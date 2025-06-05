# Create directory structure
mkdir -p log-parser-day4/{src,logs,docker}

# Create source files
cat > log-parser-day4/src/log_parser.py << 'EOF'
class LogParser:
   def __init__(self):
       # Dictionary to store different parser implementations
       self.parsers = {
           'apache': self.parse_apache_log,
           'nginx': self.parse_nginx_log,
           'json': self.parse_json_log
       }
       
   def detect_format(self, log_line):
       """Detect the format of a log line"""
       import json
       import re
       
       # Try to parse as JSON
       try:
           json.loads(log_line)
           return 'json'
       except ValueError:
           pass
       
       # Check for Apache/Nginx patterns
       apache_pattern = r'\S+ - - \[\d+/\w+/\d+:\d+:\d+:\d+ [\+\-]\d+\]'
       nginx_pattern = r'\S+ - \S+ \[\d+/\w+/\d+:\d+:\d+:\d+ [\+\-]\d+\]'
       
       if re.match(apache_pattern, log_line):
           return 'apache'
       elif re.match(nginx_pattern, log_line):
           return 'nginx'
       
       return 'unknown'
   
   def parse(self, log_line):
       """Parse a log line into structured data"""
       log_format = self.detect_format(log_line)
       
       if log_format in self.parsers:
           return self.parsers[log_format](log_line)
       else:
           return {'raw': log_line, 'format': 'unknown'}
   
   def parse_apache_log(self, log_line):
       """Parse Apache common log format"""
       import re
       pattern = r'(\S+) - - \[(\d+/\w+/\d+):(\d+:\d+:\d+) ([\+\-]\d+)\] "(\S+) (\S+) ([^"]+)" (\d+) (\d+|-)'
       match = re.match(pattern, log_line)
       
       if match:
           ip, date, time, timezone, method, path, protocol, status, size = match.groups()
           
           try:
               status_code = int(status)
               size = int(size) if size != '-' else 0
           except ValueError:
               status_code = 0
               size = 0
               
           # Convert Apache date format to ISO format
           from datetime import datetime
           try:
               dt = datetime.strptime(f"{date}:{time} {timezone}", "%d/%b/%Y:%H:%M:%S %z")
               timestamp = dt.isoformat()
           except ValueError:
               timestamp = f"{date}T{time}{timezone}"
               
           return {
               'timestamp': timestamp,
               'source_ip': ip,
               'method': method,
               'path': path,
               'protocol': protocol,
               'status_code': status_code,
               'size': size,
               'format': 'apache'
           }
       
       return {'raw': log_line, 'format': 'unknown'}
   
   def parse_nginx_log(self, log_line):
       """Parse Nginx access log format"""
       import re
       pattern = r'(\S+) - (\S+) \[(\d+/\w+/\d+):(\d+:\d+:\d+) ([\+\-]\d+)\] "(\S+) (\S+) ([^"]+)" (\d+) (\d+) "([^"]*)" "([^"]*)"'
       match = re.match(pattern, log_line)
       
       if match:
           ip, user, date, time, timezone, method, path, protocol, status, size, referrer, user_agent = match.groups()
           
           try:
               status_code = int(status)
               size = int(size)
           except ValueError:
               status_code = 0
               size = 0
               
           # Convert Nginx date format to ISO format
           from datetime import datetime
           try:
               dt = datetime.strptime(f"{date}:{time} {timezone}", "%d/%b/%Y:%H:%M:%S %z")
               timestamp = dt.isoformat()
           except ValueError:
               timestamp = f"{date}T{time}{timezone}"
               
           return {
               'timestamp': timestamp,
               'source_ip': ip,
               'user': user if user != '-' else None,
               'method': method,
               'path': path,
               'protocol': protocol,
               'status_code': status_code,
               'size': size,
               'referrer': referrer if referrer != '-' else None,
               'user_agent': user_agent,
               'format': 'nginx'
           }
       
       return {'raw': log_line, 'format': 'unknown'}
   
   def parse_json_log(self, log_line):
       """Parse JSON log format"""
       import json
       try:
           data = json.loads(log_line)
           
           # Add standard format indicator
           data['format'] = 'json'
           
           # Map common fields to our schema if they exist with different names
           field_mappings = {
               'ip': 'source_ip',
               'level': 'log_level',
               'msg': 'message',
               'time': 'timestamp'
           }
           
           for src, dst in field_mappings.items():
               if src in data and dst not in data:
                   data[dst] = data[src]
                   
           return data
       except json.JSONDecodeError:
           return {'raw': log_line, 'format': 'unknown'}
EOF

cat > log-parser-day4/src/log_parser_demo.py << 'EOF'
#!/usr/bin/env python3
# log_parser_demo.py

from log_parser import LogParser
import json

# Sample logs for testing
sample_logs = [
   # Apache log
   '192.168.1.20 - - [28/Jul/2023:10:27:10 +0000] "GET /index.html HTTP/1.1" 200 2326',
   # Nginx log
   '192.168.1.10 - john [28/Jul/2023:10:27:10 +0000] "GET /api/users HTTP/1.1" 404 52 "https://example.com" "Mozilla/5.0"',
   # JSON log
   '{"timestamp": "2023-07-28T10:27:10Z", "level": "ERROR", "message": "Database connection failed", "service": "user-api"}'
]

def main():
   # Create our parser
   parser = LogParser()
   
   print("Log Parser Demo")
   print("=" * 50)
   
   # Parse each sample log
   for i, log in enumerate(sample_logs):
       print(f"\nLog #{i+1}:")
       print(f"Raw: {log[:60]}..." if len(log) > 60 else f"Raw: {log}")
       
       # Detect format
       format_type = parser.detect_format(log)
       print(f"Detected Format: {format_type}")
       
       # Parse the log
       parsed = parser.parse(log)
       
       # Print the parsed result in a pretty format
       print("Parsed Result:")
       print(json.dumps(parsed, indent=2))
       print("-" * 50)

if __name__ == "__main__":
   main()
EOF

cat > log-parser-day4/src/log_processing_service.py << 'EOF'
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
   log_dir = os.environ.get('LOG_DIR', '/logs')
   
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
EOF

# Create sample log files
mkdir -p log-parser-day4/logs
cat > log-parser-day4/logs/apache.log << 'EOF'
192.168.1.20 - - [28/Jul/2023:10:27:10 +0000] "GET /index.html HTTP/1.1" 200 2326
192.168.1.21 - - [28/Jul/2023:10:28:15 +0000] "POST /login HTTP/1.1" 302 0
192.168.1.22 - - [28/Jul/2023:10:29:20 +0000] "GET /dashboard HTTP/1.1" 200 5823
192.168.1.23 - - [28/Jul/2023:10:30:25 +0000] "GET /api/data HTTP/1.1" 404 124
EOF

cat > log-parser-day4/logs/nginx.log << 'EOF'
192.168.1.10 - john [28/Jul/2023:10:27:10 +0000] "GET /api/users HTTP/1.1" 404 52 "https://example.com" "Mozilla/5.0"
192.168.1.11 - jane [28/Jul/2023:10:28:15 +0000] "POST /api/upload HTTP/1.1" 201 0 "https://example.com/form" "Chrome/98.0"
192.168.1.12 - bob [28/Jul/2023:10:29:20 +0000] "GET /api/products HTTP/1.1" 200 1024 "https://example.com/shop" "Firefox/95.0"
EOF

cat > log-parser-day4/logs/app.log << 'EOF'
{"timestamp": "2023-07-28T10:27:10Z", "level": "ERROR", "message": "Database connection failed", "service": "user-api"}
{"timestamp": "2023-07-28T10:28:15Z", "level": "INFO", "message": "User logged in", "service": "auth-service", "user_id": 12345}
{"timestamp": "2023-07-28T10:29:20Z", "level": "WARN", "message": "High CPU usage detected", "service": "monitoring", "usage": 85.2}
EOF

# Create Docker files
cat > log-parser-day4/docker/Dockerfile << 'EOF'
# Use Python 3.9 slim image as base
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy our log parser files
COPY ../src/log_parser.py /app/
COPY ../src/log_parser_demo.py /app/

# Make the demo script executable
RUN chmod +x /app/log_parser_demo.py

# Create a directory for logs
RUN mkdir -p /logs

# Entry point
ENTRYPOINT ["python3", "log_parser_demo.py"]
EOF

cat > log-parser-day4/docker/Dockerfile.service << 'EOF'
# Use Python 3.9 slim image as base
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy our log parser files
COPY ../src/log_parser.py /app/
COPY ../src/log_processing_service.py /app/

# Install required packages
RUN pip install watchdog

# Make the script executable
RUN chmod +x /app/log_processing_service.py

# Create a directory for logs
RUN mkdir -p /logs

# Set environment variables
ENV LOG_DIR=/logs

# Entry point
CMD ["python", "log_processing_service.py"]
EOF

cat > log-parser-day4/docker-compose.yml << 'EOF'
version: '3'

services:
 log-parser-demo:
   build:
     context: .
     dockerfile: docker/Dockerfile
   volumes:
     - ./logs:/logs

 log-processing-service:
   build:
     context: .
     dockerfile: docker/Dockerfile.service
   volumes:
     - ./logs:/logs
EOF