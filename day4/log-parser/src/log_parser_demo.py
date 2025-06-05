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
