import os
import time
import yaml
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Configure logging for our collector service
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('LogCollector')

class LogFileHandler(FileSystemEventHandler):
    """Handles events for log files we're monitoring."""
    
    def __init__(self, log_file_path):
        self.log_file_path = log_file_path
        self.last_position = 0
        self.initialize_position()
        
    def initialize_position(self):
        """Start tracking from the end of the existing file."""
        if os.path.exists(self.log_file_path):
            with open(self.log_file_path, 'r') as file:
                file.seek(0, os.SEEK_END)
                self.last_position = file.tell()
                logger.info(f"Initialized tracking for {self.log_file_path} at position {self.last_position}")
    
    def on_modified(self, event):
        """Called when a file is modified."""
        if event.src_path == self.log_file_path:
            self.collect_new_logs()
    
    def collect_new_logs(self):
        """Read and process new log entries."""
        try:
            with open(self.log_file_path, 'r') as file:
                # Jump to where we last read
                file.seek(self.last_position)
                
                # Read new content
                new_content = file.read()
                
                if new_content:
                    # In a real system, we might send this to a message queue or processing service
                    # For now, we'll just display the new logs
                    print("\n--- New Log Entries Detected ---")
                    for line in new_content.splitlines():
                        if line.strip():  # Skip empty lines
                            print(f"COLLECTED: {line}")
                    print("--------------------------------\n")
                
                # Update our position in the file
                self.last_position = file.tell()
                
        except Exception as e:
            logger.error(f"Error reading log file: {e}")

class LogCollectorService:
    """Main service class for the log collector."""
    
    def __init__(self, config_path="config.yml"):
        self.observers = []
        self.handlers = []
        self.load_config(config_path)
    
    def load_config(self, config_path):
        """Load configuration from YAML file or use defaults."""
        self.config = {
            'log_files': ['./sample_logs/app.log'],
            'check_interval': 0.5  # seconds
        }
        
        try:
            if os.path.exists(config_path):
                with open(config_path, 'r') as file:
                    yaml_config = yaml.safe_load(file)
                    if yaml_config:
                        self.config.update(yaml_config)
                        logger.info("Loaded configuration from file")
        except Exception as e:
            logger.error(f"Error loading config: {e}")
            logger.info("Using default configuration")
            
        logger.info(f"Monitoring log files: {self.config['log_files']}")
    
    def start(self):
        """Start monitoring log files."""
        for log_file_path in self.config['log_files']:
            # Create the directory if it doesn't exist
            os.makedirs(os.path.dirname(log_file_path), exist_ok=True)
            
            # Ensure the log file exists
            if not os.path.exists(log_file_path):
                with open(log_file_path, 'w') as f:
                    pass
                logger.info(f"Created empty log file: {log_file_path}")
            
            # Create a handler for this log file
            handler = LogFileHandler(log_file_path)
            self.handlers.append(handler)
            
            # Set up an observer for the directory containing the log file
            log_dir = os.path.dirname(log_file_path)
            observer = Observer()
            observer.schedule(handler, log_dir, recursive=False)
            observer.start()
            self.observers.append(observer)
            
            logger.info(f"Started monitoring: {log_file_path}")
    
    def stop(self):
        """Stop monitoring log files."""
        for observer in self.observers:
            observer.stop()
        
        for observer in self.observers:
            observer.join()
            
        logger.info("Stopped all log monitoring")
        
    def run(self):
        """Run the collector service until interrupted."""
        try:
            self.start()
            logger.info("Log collector service is running. Press Ctrl+C to stop.")
            
            # Keep the main thread alive until interrupted
            while True:
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Received stop signal")
        finally:
            self.stop()

if __name__ == "__main__":
    collector = LogCollectorService()
    collector.run()