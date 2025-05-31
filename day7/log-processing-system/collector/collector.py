# collector/collector.py
import time
import os
import argparse
import json
from pathlib import Path

class LogCollector:
    def __init__(self, source_path, output_dir, poll_interval=1.0):
        self.source_path = source_path
        self.output_dir = output_dir
        self.poll_interval = poll_interval
        self.last_position = 0
        
        # Ensure output directory exists
        Path(output_dir).mkdir(parents=True, exist_ok=True)
        
        # Create a file position tracker
        self.position_file = os.path.join(output_dir, "position_tracker.json")
        self._load_position()
    
    def _load_position(self):
        """Load the last read position from a file"""
        if os.path.exists(self.position_file):
            try:
                with open(self.position_file, 'r') as f:
                    data = json.load(f)
                    self.last_position = data.get(self.source_path, 0)
            except Exception as e:
                print(f"Error loading position data: {str(e)}")
    
    def _save_position(self):
        """Save the current read position to a file"""
        try:
            data = {}
            if os.path.exists(self.position_file):
                with open(self.position_file, 'r') as f:
                    data = json.load(f)
            
            data[self.source_path] = self.last_position
            
            with open(self.position_file, 'w') as f:
                json.dump(data, f)
        except Exception as e:
            print(f"Error saving position data: {str(e)}")
    
    def collect_logs(self):
        """Collect new log entries from the source file"""
        if not os.path.exists(self.source_path):
            print(f"Log file {self.source_path} does not exist. Waiting...")
            return []
        
        new_entries = []
        try:
            with open(self.source_path, 'r') as f:
                f.seek(self.last_position)
                for line in f:
                    new_entries.append(line.strip())
                
                self.last_position = f.tell()
                self._save_position()
        except Exception as e:
            print(f"Error collecting logs: {str(e)}")
        
        return new_entries
    
    def save_collected_logs(self, entries):
        """Save collected log entries to the output directory"""
        if not entries:
            return
        
        timestamp = int(time.time())
        output_file = os.path.join(self.output_dir, f"collected_{timestamp}.log")
        
        try:
            with open(output_file, 'w') as f:
                for entry in entries:
                    f.write(entry + '\n')
            print(f"Saved {len(entries)} log entries to {output_file}")
        except Exception as e:
            print(f"Error saving collected logs: {str(e)}")
    
    def run(self):
        """Run the collector continuously"""
        print(f"Starting log collector watching {self.source_path}")
        print(f"Storing collected logs in {self.output_dir}")
        
        while True:
            try:
                entries = self.collect_logs()
                if entries:
                    print(f"Collected {len(entries)} new log entries")
                    self.save_collected_logs(entries)
                
                time.sleep(self.poll_interval)
            except KeyboardInterrupt:
                print("Log collection stopped")
                break
            except Exception as e:
                print(f"Error in collector: {str(e)}")
                time.sleep(self.poll_interval)

def main():
    parser = argparse.ArgumentParser(description='Collect logs from local files')
    parser.add_argument('--source', type=str, default='/logs/app.log', help='Source log file to watch')
    parser.add_argument('--output-dir', type=str, default='/data/collected', help='Output directory for collected logs')
    parser.add_argument('--interval', type=float, default=1.0, help='Polling interval in seconds')
    
    args = parser.parse_args()
    
    collector = LogCollector(
        source_path=args.source,
        output_dir=args.output_dir,
        poll_interval=args.interval
    )
    
    collector.run()

if __name__ == "__main__":
    main()