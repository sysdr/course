#!/usr/bin/env python3
# log_processing_service.py

import os
import time
import json
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from log_parser import LogParser

class LogFileHandler(FileSystemEventHandler):
   def __init__(self, parser):
       self.parser = parser
       self.processed_lines = set()  # Track processed lines to avoid duplicates
       
   def on_modified(self, event):
       if not event.is_directory and event.src_path.endswith('.log'):
           self.process_file(event.src_path)
   
   def process_file(self, file_path):
       try:
           with open(file_path, 'r') as f:
               # Read all lines from the file
               lines = f.readlines()
               
               # Process only new lines
               for line in lines:
                   line_hash = hash(line)
                   if line_hash not in self.processed_lines:
                       # Parse the log line
                       parsed_log = self.parser.parse(line.strip())
                       
                       # Output the structured log data
                       self.output_parsed_log(parsed_log, file_path)
                       
                       # Mark as processed
                       self.processed_lines.add(line_hash)
                       
                       # Limit the size of our tracking set to prevent memory issues
                       if len(self.processed_lines) > 100000:
                           # Remove the oldest entries (arbitrary number for demo purposes)
                           self.processed_lines = set(list(self.processed_lines)[-50000:])
       except Exception as e:
           print(f"Error processing file {file_path}: {e}")
   
   def output_parsed_log(self, parsed_log, source_file):
       """Output the parsed log to a JSON file or another destination"""
       
       # Add source file information
       parsed_log['source_file'] = os.path.basename(source_file)
       
       # In a real system, you might:
       # 1. Send to Kafka or other message queue
       # 2. Write to a database
       # 3. Send to a central logging service like Elasticsearch
       
       # For this demo, we'll write to a JSON file
       output_dir = os.path.join(os.path.dirname(source_file), 'parsed')
       os.makedirs(output_dir, exist_ok=True)
       
       output_file = os.path.join(output_dir, 
                                 f"parsed_{os.path.basename(source_file)}.json")
       
       # Append to the file
       with open(output_file, 'a') as f:
           f.write(json.dumps(parsed_log) + '\n')
       
       print(f"Parsed log from {source_file}: {json.dumps(parsed_log)[:100]}...")


def main():
   # Create our parser
   parser = LogParser()
   
   # Directory to monitor for log files
   log_dir = os.environ.get('LOG_DIR', '../logs')
   
   print(f"Starting log processing service. Monitoring directory: {log_dir}")
   
   # Create an observer to watch for file changes
   event_handler = LogFileHandler(parser)
   observer = Observer()
   observer.schedule(event_handler, log_dir, recursive=True)
   observer.start()
   
   try:
       # Process any existing files first
       for filename in os.listdir(log_dir):
           if filename.endswith('.log'):
               file_path = os.path.join(log_dir, filename)
               print(f"Processing existing file: {file_path}")
               event_handler.process_file(file_path)
       
       # Keep the service running
       while True:
           time.sleep(1)
   except KeyboardInterrupt:
       observer.stop()
   observer.join()


if __name__ == "__main__":
   main()
