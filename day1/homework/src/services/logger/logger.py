"""
Logger module for handling log message formatting and output.
"""
import os
import time
from datetime import datetime
import config


class Logger:
    def __init__(self):
        """Initialize the logger with configuration settings."""
        self.config = config.get_config()
        self.logs = []
        self.setup_log_directory()
        
    def setup_log_directory(self):
        """Ensure the log directory exists."""
        if self.config["log_to_file"]:
            log_dir = os.path.dirname(self.config["log_file_path"])
            os.makedirs(log_dir, exist_ok=True)
    
    def log(self, level, message):
        """Log a message with the specified level."""
        if not config.is_log_enabled(level, self.config["log_level"]):
            return
            
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # Format for console
        console_message = self.config["console_format"].format(
            timestamp=timestamp,
            level=level.upper(),
            message=message
        )
        
        # Store log for web display (limit to max logs to display)
        self.logs.append({
            "timestamp": timestamp,
            "level": level.upper(),
            "message": message
        })
        if len(self.logs) > self.config["max_logs_to_display"]:
            self.logs.pop(0)
        
        # Print to console
        print(console_message)
        
        # Write to file if enabled
        if self.config["log_to_file"]:
            self._write_to_file(timestamp, level, message)
    
    def _write_to_file(self, timestamp, level, message):
        """Write log message to file with rotation if needed."""
        # Format for file
        file_message = self.config["file_format"].format(
            timestamp=timestamp,
            level=level.upper(),
            message=message
        )
        
        # Check if rotation is needed
        if self._should_rotate_log():
            self._rotate_log()
            
        # Write to file
        with open(self.config["log_file_path"], 'a') as file:
            file.write(file_message + '\n')
    
    def _should_rotate_log(self):
        """Check if log file should be rotated based on size."""
        if not os.path.exists(self.config["log_file_path"]):
            return False
            
        # Get file size in MB
        size_mb = os.path.getsize(self.config["log_file_path"]) / (1024 * 1024)
        return size_mb >= self.config["log_max_size_mb"]
    
    def _rotate_log(self):
        """Rotate the log file by renaming it with a timestamp."""
        if not os.path.exists(self.config["log_file_path"]):
            return
            
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        base_path = self.config["log_file_path"]
        rotated_path = f"{base_path}.{timestamp}"
        
        os.rename(base_path, rotated_path)
        
        # Log rotation event (directly to console to avoid recursion)
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [INFO] Rotated log file to {rotated_path}")
    
    def get_recent_logs(self):
        """Return recent logs for web display."""
        return self.logs
    
    def debug(self, message):
        """Log a debug message."""
        self.log("debug", message)
        
    def info(self, message):
        """Log an info message."""
        self.log("info", message)
        
    def warning(self, message):
        """Log a warning message."""
        self.log("warning", message)
        
    def error(self, message):
        """Log an error message."""
        self.log("error", message)
        
    def critical(self, message):
        """Log a critical message."""
        self.log("critical", message)