# query/query.py
import os
import argparse
import json
import re
from datetime import datetime

class LogQuery:
    def __init__(self, storage_dir):
        self.storage_dir = storage_dir
        self.index_dir = os.path.join(storage_dir, "index")
        self.active_dir = os.path.join(storage_dir, "active")
        self.archive_dir = os.path.join(storage_dir, "archive")
    
    def find_logs_by_index(self, index_type, index_value):
        """Find logs using the index"""
        index_file = os.path.join(self.index_dir, index_type, f"{index_value}.idx")
        
        if not os.path.exists(index_file):
            print(f"No index found for {index_type}={index_value}")
            return []
        
        results = []
        try:
            with open(index_file, 'r') as f:
                for line in f:
                    index_entry = json.loads(line.strip())
                    log_file = os.path.join(self.storage_dir, index_entry['file'])
                    line_number = index_entry.get('line', 0)
                    
                    if os.path.exists(log_file):
                        with open(log_file, 'r') as log_f:
                            log_data = json.load(log_f)
                            
                            # Find the entry based on line number if available
                            for entry in log_data:
                                if entry.get('line_number') == line_number:
                                    results.append(entry)
                                    break
        except Exception as e:
            print(f"Error searching index: {str(e)}")
        
        return results
    
    def search_all_logs(self, pattern):
        """Search all logs for a pattern"""
        results = []
        
        # Search in active logs
        for file_name in os.listdir(self.active_dir):
            if file_name.endswith('.json'):
                file_path = os.path.join(self.active_dir, file_name)
                results.extend(self._search_file(file_path, pattern))
        
        # Search in archived logs
        for archive_dir in os.listdir(self.archive_dir):
            archive_path = os.path.join(self.archive_dir, archive_dir)
            if os.path.isdir(archive_path):
                for file_name in os.listdir(archive_path):
                    if file_name.endswith('.json'):
                        file_path = os.path.join(archive_path, file_name)
                        results.extend(self._search_file(file_path, pattern))
        
        return results
    
    def _search_file(self, file_path, pattern):
        """Search a single file for the pattern"""
        results = []
        try:
            with open(file_path, 'r') as f:
                log_data = json.load(f)
                
                for entry in log_data:
                   # Search in the raw log entry
                   if 'raw' in entry and re.search(pattern, entry['raw'], re.IGNORECASE):
                       results.append(entry)
                   # Also search in the message field if present
                   elif 'message' in entry and re.search(pattern, entry['message'], re.IGNORECASE):
                       results.append(entry)
        except Exception as e:
           print(f"Error searching file {file_path}: {str(e)}")
       
        return results
   
    def display_results(self, results, format_output='text'):
       """Display search results in the requested format"""
       if not results:
           print("No matching logs found")
           return
       
       print(f"Found {len(results)} matching log entries:")
       
       if format_output == 'json':
           print(json.dumps(results, indent=2))
       else:  # text format
           for i, entry in enumerate(results, 1):
               print(f"\n--- Result {i} ---")
               if 'timestamp' in entry:
                   print(f"Time: {entry['timestamp']}")
               if 'level' in entry:
                   print(f"Level: {entry['level']}")
               if 'source_file' in entry:
                   print(f"Source: {entry['source_file']}")
               if 'raw' in entry:
                   print(f"Log: {entry['raw']}")
               print("-" * 40)

def main():
   parser = argparse.ArgumentParser(description='Query and search logs')
   parser.add_argument('--storage-dir', type=str, default='/data/storage', help='Storage directory for log data')
   parser.add_argument('--index-type', type=str, choices=['date', 'level', 'status', 'service'], help='Type of index to search')
   parser.add_argument('--index-value', type=str, help='Value to search for in the index')
   parser.add_argument('--pattern', type=str, help='Regular expression pattern to search for in logs')
   parser.add_argument('--format', type=str, choices=['text', 'json'], default='text', help='Output format')
   
   args = parser.parse_args()
   
   query_tool = LogQuery(args.storage_dir)
   
   results = []
   
   if args.index_type and args.index_value:
       print(f"Searching for logs with {args.index_type}={args.index_value}")
       results = query_tool.find_logs_by_index(args.index_type, args.index_value)
   elif args.pattern:
       print(f"Searching for logs matching pattern: {args.pattern}")
       results = query_tool.search_all_logs(args.pattern)
   else:
       print("Please specify either --index-type and --index-value, or --pattern")
       return
   
   query_tool.display_results(results, args.format)

if __name__ == "__main__":
   main()