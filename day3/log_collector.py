#!/usr/bin/env python3
"""
Log Collector Service

This service watches log files and detects new entries as they appear.
It's designed to be a building block in a distributed logging system.
"""

import os
import time
import argparse
import json
from datetime import datetime
from typing import Dict, List, Optional, Set
import signal
import sys

class LogCollector:
    """Watches log files and detects new entries"""
    
    def __init__(self, log_paths: List[str], check_interval: float = 0.5):
        """
        Initialize the log collector
        
        Args:
            log_paths: List of paths to log files to watch
            check_interval: How often to check for new logs (in seconds)
        """
        self.log_paths = log_paths
        self.check_interval = check_interval
        self.file_positions: Dict[str, int] = {}
        self.running = False
        self.processed_entries = 0
        
        # Initialize file positions
        for path in self.log_paths:
            try:
                if os.path.exists(path):
                    # Start at the end of existing files
                    with open(path, 'r') as f:
                        f.seek(0, os.SEEK_END)
                        self.file_positions[path] = f.tell()
                else:
                    # File doesn't exist yet, will be created later
                    self.file_positions[path] = 0
            except Exception as e:
                print(f"Error initializing file position for {path}: {e}")
    
    def process_log_entry(self, log_file: str, entry: str) -> None:
        """
        Process a single log entry - this method can be extended
        in the future to do more complex processing
        
        Args:
            log_file: Source log file path
            entry: The log entry content
        """
        # Simple processing - print with timestamp and source
        timestamp = datetime.now().isoformat()
        
        try:
            # Try to parse as JSON for prettier printing
            data = json.loads(entry)
            formatted_entry = json.dumps(data, indent=2)
        except:
            # Not JSON, use as-is
            formatted_entry = entry.strip()
        
        print(f"[{timestamp}] From {os.path.basename(log_file)}: {formatted_entry}")
        self.processed_entries += 1
    
    def check_file_for_new_entries(self, file_path: str) -> int:
        """
        Check a single file for new entries
        
        Args:
            file_path: Path to log file
            
        Returns:
            Number of new entries found
        """
        new_entries = 0
        
        try:
            if not os.path.exists(file_path):
                return 0
                
            with open(file_path, 'r') as f:
                # Move to last known position
                f.seek(self.file_positions.get(file_path, 0))
                
                # Read any new content
                for line in f:
                    if line.strip():  # Skip empty lines
                        self.process_log_entry(file_path, line)
                        new_entries += 1
                
                # Update position
                self.file_positions[file_path] = f.tell()
                
            return new_entries
            
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return 0
    
    def run(self) -> None:
        """Run the log collector until stopped"""
        self.running = True
        
        # Set up signal handlers for graceful shutdown
        def handle_signal(sig, frame):
            print(f"\nShutting down log collector (received signal {sig})...")
            self.running = False
            
        signal.signal(signal.SIGINT, handle_signal)
        signal.signal(signal.SIGTERM, handle_signal)
        
        print(f"Log collector started, watching {len(self.log_paths)} file(s):")
        for path in self.log_paths:
            print(f"  - {path}")
        
        try:
            while self.running:
                total_new_entries = 0
                
                # Check each file for new entries
                for log_path in self.log_paths:
                    new_entries = self.check_file_for_new_entries(log_path)
                    total_new_entries += new_entries
                
                # If we found new entries, print a summary
                if total_new_entries > 0:
                    print(f"Processed {total_new_entries} new log entries")
                    
                # Sleep until next check
                time.sleep(self.check_interval)
                
        except Exception as e:
            print(f"Error in log collector: {e}")
        finally:
            print(f"Log collector stopped. Total entries processed: {self.processed_entries}")

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Log Collector Service')
    
    parser.add_argument(
        '-f', '--files',
        nargs='+',
        required=True,
        help='Log files to watch (can specify multiple)'
    )
    
    parser.add_argument(
        '-i', '--interval',
        type=float,
        default=0.5,
        help='How often to check for new logs (in seconds)'
    )
    
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_arguments()
    
    collector = LogCollector(
        log_paths=args.files,
        check_interval=args.interval
    )
    
    collector.run()