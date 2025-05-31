"""
Log generator module for creating sample logs with configurable rates and types.
"""
import os
import time
import random
from datetime import datetime

class LogGenerator:
    def __init__(self, config):
        """Initialize the log generator with configuration settings."""
        self.config = config
        self.ensure_log_directory()
        
    def ensure_log_directory(self):
        """Make sure the log directory exists."""
        log_dir = os.path.dirname(self.config["OUTPUT_FILE"])
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
    
    def generate_log_message(self):
        """Generate a random log message based on configuration."""
        # Select log type based on distribution
        log_type = self._select_log_type()
        
        # Generate timestamp
        timestamp = datetime.now().isoformat()
        
        # Create sample messages based on log type
        messages = {
            "INFO": [
                "User logged in successfully",
                "Page loaded in 0.2 seconds",
                "Database connection established",
                "Cache refreshed successfully",
                "API request completed"
            ],
            "WARNING": [
                "High memory usage detected",
                "API response time exceeding threshold",
                "Database connection pool running low",
                "Retry attempt for failed operation",
                "Cache miss rate increasing"
            ],
            "ERROR": [
                "Failed to connect to database",
                "API request timeout",
                "Invalid user credentials",
                "Processing error in data pipeline",
                "Out of memory error"
            ],
            "DEBUG": [
                "Function X called with parameters Y",
                "SQL query execution details",
                "Cache lookup performed",
                "Request headers processed",
                "Internal state transition"
            ]
        }
        
        # Select a random message for the chosen log type
        if log_type in messages:
            message = random.choice(messages[log_type])
        else:
            message = f"Sample log message for {log_type}"
            
        # Generate a unique ID for this log entry
        log_id = f"LOG-{int(time.time())}-{random.randint(1000, 9999)}"
        
        # Create the full log entry
        log_entry = f"{timestamp} [{log_type}] [{log_id}]: {message}"
        return log_entry
    
    def _select_log_type(self):
        """Select a log type based on the configured distribution."""
        distribution = self.config["LOG_DISTRIBUTION"]
        types = list(distribution.keys())
        weights = list(distribution.values())
        
        return random.choices(types, weights=weights, k=1)[0]
    
    def write_log(self, log_entry):
        """Write a log entry to the configured outputs."""
        # Write to file if configured
        if self.config["OUTPUT_FILE"]:
            with open(self.config["OUTPUT_FILE"], "a") as f:
                f.write(log_entry + "\n")
        
        # Write to console if configured
        if self.config["CONSOLE_OUTPUT"]:
            print(log_entry)
    
    def run(self, duration=None):
        """Run the log generator for a specified duration or indefinitely."""
        print(f"Starting log generator with rate: {self.config['LOG_RATE']} logs/second")
        
        # Calculate sleep time based on log rate
        sleep_time = 1.0 / self.config["LOG_RATE"] if self.config["LOG_RATE"] > 0 else 1.0
        
        start_time = time.time()
        count = 0
        
        try:
            while duration is None or time.time() - start_time < duration:
                log_entry = self.generate_log_message()
                self.write_log(log_entry)
                count += 1
                
                # Sleep to maintain the configured rate
                time.sleep(sleep_time)
                
        except KeyboardInterrupt:
            print("\nLog generator stopped by user")
        
        print(f"Generated {count} log entries")