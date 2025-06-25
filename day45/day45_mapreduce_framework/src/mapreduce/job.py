import os
import json
import time
import logging
import multiprocessing as mp
from typing import List, Callable, Any, Iterator, Tuple
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass, asdict
import dill
from pathlib import Path

@dataclass
class MapReduceConfig:
    input_path: str
    output_path: str
    num_workers: int = mp.cpu_count()
    chunk_size: int = 64 * 1024 * 1024  # 64MB chunks
    intermediate_dir: str = "intermediate"
    
@dataclass
class JobStatus:
    job_id: str
    status: str  # pending, mapping, shuffling, reducing, completed, failed
    progress: float
    start_time: float
    current_phase: str
    total_chunks: int = 0
    completed_chunks: int = 0
    error_message: str = None
    execution_time: float = 0.0
    records_processed: int = 0

class MapReduceJob:
    def __init__(self, config: MapReduceConfig, job_id: str = None):
        self.config = config
        self.job_id = job_id or f"job_{int(time.time())}"
        self.status = JobStatus(
            job_id=self.job_id,
            status="pending",
            progress=0.0,
            start_time=time.time(),
            current_phase="initialization"
        )
        self.logger = logging.getLogger(f"MapReduce.{self.job_id}")
        
        # Create necessary directories
        os.makedirs(self.config.output_path, exist_ok=True)
        os.makedirs(os.path.join(self.config.output_path, self.config.intermediate_dir), exist_ok=True)
    
    def run(self, map_func: Callable, reduce_func: Callable, input_files: List[str]) -> dict:
        """Execute complete MapReduce pipeline"""
        try:
            self.logger.info(f"Starting MapReduce job {self.job_id}")
            
            # Phase 1: Map
            self.status.current_phase = "mapping"
            self.status.status = "mapping"
            map_outputs = self._execute_map_phase(map_func, input_files)
            
            # Phase 2: Shuffle
            self.status.current_phase = "shuffling"
            self.status.status = "shuffling"
            shuffled_data = self._execute_shuffle_phase(map_outputs)
            
            # Phase 3: Reduce
            self.status.current_phase = "reducing"
            self.status.status = "reducing"
            final_results = self._execute_reduce_phase(reduce_func, shuffled_data)
            
            # Complete
            self.status.status = "completed"
            self.status.progress = 100.0
            self.status.current_phase = "completed"
            self.status.execution_time = time.time() - self.status.start_time
            
            self.logger.info(f"MapReduce job {self.job_id} completed successfully")
            return {
                'job_id': self.job_id,
                'status': 'completed',
                'results': final_results,
                'execution_time': self.status.execution_time
            }
            
        except Exception as e:
            self.status.status = "failed"
            self.status.error_message = str(e)
            self.status.execution_time = time.time() - self.status.start_time
            self.logger.error(f"Job {self.job_id} failed: {e}")
            raise
    
    def _execute_map_phase(self, map_func: Callable, input_files: List[str]) -> List[str]:
        """Execute map phase across multiple workers"""
        self.logger.info("Starting map phase")
        
        # Split input files into chunks
        chunks = self._split_input_files(input_files)
        self.status.total_chunks = len(chunks)
        
        # Count total records for tracking
        total_records = sum(len(chunk) for chunk in chunks)
        self.status.records_processed = total_records
        
        map_outputs = []
        
        with ProcessPoolExecutor(max_workers=self.config.num_workers) as executor:
            # Submit map tasks
            future_to_chunk = {
                executor.submit(self._map_worker, dill.dumps(map_func), chunk, i): i 
                for i, chunk in enumerate(chunks)
            }
            
            # Collect results
            for future in as_completed(future_to_chunk):
                chunk_id = future_to_chunk[future]
                try:
                    output_file = future.result()
                    map_outputs.append(output_file)
                    self.status.completed_chunks += 1
                    self.status.progress = (self.status.completed_chunks / self.status.total_chunks) * 33.33
                    self.logger.info(f"Completed map task for chunk {chunk_id}")
                except Exception as e:
                    self.logger.error(f"Map task failed for chunk {chunk_id}: {e}")
                    raise
        
        return map_outputs
    
    def _map_worker(self, serialized_map_func: bytes, chunk_data: List[str], chunk_id: int) -> str:
        """Worker process for map operations"""
        map_func = dill.loads(serialized_map_func)
        
        output_file = os.path.join(
            self.config.output_path, 
            self.config.intermediate_dir, 
            f"map_output_{chunk_id}.json"
        )
        
        results = []
        for line in chunk_data:
            for key, value in map_func(line.strip()):
                results.append({'key': key, 'value': value})
        
        with open(output_file, 'w') as f:
            json.dump(results, f)
        
        return output_file
    
    def _execute_shuffle_phase(self, map_outputs: List[str]) -> dict:
        """Shuffle and sort intermediate results"""
        self.logger.info("Starting shuffle phase")
        
        shuffled = {}
        
        for output_file in map_outputs:
            with open(output_file, 'r') as f:
                map_results = json.load(f)
            
            for item in map_results:
                key = item['key']
                value = item['value']
                
                if key not in shuffled:
                    shuffled[key] = []
                shuffled[key].append(value)
        
        # Update progress
        self.status.progress = 66.66
        
        return shuffled
    
    def _execute_reduce_phase(self, reduce_func: Callable, shuffled_data: dict) -> dict:
        """Execute reduce phase"""
        self.logger.info("Starting reduce phase")
        
        final_results = {}
        
        with ProcessPoolExecutor(max_workers=self.config.num_workers) as executor:
            # Submit reduce tasks
            future_to_key = {
                executor.submit(self._reduce_worker, dill.dumps(reduce_func), key, values): key
                for key, values in shuffled_data.items()
            }
            
            # Collect results
            for future in as_completed(future_to_key):
                key = future_to_key[future]
                try:
                    result_key, result_value = future.result()
                    final_results[result_key] = result_value
                except Exception as e:
                    self.logger.error(f"Reduce task failed for key {key}: {e}")
                    raise
        
        return final_results
    
    def _reduce_worker(self, serialized_reduce_func: bytes, key: str, values: List[Any]) -> Tuple[str, Any]:
        """Worker process for reduce operations"""
        reduce_func = dill.loads(serialized_reduce_func)
        result = reduce_func(key, values)
        return result
    
    def _split_input_files(self, input_files: List[str]) -> List[List[str]]:
        """Split input files into processable chunks"""
        chunks = []
        current_chunk = []
        current_size = 0
        
        for file_path in input_files:
            if not os.path.exists(file_path):
                continue
                
            with open(file_path, 'r') as f:
                for line in f:
                    current_chunk.append(line)
                    current_size += len(line)
                    
                    if current_size >= self.config.chunk_size:
                        chunks.append(current_chunk)
                        current_chunk = []
                        current_size = 0
        
        if current_chunk:
            chunks.append(current_chunk)
        
        return chunks
    
    def get_status(self) -> dict:
        """Get current job status"""
        status_dict = {
            'job_id': self.status.job_id,
            'status': self.status.status,
            'progress': self.status.progress,
            'start_time': self.status.start_time,
            'current_phase': self.status.current_phase,
            'total_chunks': self.status.total_chunks,
            'completed_chunks': self.status.completed_chunks,
            'error_message': self.status.error_message,
            'execution_time': self.status.execution_time,
            'records_processed': self.status.records_processed
        }
        
        return status_dict
