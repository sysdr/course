import time
from typing import Iterator, Optional

class LogReader:
    """Reads logs from a file, supporting both batch and real-time reading."""
    
    def __init__(self, log_file_path: str):
        """Initialize with path to log file.
        
        Args:
            log_file_path: Path to the log file to read
        """
        self.log_file_path = log_file_path
        self.last_position = 0
    
    def read_batch(self) -> list[str]:
        """Read all logs in the file as a batch.
        
        Returns:
            List of log lines
        """
        try:
            with open(self.log_file_path, 'r') as file:
                return file.readlines()
        except FileNotFoundError:
            print(f"Warning: Log file {self.log_file_path} not found")
            return []
    
    def read_incremental(self) -> Iterator[str]:
        """Read logs incrementally, yielding only new lines.
        
        Yields:
            New log lines as they are written to the file
        """
        try:
            with open(self.log_file_path, 'r') as file:
                # Move to the last read position
                file.seek(self.last_position)
                
                while True:
                    line = file.readline()
                    if line:
                        yield line
                        self.last_position = file.tell()
                    else:
                        # No new lines, wait before checking again
                        time.sleep(0.1)
        except FileNotFoundError:
            print(f"Warning: Log file {self.log_file_path} not found")
            yield from []