import os
import gzip
import shutil
from datetime import datetime

class LogStorage:
    """Manages log file storage with rotation and retention policies"""
    
    def __init__(self, 
                 log_directory, 
                 base_filename="application.log",
                 rotation_policy=None,
                 retention_policy=None,
                 compress_rotated=True):
        """
        Initialize the log storage system
        
        Args:
            log_directory: Directory to store log files
            base_filename: Base name for log files
            rotation_policy: When to rotate log files (if None, never rotate)
            retention_policy: How to manage old log files (if None, keep all)
            compress_rotated: Whether to compress rotated log files
        """
        self.log_directory = log_directory
        self.base_filename = base_filename
        self.rotation_policy = rotation_policy
        self.retention_policy = retention_policy
        self.compress_rotated = compress_rotated
        
        # Create log directory if it doesn't exist
        os.makedirs(log_directory, exist_ok=True)
        
        # Full path to the current active log file
        self.current_log_path = os.path.join(self.log_directory, self.base_filename)
    
    def write_log(self, log_message):
        """
        Write a log message to the current log file,
        rotating if necessary according to the policy
        """
        # Check if we need to rotate
        if self.rotation_policy and self.rotation_policy.should_rotate(self.current_log_path):
            self._rotate_log()
            
        # Ensure log message ends with a newline
        if not log_message.endswith('\n'):
            log_message += '\n'
            
        # Append to the current log file
        with open(self.current_log_path, 'a') as log_file:
            log_file.write(log_message)
    
    def _rotate_log(self):
        """Rotate the current log file"""
        if not os.path.exists(self.current_log_path):
            return  # Nothing to rotate
            
        # Generate a timestamp for the rotated filename
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        rotated_filename = f"{os.path.splitext(self.base_filename)[0]}.{timestamp}.log"
        rotated_path = os.path.join(self.log_directory, rotated_filename)
        
        # Rename the current log to the rotated filename
        shutil.move(self.current_log_path, rotated_path)
        
        # Compress the rotated log if configured
        if self.compress_rotated:
            compressed_path = f"{rotated_path}.gz"
            with open(rotated_path, 'rb') as f_in:
                with gzip.open(compressed_path, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)
            # Remove the uncompressed rotated file
            os.remove(rotated_path)
            print(f"Rotated and compressed log to {compressed_path}")
        else:
            print(f"Rotated log to {rotated_path}")
            
        # Apply retention policy if configured
        if self.retention_policy:
            pattern = f"{os.path.splitext(self.base_filename)[0]}.*"
            self.retention_policy.apply(self.log_directory, pattern)
    
    def close(self):
        """Perform any cleanup operations"""
        # Currently nothing specific to clean up
        pass