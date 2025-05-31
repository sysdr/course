# tests/test_log_storage.py
import os
import time
import shutil
import unittest
from src.log_storage import LogStorage
from src.rotation_policy import SizeBasedRotationPolicy, TimeBasedRotationPolicy
from src.retention_policy import CountBasedRetentionPolicy

class TestLogStorage(unittest.TestCase):
    def setUp(self):
        # Create a temporary directory for testing
        self.test_dir = "test_logs"
        os.makedirs(self.test_dir, exist_ok=True)
    
    def tearDown(self):
        # Clean up test directory
        shutil.rmtree(self.test_dir, ignore_errors=True)
    
    def test_size_based_rotation(self):
        # Create log storage with size-based rotation at 100 bytes
        storage = LogStorage(
            log_directory=self.test_dir,
            base_filename="test.log",
            rotation_policy=SizeBasedRotationPolicy(100),
            compress_rotated=False
        )
        
        # Write enough data to trigger rotation
        for i in range(20):
            storage.write_log(f"Test log message {i} with some additional content to fill space.")
        
        # Check that rotation occurred (at least one rotated file exists)
        rotated_files = [f for f in os.listdir(self.test_dir) if f != "test.log"]
        self.assertGreater(len(rotated_files), 0)
    
    def test_retention_policy(self):
        # Create log storage with retention policy keeping only 3 files
        storage = LogStorage(
            log_directory=self.test_dir,
            base_filename="test.log",
            rotation_policy=SizeBasedRotationPolicy(10),  # Small size to force rotation
            retention_policy=CountBasedRetentionPolicy(3),
            compress_rotated=False
        )
        
        # Write enough data to trigger multiple rotations
        for i in range(100):
            storage.write_log(f"Message {i}")
            time.sleep(0.01)  # Small delay to ensure distinct creation times
        
        # Check that only the specified number of files exist
        all_files = os.listdir(self.test_dir)
        # +1 because we count the active log file plus the rotated ones
        self.assertLessEqual(len(all_files), 4)  # 3 rotated + 1 active

if __name__ == "__main__":
    unittest.main()