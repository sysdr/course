#!/usr/bin/env python3
"""
Log Collector Service

This service watches log files for changes and detects new entries.
It demonstrates a key component of distributed logging systems.
"""

import os
import time
import json
import argparse
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler


class LogEntry:
    """Represents a structured log entry from a log file."""
    
    def __init__(self, content, source, timestamp=None):
        self.content = content
        self.source = source
        # Use current time if no timestamp provided
        self.timestamp = timestamp or time.time()
    
    def to_dict(self):
        """Convert log entry to dictionary for serialization."""
        return {
            "content": self.content,
            "source": self.source,
            "timestamp": self.timestamp
        }
    
    def __str__(self):
        """String representation of log entry."""
        return f"[{self.source}] {self.content}"


class LogCollector:
    """Core class for collecting and processing log entries."""
    
    def __init__(self, output_dir="./collected_logs"):
        """Initialize the log collector with output directory."""
        self.output_dir = output_dir
        # Ensure output directory exists
        os.makedirs(output_dir, exist_ok=True)
        self.buffer = []
        self.collected_count = 0
    
    def process_entry(self, entry):
        """Process a new log entry."""
        print(f"New log entry detected: {entry}")
        self.buffer.append(entry)
        self.collected_count += 1
        
        # For demonstration, we'll write every 5 entries to a file
        if len(self.buffer) >= 5:
            self.flush_buffer()
    
    def flush_buffer(self):
        """Write buffered entries to output file."""
        if not self.buffer:
            return
            
        # Create output filename based on timestamp
        output_file = os.path.join(
            self.output_dir, 
            f"collected_logs_{int(time.time())}.json"
        )
        
        # Write entries to file
        with open(output_file, 'w') as f:
            entries_dict = [entry.to_dict() for entry in self.buffer]
            json.dump(entries_dict, f, indent=2)
            
        print(f"Wrote {len(self.buffer)} entries to {output_file}")
        self.buffer = []  # Clear the buffer


class LogFileHandler(FileSystemEventHandler):
    """Handler for file system events on log files."""
    
    def __init__(self, collector):
        """Initialize with a reference to the log collector."""
        self.collector = collector
        # Keep track of file positions to detect new content
        self.file_positions = {}
    
    def on_modified(self, event):
        """Handle file modification events."""
        if event.is_directory:
            return
            
        # Process changes in the file
        self._process_file_changes(event.src_path)
    
    def _process_file_changes(self, file_path):
        """Process changes in a log file by reading new content."""
        # Get the last position we read from this file
        last_position = self.file_positions.get(file_path, 0)
        
        try:
            with open(file_path, 'r') as f:
                # Move to where we last read
                f.seek(last_position)
                
                # Read new lines
                new_lines = f.readlines()
                
                # If we have new content
                if new_lines:
                    for line in new_lines:
                        line = line.strip()
                        if line:  # Skip empty lines
                            # Create and process log entry
                            entry = LogEntry(
                                content=line,
                                source=os.path.basename(file_path)
                            )
                            self.collector.process_entry(entry)
                
                # Remember position for next time
                self.file_positions[file_path] = f.tell()
                
        except Exception as e:
            print(f"Error processing file {file_path}: {e}")


def watch_log_files(log_paths, output_dir="./collected_logs"):
    """
    Watch the specified log files for changes.
    
    Args:
        log_paths: List of paths to log files to watch
        output_dir: Directory to save collected logs
    """
    print(f"Starting log collector. Watching {len(log_paths)} files.")
    print(f"Output directory: {output_dir}")
    
    # Initialize the collector and event handler
    collector = LogCollector(output_dir)
    event_handler = LogFileHandler(collector)
    
    # Set up the observer
    observer = Observer()
    
    # Add watchers for each log file's directory
    for log_path in log_paths:
        if not os.path.exists(log_path):
            print(f"Warning: Log file {log_path} does not exist yet.")
        
        # Get the directory containing the log file
        directory = os.path.dirname(log_path) or '.'
        
        # Schedule the directory for watching
        observer.schedule(event_handler, directory, recursive=False)
        
        # Initial read of existing content
        if os.path.exists(log_path) and os.path.isfile(log_path):
            event_handler._process_file_changes(log_path)
    
    # Start the observer
    observer.start()
    
    try:
        # Keep the main thread running
        while True:
            time.sleep(1)
            # Every 10 seconds, flush buffer even if not full
            if time.time() % 10 < 1 and collector.buffer:
                collector.flush_buffer()
                
    except KeyboardInterrupt:
        # Stop the observer gracefully
        observer.stop()
        
    # Wait for the observer thread to finish
    observer.join()
    
    # Final flush of any remaining entries
    collector.flush_buffer()
    
    print(f"Log collector stopped. Collected {collector.collected_count} entries.")


if __name__ == "__main__":
    # Set up command-line argument parsing
    parser = argparse.ArgumentParser(description='Log file collector service')
    parser.add_argument(
        '--log-files', 
        required=True,
        nargs='+', 
        help='Paths to log files to watch'
    )
    parser.add_argument(
        '--output-dir', 
        default='./collected_logs',
        help='Directory to store collected logs'
    )
    
    # Parse arguments
    args = parser.parse_args()
    
    # Start watching log files
    watch_log_files(args.log_files, args.output_dir)
