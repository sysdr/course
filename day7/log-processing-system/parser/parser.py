# parser/parser.py
import os
import argparse
import json
import time
import re
from pathlib import Path
from datetime import datetime

# Regular expressions for parsing different log formats
LOG_PARSERS = {
    'apache': re.compile(r'(?P<ip>\S+) - - \[(?P<timestamp>[^\]]+)\] "GET /api/(?P<endpoint>\S+) HTTP/\d\.\d" (?P<status>\d+) (?P<size>\d+)'),
    'nginx': re.compile(r'(?P<timestamp>[^\[]+) \[(?P<level>\w+)\] (?P<process>\w+): (?P<message>.+)'),
    'app': re.compile(r'\[(?P<timestamp>[^\]]+)\] (?P<level>\w+) \[(?P<service>\w+)\] (?P<message>.+)')
}

def parse_log_entry(log_entry, format_name):
    """Parse a log entry into structured data based on the format"""
    parser = LOG_PARSERS.get(format_name)
    if not parser:
        return None
    
    match = parser.match(log_entry)
    if not match:
        return None
    
    data = match.groupdict()
    
    # Add metadata
    data['raw'] = log_entry
    data['parsed_at'] = datetime.now().isoformat()
    data['format'] = format_name
    
    return data

class LogParser:
    def __init__(self, input_dir, output_dir, format_name, interval=5.0):
        self.input_dir = input_dir
        self.output_dir = output_dir
        self.format_name = format_name
        self.interval = interval
        self.processed_files = set()
        
        # Ensure output directory exists
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        
        # Load processed files list
        self.processed_file = os.path.join(output_dir, "processed_files.json")
        self._load_processed_files()
    
    def _load_processed_files(self):
        """Load the list of already processed files"""
        if os.path.exists(self.processed_file):
            try:
                with open(self.processed_file, 'r') as f:
                    self.processed_files = set(json.load(f))
            except Exception as e:
                print(f"Error loading processed files: {str(e)}")
    
    def _save_processed_files(self):
        """Save the list of processed files"""
        try:
            with open(self.processed_file, 'w') as f:
                json.dump(list(self.processed_files), f)
        except Exception as e:
            print(f"Error saving processed files: {str(e)}")
    
    def parse_file(self, file_path):
        """Parse a single log file and return structured data"""
        structured_data = []
        
        try:
            with open(file_path, 'r') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line:
                        continue
                    
                    parsed = parse_log_entry(line, self.format_name)
                    if parsed:
                        # Add line number and file info
                        parsed['line_number'] = line_num
                        parsed['source_file'] = os.path.basename(file_path)
                        structured_data.append(parsed)
                    else:
                        print(f"Failed to parse line {line_num} in {file_path}: {line[:50]}...")
        except Exception as e:
            print(f"Error parsing file {file_path}: {str(e)}")
        
        return structured_data
    
    def save_parsed_data(self, data, source_file):
        """Save parsed data to the output directory"""
        if not data:
            return
        
        timestamp = int(time.time())
        base_name = os.path.splitext(os.path.basename(source_file))[0]
        output_file = os.path.join(self.output_dir, f"parsed_{base_name}_{timestamp}.json")
        
        try:
            with open(output_file, 'w') as f:
                json.dump(data, f, indent=2)
            print(f"Saved {len(data)} parsed log entries to {output_file}")
        except Exception as e:
            print(f"Error saving parsed data: {str(e)}")
    
    def run(self):
        """Run the parser continuously"""
        print(f"Starting log parser watching {self.input_dir}")
        print(f"Parsing logs as {self.format_name} format")
        print(f"Storing parsed data in {self.output_dir}")
        
        while True:
            try:
                # Get list of files in the input directory
                input_files = [
                    os.path.join(self.input_dir, f) 
                    for f in os.listdir(self.input_dir) 
                    if os.path.isfile(os.path.join(self.input_dir, f)) and f.endswith('.log')
                ]
                
                # Process new files
                for file_path in input_files:
                    if file_path in self.processed_files:
                        continue
                    
                    print(f"Processing new file: {file_path}")
                    parsed_data = self.parse_file(file_path)
                    self.save_parsed_data(parsed_data, file_path)
                    
                    # Mark as processed
                    self.processed_files.add(file_path)
                    self._save_processed_files()
                
                time.sleep(self.interval)
            except KeyboardInterrupt:
                print("Log parsing stopped")
                break
            except Exception as e:
                print(f"Error in parser: {str(e)}")
                time.sleep(self.interval)

def main():
    parser = argparse.ArgumentParser(description='Parse logs into structured data')
    parser.add_argument('--input-dir', type=str, default='/data/collected', help='Input directory with collected logs')
    parser.add_argument('--output-dir', type=str, default='/data/parsed', help='Output directory for parsed data')
    parser.add_argument('--format', choices=['apache', 'nginx', 'app'], default='apache', help='Log format to parse')
    parser.add_argument('--interval', type=float, default=5.0, help='Polling interval in seconds')
    
    args = parser.parse_args()
    
    parser = LogParser(
        input_dir=args.input_dir,
        output_dir=args.output_dir,
        format_name=args.format,
        interval=args.interval
    )
    
    parser.run()

if __name__ == "__main__":
    main()