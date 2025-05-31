import os
import time
from abc import ABC, abstractmethod
from datetime import datetime

class RotationPolicy(ABC):
    """Base class for all rotation policies"""
    
    @abstractmethod
    def should_rotate(self, log_file_path):
        """Check if the log file should be rotated"""
        pass
    
class SizeBasedRotationPolicy(RotationPolicy):
    """Rotate logs when they reach a specified size"""
    
    def __init__(self, max_size_bytes):
        """
        Initialize with maximum file size in bytes
        """
        self.max_size_bytes = max_size_bytes
    
    def should_rotate(self, log_file_path):
        """Return True if file size exceeds the threshold"""
        if not os.path.exists(log_file_path):
            return False
        
        current_size = os.path.getsize(log_file_path)
        return current_size >= self.max_size_bytes

class TimeBasedRotationPolicy(RotationPolicy):
    """Rotate logs after a specified time interval"""
    
    def __init__(self, interval_seconds):
        """
        Initialize with rotation interval in seconds
        """
        self.interval_seconds = interval_seconds
        self.last_rotation_time = time.time()
    
    def should_rotate(self, log_file_path):
        """Return True if enough time has passed since last rotation"""
        current_time = time.time()
        if current_time - self.last_rotation_time >= self.interval_seconds:
            self.last_rotation_time = current_time
            return True
        return False