# generator/generator.py
import time
import random
import datetime
import os
import argparse
from pathlib import Path

# Log format templates
LOG_FORMATS = {
    'apache': '{ip} - - [{timestamp}] "GET /api/{endpoint} HTTP/1.1" {status} {size}',
    'nginx': '{timestamp} [{level}] {process}: {message}',
    'app': '[{timestamp}] {level} [{service}] {message}'
}

# Sample data for generating logs
SAMPLE_DATA = {
    'ip': ['192.168.1.1', '10.0.0.2', '172.16.254.1', '8.8.8.8', '1.1.1.1'],
    'endpoint': ['users', 'products', 'orders', 'auth', 'search', 'health'],
    'status': [200, 200, 200, 201, 204, 400, 401, 403, 404, 500],
    'size': list(range(100, 10000, 100)),
    'level': ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
    'service': ['auth', 'payment', 'inventory', 'shipping', 'notification'],
    'message': [
        'User logged in successfully',
        'Payment processed',
        'Failed to connect to database',
        'Order created',
        'Invalid authentication token',
        'Service started',
        'Service stopped',
        'Connection timeout',
        'API request received',
        'Cache miss'
    ],
    'process': ['worker1', 'worker2', 'worker3', 'main', 'background']
}

def generate_log_entry(log_format):
    """Generate a single log entry based on the specified format"""
    now = datetime.datetime.now().strftime('%d/%b/%Y:%H:%M:%S +0000')
    
    if log_format == 'apache':
        return LOG_FORMATS['apache'].format(
            ip=random.choice(SAMPLE_DATA['ip']),
            timestamp=now,
            endpoint=random.choice(SAMPLE_DATA['endpoint']),
            status=random.choice(SAMPLE_DATA['status']),
            size=random.choice(SAMPLE_DATA['size'])
        )
    elif log_format == 'nginx':
        return LOG_FORMATS['nginx'].format(
            timestamp=now,
            level=random.choice(SAMPLE_DATA['level']),
            process=random.choice(SAMPLE_DATA['process']),
            message=random.choice(SAMPLE_DATA['message'])
        )
    else:  # app format
        return LOG_FORMATS['app'].format(
            timestamp=now,
            level=random.choice(SAMPLE_DATA['level']),
            service=random.choice(SAMPLE_DATA['service']),
            message=random.choice(SAMPLE_DATA['message'])
        )

def main():
    parser = argparse.ArgumentParser(description='Generate sample logs at a configurable rate')
    parser.add_argument('--format', choices=['apache', 'nginx', 'app'], default='apache', help='Log format to generate')
    parser.add_argument('--rate', type=float, default=1.0, help='Logs per second to generate')
    parser.add_argument('--output', type=str, default='/logs/app.log', help='Output file path')
    
    args = parser.parse_args()
    
    # Ensure the logs directory exists
    Path(os.path.dirname(args.output)).mkdir(parents=True, exist_ok=True)
    
    print(f"Starting log generator with format: {args.format}, rate: {args.rate} logs/sec")
    print(f"Writing logs to: {args.output}")
    
    while True:
        try:
            log_entry = generate_log_entry(args.format)
            with open(args.output, 'a') as f:
                f.write(log_entry + '\n')
            
            # Sleep to maintain the requested rate
            time.sleep(1.0 / args.rate)
        except KeyboardInterrupt:
            print("Log generation stopped")
            break
        except Exception as e:
            print(f"Error generating log: {str(e)}")
            continue

if __name__ == "__main__":
    main()