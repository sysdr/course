import pytest
import tempfile
import os
import time
from src.mapreduce.coordinator import JobCoordinator
from src.mapreduce.job import MapReduceConfig
from src.mapreduce.analyzers import word_count_mapper, word_count_reducer
from src.utils.data_generator import LogDataGenerator

class TestEndToEnd:
    """End-to-end integration tests"""
    
    def setup_method(self):
        """Setup test environment"""
        self.temp_dir = tempfile.mkdtemp()
        self.coordinator = JobCoordinator()
        self.generator = LogDataGenerator()
    
    def test_complete_mapreduce_pipeline(self):
        """Test complete MapReduce pipeline"""
        # Generate test data
        test_file = os.path.join(self.temp_dir, "test_logs.txt")
        self.generator.generate_json_logs(100, test_file)
        
        # Create job configuration
        config = MapReduceConfig(
            input_path=self.temp_dir,
            output_path=self.temp_dir,
            num_workers=2
        )
        
        # Submit job
        job_id = self.coordinator.submit_job(
            config, word_count_mapper, word_count_reducer, [test_file]
        )
        
        # Wait for job completion (max 30 seconds)
        max_wait = 30
        wait_time = 0
        
        while wait_time < max_wait:
            status = self.coordinator.get_job_status(job_id)
            if status['status'] in ['completed', 'failed']:
                break
            time.sleep(1)
            wait_time += 1
        
        # Verify job completed successfully
        final_status = self.coordinator.get_job_status(job_id)
        assert final_status['status'] == 'completed'
        assert final_status['progress'] == 100.0
    
    def test_multiple_concurrent_jobs(self):
        """Test multiple concurrent job execution"""
        # Generate test data
        test_files = []
        for i in range(3):
            test_file = os.path.join(self.temp_dir, f"test_logs_{i}.txt")
            self.generator.generate_json_logs(50, test_file)
            test_files.append(test_file)
        
        # Submit multiple jobs
        job_ids = []
        for i, test_file in enumerate(test_files):
            config = MapReduceConfig(
                input_path=self.temp_dir,
                output_path=os.path.join(self.temp_dir, f"output_{i}"),
                num_workers=2
            )
            
            job_id = self.coordinator.submit_job(
                config, word_count_mapper, word_count_reducer, [test_file]
            )
            job_ids.append(job_id)
        
        # Wait for all jobs to complete
        max_wait = 60
        wait_time = 0
        
        while wait_time < max_wait:
            all_completed = True
            for job_id in job_ids:
                status = self.coordinator.get_job_status(job_id)
                if status['status'] not in ['completed', 'failed']:
                    all_completed = False
                    break
            
            if all_completed:
                break
            
            time.sleep(1)
            wait_time += 1
        
        # Verify all jobs completed
        for job_id in job_ids:
            status = self.coordinator.get_job_status(job_id)
            assert status['status'] == 'completed'
    
    def test_performance_benchmark(self):
        """Test performance with larger dataset"""
        # Generate larger test dataset
        test_file = os.path.join(self.temp_dir, "large_test.txt")
        self.generator.generate_json_logs(1000, test_file)
        
        config = MapReduceConfig(
            input_path=self.temp_dir,
            output_path=self.temp_dir,
            num_workers=4
        )
        
        start_time = time.time()
        
        job_id = self.coordinator.submit_job(
            config, word_count_mapper, word_count_reducer, [test_file]
        )
        
        # Wait for completion
        max_wait = 120  # 2 minutes max
        wait_time = 0
        
        while wait_time < max_wait:
            status = self.coordinator.get_job_status(job_id)
            if status['status'] in ['completed', 'failed']:
                break
            time.sleep(1)
            wait_time += 1
        
        end_time = time.time()
        execution_time = end_time - start_time
        
        # Verify performance
        status = self.coordinator.get_job_status(job_id)
        assert status['status'] == 'completed'
        assert execution_time < 60  # Should complete within 1 minute
        
        print(f"Performance test: Processed 1000 logs in {execution_time:.2f} seconds")
