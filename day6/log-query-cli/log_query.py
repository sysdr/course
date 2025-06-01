#!/usr/bin/env python3
import argparse
import re
import sys
from datetime import datetime

def parse_arguments():
    parser = argparse.ArgumentParser(description='Query and filter log files')
    parser.add_argument('logfile', help='Log file to query')
    parser.add_argument('-l', '--level', choices=['INFO', 'WARN', 'ERROR', 'DEBUG'],
                      help='Filter by log level')
    parser.add_argument('-s', '--search', help='Search term in log message')
    parser.add_argument('-d', '--date', help='Filter by date (YYYY-MM-DD)')
    parser.add_argument('-t', '--time-range', help='Time range (HH:MM-HH:MM)')
    parser.add_argument('-n', '--lines', type=int, default=0, help='Show only N lines')
    return parser.parse_args()

def parse_log_line(line):
    """Parse a log line into components."""
    # Basic pattern for: [DATE TIME] [LEVEL] MESSAGE
    pattern = r'\[(.*?)\] \[(.*?)\] (.*)'
    match = re.match(pattern, line)
    if match:
        timestamp_str, level, message = match.groups()
        try:
            timestamp = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
            return {
                'timestamp': timestamp,
                'level': level,
                'message': message,
                'raw': line.strip()
            }
        except ValueError:
            return None
    return None

def filter_log_entries(entries, args):
    """Filter log entries based on command line arguments."""
    filtered = entries
    
    # Filter by log level
    if args.level:
        filtered = [entry for entry in filtered if entry['level'] == args.level]
    
    # Filter by search term
    if args.search:
        filtered = [entry for entry in filtered if args.search.lower() in entry['message'].lower()]
    
    # Filter by date
    if args.date:
        target_date = datetime.strptime(args.date, '%Y-%m-%d').date()
        filtered = [entry for entry in filtered if entry['timestamp'].date() == target_date]
    
    # Filter by time range
    if args.time_range:
        start_time, end_time = args.time_range.split('-')
        start_hour, start_minute = map(int, start_time.split(':'))
        end_hour, end_minute = map(int, end_time.split(':'))
        
        def in_time_range(entry):
            t = entry['timestamp']
            entry_time = t.hour * 60 + t.minute  # Convert to minutes
            start_time_mins = start_hour * 60 + start_minute
            end_time_mins = end_hour * 60 + end_minute
            return start_time_mins <= entry_time <= end_time_mins
        
        filtered = [entry for entry in filtered if in_time_range(entry)]
    
    # Limit number of results
    if args.lines > 0:
        filtered = filtered[:args.lines]
    
    return filtered

def main():
    args = parse_arguments()
    
    try:
        # Read and parse log file
        with open(args.logfile, 'r') as f:
            log_lines = f.readlines()
        
        # Parse each line into structured format
        entries = []
        for line in log_lines:
            entry = parse_log_line(line)
            if entry:
                entries.append(entry)
        
        # Apply filters based on arguments
        filtered_entries = filter_log_entries(entries, args)
        
        # Display results
        for entry in filtered_entries:
            print(entry['raw'])
        
        # Print summary
        print(f"\nFound {len(filtered_entries)} matching entries out of {len(entries)} total logs.")
    
    except FileNotFoundError:
        print(f"Error: Log file '{args.logfile}' not found.")
        return 1
    except Exception as e:
        print(f"Error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())