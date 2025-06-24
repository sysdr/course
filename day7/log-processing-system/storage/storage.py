# storage/storage.py
import os
import argparse
import json
import time
import shutil
from pathlib import Path
from datetime import datetime, timedelta

class LogStorage:
    def __init__(self, input_dir, storage_dir, rotation_size=10, rotation_hours=24, interval=10.0):
        self.input_dir = input_dir
        self.storage_dir = storage_dir
        self.rotation_size_mb = rotation_size
        self.rotation_hours = rotation_hours
        self.interval = interval
        self.processed_files = set()
        
        # Ensure storage directory exists
        Path(storage_dir).mkdir(parents=True, exist_ok=True)
        
        # Create index directory
        self.index_dir = os.path.join(storage_dir, "index")
        Path(self.index_dir).mkdir(parents=True, exist_ok=True)
        
        # Create active storage directory
        self.active_dir = os.path.join(storage_dir, "active")
        Path(self.active_dir).mkdir(parents=True, exist_ok=True)
        
        # Create archive directory
        self.archive_dir = os.path.join(storage_dir, "archive")
        Path(self.archive_dir).mkdir(parents=True, exist_ok=True)
        
        # Create tracking file
        self.tracking_file = os.path.join(storage_dir, "storage_tracking.json")
        self._load_tracking_data()
    
    def _load_tracking_data(self):
        """Load tracking data from file"""
        if os.path.exists(self.tracking_file):
            try:
                with open(self.tracking_file, 'r') as f:
                    data = json.load(f)
                    self.processed_files = set(data.get('processed_files', []))
            except Exception as e:
                print(f"Error loading tracking data: {str(e)}")
                self.processed_files = set()
        else:
            self.processed_files = set()
    
    def _save_tracking_data(self):
        """Save tracking data to file"""
        try:
            data = {
                'processed_files': list(self.processed_files),
                'last_updated': datetime.now().isoformat()
            }
            with open(self.tracking_file, 'w') as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"Error saving tracking data: {str(e)}")
    
    def _update_index(self, parsed_data, storage_file):
        """Update the index with information about where logs are stored"""
        # Create a simple index entry for each log
        for entry in parsed_data:
            # Create index keys based on different fields
            index_keys = []
            
            # Index by timestamp (day)
            if 'timestamp' in entry:
                try:
                    # Try to parse the timestamp, this might need adjustment based on format
                    ts = entry['timestamp']
                    day = ts.split(':')[0]  # Simple approach - just use the date part
                    index_keys.append(('date', day))
                except:
                    pass
            
            # Index by level if present
            if 'level' in entry:
                index_keys.append(('level', entry['level']))
            
            # Index by status if present
            if 'status' in entry:
                index_keys.append(('status', str(entry['status'])))
            
            # Index by service if present
            if 'service' in entry:
                index_keys.append(('service', entry['service']))
            
            # Create index entries
            for key_type, key_value in index_keys:
                index_dir = os.path.join(self.index_dir, key_type)
                Path(index_dir).mkdir(parents=True, exist_ok=True)
                
                index_file = os.path.join(index_dir, f"{key_value}.idx")
                index_entry = {
                    'file': storage_file,
                    'line': entry.get('line_number', 0)
                }
                
                # Append to index file
                try:
                    with open(index_file, 'a') as f:
                        f.write(json.dumps(index_entry) + '\n')
                except Exception as e:
                    print(f"Error updating index: {str(e)}")
    
    def store_logs(self, file_path):
        """Store logs from parsed data file into storage system"""
        try:
            with open(file_path, 'r') as f:
                parsed_data = json.load(f)
            
            if not parsed_data:
                return
            
            # Create storage file
            timestamp = int(time.time())
            storage_file = os.path.join(self.active_dir, f"logs_{timestamp}.json")
            
            # Store the data
            with open(storage_file, 'w') as f:
                json.dump(parsed_data, f, indent=2)
            
            # Update index
            self._update_index(parsed_data, os.path.relpath(storage_file, self.storage_dir))
            
            print(f"Stored {len(parsed_data)} log entries in {storage_file}")
            return storage_file
        except Exception as e:
            print(f"Error storing logs from {file_path}: {str(e)}")
            return None
    
    def check_rotation(self):
        """Check if rotation is needed based on size or time"""
        active_files = [
            os.path.join(self.active_dir, f)
            for f in os.listdir(self.active_dir)
            if os.path.isfile(os.path.join(self.active_dir, f))
        ]
        
        if not active_files:
            return
        
        # Check size-based rotation
        total_size_mb = sum(os.path.getsize(f) for f in active_files) / (1024 * 1024)
        if total_size_mb >= self.rotation_size_mb:
            self.rotate_logs("size")
            return
        
        # Check time-based rotation
        oldest_file = min(active_files, key=os.path.getctime, default=None)
        if oldest_file:
            create_time = datetime.fromtimestamp(os.path.getctime(oldest_file))
            if datetime.now() - create_time > timedelta(hours=self.rotation_hours):
                self.rotate_logs("time")
    
    def rotate_logs(self, reason):
        """Rotate logs from active to archive"""
        print(f"Rotating logs due to {reason} trigger")
        
        timestamp = int(time.time())
        archive_dir = os.path.join(self.archive_dir, f"rotated_{timestamp}")
        Path(archive_dir).mkdir(parents=True, exist_ok=True)
        
        # Move all files from active to archive
        for file_name in os.listdir(self.active_dir):
            source_path = os.path.join(self.active_dir, file_name)
            target_path = os.path.join(archive_dir, file_name)
            
            if os.path.isfile(source_path):
                shutil.move(source_path, target_path)
        
        print(f"Rotated logs to {archive_dir}")
    
    def run(self):
        """Run the storage system continuously"""
        print(f"Starting log storage system")
        print(f"Watching for parsed logs in {self.input_dir}")
        print(f"Storing logs in {self.storage_dir}")
        print(f"Rotation policy: {self.rotation_size_mb}MB or {self.rotation_hours} hours")
        
        while True:
            try:
                # Check for new parsed log files
                input_files = [
                    os.path.join(self.input_dir, f)
                    for f in os.listdir(self.input_dir)
                    if os.path.isfile(os.path.join(self.input_dir, f)) and f.endswith('.json')
                ]
                
                # Process new files
                for file_path in input_files:
                    if file_path in self.processed_files:
                        continue
                    
                    print(f"Processing parsed file: {file_path}")
                    self.store_logs(file_path)
                    
                    # Mark as processed
                    self.processed_files.add(file_path)
                    self._save_tracking_data()
                
                # Check if rotation is needed
                self.check_rotation()
                
                time.sleep(self.interval)
            except KeyboardInterrupt:
                print("Log storage stopped")
                break
            except Exception as e:
                print(f"Error in storage system: {str(e)}")
                time.sleep(self.interval)

def main():
    parser = argparse.ArgumentParser(description='Store and manage logs with rotation policies')
    parser.add_argument('--input-dir', type=str, default='/data/parsed', help='Input directory with parsed logs')
    parser.add_argument('--storage-dir', type=str, default='/data/storage', help='Storage directory for log data')
    parser.add_argument('--rotation-size', type=int, default=10, help='Size-based rotation trigger in MB')
    parser.add_argument('--rotation-hours', type=int, default=24, help='Time-based rotation trigger in hours')
    parser.add_argument('--interval', type=float, default=10.0, help='Polling interval in seconds')
    
    args = parser.parse_args()
    
    storage = LogStorage(
        input_dir=args.input_dir,
        storage_dir=args.storage_dir,
        rotation_size=args.rotation_size,
        rotation_hours=args.rotation_hours,
        interval=args.interval
    )
    
    storage.run()

if __name__ == "__main__":
    main()