import os
import glob
import time
from abc import ABC, abstractmethod

class RetentionPolicy(ABC):
    """Base class for all retention policies"""
    
    @abstractmethod
    def apply(self, log_directory, log_file_pattern):
        """Apply the retention policy to log files"""
        pass

class CountBasedRetentionPolicy(RetentionPolicy):
    """Keep a maximum number of log files"""
    
    def __init__(self, max_files):
        """Initialize with maximum number of files to keep"""
        self.max_files = max_files
    
    def apply(self, log_directory, log_file_pattern):
        """Delete oldest files when count exceeds threshold"""
        pattern = os.path.join(log_directory, log_file_pattern)
        log_files = sorted(glob.glob(pattern), key=os.path.getctime)
        
        # If we have more files than our limit
        if len(log_files) > self.max_files:
            # Calculate how many files to remove
            files_to_remove = log_files[:len(log_files) - self.max_files]
            
            # Remove excess files
            for file_path in files_to_remove:
                try:
                    os.remove(file_path)
                    print(f"Deleted old log file: {file_path}")
                except OSError as e:
                    print(f"Error deleting {file_path}: {e}")

class AgeBasedRetentionPolicy(RetentionPolicy):
    """Delete log files older than a specified age"""
    
    def __init__(self, max_age_days):
        """Initialize with maximum age in days"""
        self.max_age_seconds = max_age_days * 24 * 60 * 60
    
    def apply(self, log_directory, log_file_pattern):
        """Delete files older than the threshold"""
        current_time = time.time()
        pattern = os.path.join(log_directory, log_file_pattern)
        
        for log_file in glob.glob(pattern):
            file_age = current_time - os.path.getctime(log_file)
            
            if file_age > self.max_age_seconds:
                try:
                    os.remove(log_file)
                    print(f"Deleted expired log file: {log_file}")
                except OSError as e:
                    print(f"Error deleting {log_file}: {e}")