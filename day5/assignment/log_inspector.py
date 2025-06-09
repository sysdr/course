# log_inspector.py
import os
import gzip
import glob
import argparse
import time 
def list_log_files(log_directory):
    """List all log files in the specified directory"""
    if not os.path.exists(log_directory):
        print(f"Directory {log_directory} does not exist.")
        return []
    
    # Get all log files (both plain and compressed)
    log_files = glob.glob(os.path.join(log_directory, "*.log")) + \
                glob.glob(os.path.join(log_directory, "*.log.gz"))
    
    # Sort by creation time (newest first)
    log_files.sort(key=os.path.getctime, reverse=True)
    
    return log_files

def read_log_file(log_file_path):
    """Read and return the content of a log file (compressed or not)"""
    if not os.path.exists(log_file_path):
        return f"File {log_file_path} does not exist."
    
    try:
        # Handle compressed files
        if log_file_path.endswith('.gz'):
            with gzip.open(log_file_path, 'rt', encoding='utf-8') as f:
                return f.read()
        else:
            # Regular file
            with open(log_file_path, 'r', encoding='utf-8') as f:
                return f.read()
    except Exception as e:
        return f"Error reading {log_file_path}: {str(e)}"

def search_in_logs(log_directory, search_text):
    """Search for text in all log files and return matching entries"""
    log_files = list_log_files(log_directory)
    results = []
    
    for log_file in log_files:
        content = read_log_file(log_file)
        for line_number, line in enumerate(content.split('\n'), 1):
            if search_text.lower() in line.lower():
                results.append({
                    'file': os.path.basename(log_file),
                    'line': line_number,
                    'content': line
                })
    
    return results

def main():
    parser = argparse.ArgumentParser(description='Log Inspector Tool')
    parser.add_argument('--dir', default='./logs', help='Log directory path')
    parser.add_argument('--list', action='store_true', help='List all log files')
    parser.add_argument('--read', help='Read a specific log file')
    parser.add_argument('--search', help='Search text in all log files')
    
    args = parser.parse_args()
    
    # List all log files
    if args.list:
        log_files = list_log_files(args.dir)
        if log_files:
            print(f"Found {len(log_files)} log files:")
            for i, file_path in enumerate(log_files, 1):
                file_size = os.path.getsize(file_path)
                file_time = os.path.getctime(file_path)
                print(f"{i}. {os.path.basename(file_path)} - {file_size/1024:.2f} KB, {time.ctime(file_time)}")
        else:
            print("No log files found.")
    
    # Read a specific log file
    elif args.read:
        file_path = os.path.join(args.dir, args.read)
        content = read_log_file(file_path)
        print(f"Content of {args.read}:")
        print("-" * 50)
        print(content)
        print("-" * 50)
    
    # Search in logs
    elif args.search:
        results = search_in_logs(args.dir, args.search)
        if results:
            print(f"Found {len(results)} matches for '{args.search}':")
            for i, result in enumerate(results, 1):
                print(f"{i}. {result['file']} (line {result['line']}): {result['content']}")
        else:
            print(f"No matches found for '{args.search}'.")
    
    else:
        parser.print_help()

if __name__ == "__main__":
    main()