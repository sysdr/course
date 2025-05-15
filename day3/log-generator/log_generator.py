#!/usr/bin/env python3
"""
Simple Log Generator

Generates sample logs at a configurable rate.
"""

import os
import time
import json
import random
import argparse
from datetime import datetime

def generate_log(log_type):
    """Generate a sample log entry"""
    timestamp = datetime.now().isoformat()
    
    if log_type == "json":
        services = ["web", "api", "database", "cache", "auth"]
        levels = ["INFO", "WARNING", "ERROR", "DEBUG"]
        
        return json.dumps({
            "timestamp": timestamp,
            "service": random.choice(services),
            "level": random.choice(levels),
            "message": f"Sample log message {random.randint(1000, 9999)}",
            "data": {
                "value": random.random(),
                "count": random.randint(1, 100)
            }
        })
    else:
        # Plain text logs
        return f"{timestamp} - Sample log entry #{random.randint(1000, 9999)}"

def main():
    parser = argparse.ArgumentParser(description='Generate sample logs')
    parser.add_argument('--file', default='logs/application.log', help='Log file path')
    parser.add_argument('--rate', type=float, default=1.0, help='Logs per second')
    parser.add_argument('--type', choices=['json', 'text'], default='json', help='Log format')
    
    args = parser.parse_args()
    
    # Create directory for log file if it doesn't exist
    os.makedirs(os.path.dirname(args.file), exist_ok=True)
    
    print(f"Generating {args.type} logs at {args.rate} per second to {args.file}")
    
    try:
        while True:
            log_entry = generate_log(args.type)
            
            with open(args.file, 'a') as f:
                f.write(log_entry + "\n")
                
            # Calculate sleep time to maintain the desired rate
            sleep_time = 1.0 / args.rate
            time.sleep(sleep_time)
            
    except KeyboardInterrupt:
        print("Log generation stopped")

if __name__ == "__main__":
    main()
