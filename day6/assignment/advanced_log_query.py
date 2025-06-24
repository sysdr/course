#!/usr/bin/env python3
import argparse
import re
import sys
import json
import glob
from datetime import datetime
from collections import Counter

# ANSI color codes for colorized output
COLORS = {
    'INFO': '\033[94m',    # Blue
    'WARN': '\033[93m',    # Yellow
    'ERROR': '\033[91m',   # Red
    'DEBUG': '\033[92m',   # Green
    'RESET': '\033[0m'     # Reset
}

def parse_arguments():
    parser = argparse.ArgumentParser(description='Advanced log file query and analysis tool')
    parser.add_argument('logfiles', nargs='+', help='Log file(s) to query (supports wildcards)')
    parser.add_argument('-l', '--level', choices=['INFO', 'WARN', 'ERROR', 'DEBUG'],
                      help='Filter by log level')
    parser.add_argument('-s', '--search', help='Search term in log message')
    parser.add_argument('-d', '--date', help='Filter by date (YYYY-MM-DD)')
    parser.add_argument('-t', '--time-range', help='Time range (HH:MM-HH:MM)')
    parser.add_argument('-n', '--lines', type=int, default=0, help='Show only N lines')
    parser.add_argument('--stats', action='store_true', help='Show log statistics')
    parser.add_argument('--output', choices=['text', 'json'], default='text', 
                      help='Output format (text or JSON)')
    parser.add_argument('--color', action='store_true', help='Colorize output based on log level')
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
            entry_time = t.hour * 60 + t.minute
            start_time_mins = start_hour * 60 + start_minute
            end_time_mins = end_hour * 60 + end_minute
            return start_time_mins <= entry_time <= end_time_mins
        
        filtered = [entry for entry in filtered if in_time_range(entry)]
    
    # Limit number of results
    if args.lines > 0:
        filtered = filtered[:args.lines]
    
    return filtered

def calculate_statistics(entries):
    """Calculate statistics from log entries."""
    stats = {
        'total_entries': len(entries),
        'entries_by_level': {},
        'entries_by_hour': {},
        'common_errors': [],
        'earliest_log': None,
        'latest_log': None
    }
    
    # Count by level
    level_counter = Counter(entry['level'] for entry in entries)
    stats['entries_by_level'] = dict(level_counter)
    
    # Count by hour
    hour_counter = Counter(entry['timestamp'].hour for entry in entries)
    stats['entries_by_hour'] = {f"{hour:02d}:00": count for hour, count in sorted(hour_counter.items())}
    
    # Find common errors
    if entries:
        error_entries = [entry for entry in entries if entry['level'] == 'ERROR']
        error_messages = [entry['message'] for entry in error_entries]
        common_errors = Counter(error_messages).most_common(5)
        stats['common_errors'] = [{'message': msg, 'count': count} for msg, count in common_errors]
    
    # Find time range
    if entries:
        timestamps = [entry['timestamp'] for entry in entries]
        stats['earliest_log'] = min(timestamps).strftime('%Y-%m-%d %H:%M:%S')
        stats['latest_log'] = max(timestamps).strftime('%Y-%m-%d %H:%M:%S')
        
        # Calculate hourly average
        if stats['earliest_log'] != stats['latest_log']:
            earliest = min(timestamps)
            latest = max(timestamps)
            hours_diff = (latest - earliest).total_seconds() / 3600
            if hours_diff > 0:
                stats['avg_entries_per_hour'] = round(len(entries) / hours_diff, 2)
    
    return stats

def colorize_log_entry(entry, colored=False):
    """Add color to log entry based on level."""
    if not colored:
        return entry['raw']
        
    level = entry['level']
    if level in COLORS:
        # Extract the level part from the raw log and replace it with colored version
        raw = entry['raw']
        level_pattern = f"\\[{level}\\]"
        colored_level = f"{COLORS[level]}[{level}]{COLORS['RESET']}"
        return re.sub(level_pattern, colored_level, raw)
    return entry['raw']

def display_results(filtered_entries, all_entries, args):
    """Display results based on output format and other settings."""
    # If stats mode is enabled, show statistics first
    if args.stats:
        stats = calculate_statistics(all_entries)
        filtered_stats = calculate_statistics(filtered_entries)
        
        if args.output == 'json':
            print(json.dumps({
                'all_logs_stats': stats,
                'filtered_logs_stats': filtered_stats
            }, indent=2, default=str))
        else:
            print("\n===== LOG STATISTICS =====")
            print(f"Total log entries: {stats['total_entries']}")
            print(f"Matching entries: {len(filtered_entries)}")
            
            print("\nEntries by level:")
            for level, count in stats['entries_by_level'].items():
                percent = (count / stats['total_entries']) * 100 if stats['total_entries'] > 0 else 0
                print(f"  {level}: {count} ({percent:.1f}%)")
            
            if 'avg_entries_per_hour' in stats:
                print(f"\nAverage entries per hour: {stats['avg_entries_per_hour']}")
            
            print("\nEntries by hour:")
            for hour, count in stats['entries_by_hour'].items():
                print(f"  {hour}: {count}")
            
            if stats['common_errors']:
                print("\nMost common errors:")
                for i, error in enumerate(stats['common_errors'], 1):
                    print(f"  {i}. '{error['message']}' - {error['count']} occurrences")
            
            print(f"\nTime range: {stats['earliest_log']} to {stats['latest_log']}")
            print("===========================\n")
    
    # Display the filtered log entries
    if args.output == 'json':
        # Convert entries to JSON-serializable format
        json_entries = []
        for entry in filtered_entries:
            json_entry = {
                'timestamp': entry['timestamp'].strftime('%Y-%m-%d %H:%M:%S'),
                'level': entry['level'],
                'message': entry['message']
            }
            json_entries.append(json_entry)
        print(json.dumps({'entries': json_entries}, indent=2))
    else:
        # Text output
        for entry in filtered_entries:
            print(colorize_log_entry(entry, args.color))
        
        # Print summary (unless we're in stats mode which already showed this)
        if not args.stats:
            print(f"\nFound {len(filtered_entries)} matching entries out of {len(all_entries)} total logs.")

def expand_file_paths(file_patterns):
    """Expand wildcards in file paths."""
    expanded_files = []
    for pattern in file_patterns:
        matched_files = glob.glob(pattern)
        if matched_files:
            expanded_files.extend(matched_files)
        else:
            print(f"Warning: No files match pattern '{pattern}'")
    return expanded_files

def main():
    args = parse_arguments()
    
    try:
        # Expand file patterns (handle wildcards)
        log_files = expand_file_paths(args.logfiles)
        
        if not log_files:
            print("Error: No log files found.")
            return 1
        
        # Read and parse all log files
        all_entries = []
        for log_file in log_files:
            try:
                with open(log_file, 'r') as f:
                    log_lines = f.readlines()
                
                # Parse each line into structured format
                for line in log_lines:
                    entry = parse_log_line(line)
                    if entry:
                        entry['source_file'] = log_file
                        all_entries.append(entry)
            except Exception as e:
                print(f"Warning: Could not process file '{log_file}': {e}")
        
        # Sort entries by timestamp
        all_entries.sort(key=lambda e: e['timestamp'])
        
        # Apply filters based on arguments
        filtered_entries = filter_log_entries(all_entries, args)
        
        # Display results
        display_results(filtered_entries, all_entries, args)
    
    except Exception as e:
        print(f"Error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())