import threading
import time
from typing import Dict, List, Callable
from .job import MapReduceJob, MapReduceConfig
import logging

class JobCoordinator:
    """Coordinates multiple MapReduce jobs"""
    
    def __init__(self):
        self.jobs: Dict[str, MapReduceJob] = {}
        self.job_threads: Dict[str, threading.Thread] = {}
        self.logger = logging.getLogger("JobCoordinator")
        self._lock = threading.Lock()
    
    def submit_job(self, config: MapReduceConfig, map_func: Callable, 
                   reduce_func: Callable, input_files: List[str]) -> str:
        """Submit a new MapReduce job"""
        job = MapReduceJob(config)
        job_id = job.job_id
        
        with self._lock:
            self.jobs[job_id] = job
        
        # Start job in separate thread
        thread = threading.Thread(
            target=self._run_job_async,
            args=(job, map_func, reduce_func, input_files)
        )
        thread.daemon = True
        thread.start()
        
        self.job_threads[job_id] = thread
        
        self.logger.info(f"Submitted job {job_id}")
        return job_id
    
    def _run_job_async(self, job: MapReduceJob, map_func: Callable, 
                       reduce_func: Callable, input_files: List[str]):
        """Run job asynchronously"""
        try:
            job.run(map_func, reduce_func, input_files)
        except Exception as e:
            self.logger.error(f"Job {job.job_id} failed: {e}")
    
    def get_job_status(self, job_id: str) -> dict:
        """Get status of a specific job"""
        with self._lock:
            if job_id in self.jobs:
                return self.jobs[job_id].get_status()
            return {'error': 'Job not found'}
    
    def list_jobs(self) -> List[dict]:
        """List all jobs with their statuses"""
        with self._lock:
            return [job.get_status() for job in self.jobs.values()]
    
    def cleanup_completed_jobs(self):
        """Clean up completed job threads"""
        completed_jobs = []
        
        for job_id, thread in self.job_threads.items():
            if not thread.is_alive():
                completed_jobs.append(job_id)
        
        for job_id in completed_jobs:
            del self.job_threads[job_id]
