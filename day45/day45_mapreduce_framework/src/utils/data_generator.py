import json
import random
import os
from datetime import datetime, timedelta
from typing import List

class LogDataGenerator:
    """Generate sample log data for testing MapReduce framework"""
    
    def __init__(self):
        self.services = ['user-service', 'api-gateway', 'database', 'auth-service', 'payment-service']
        self.log_levels = ['INFO', 'DEBUG', 'WARNING', 'ERROR', 'CRITICAL']
        self.error_messages = [
            'Connection timeout',
            'Database query failed',
            'Authentication failed',
            'Payment processing error',
            'Service unavailable',
            'Invalid request parameters',
            'Rate limit exceeded',
            'Internal server error'
        ]
        self.ip_addresses = [f"192.168.1.{i}" for i in range(1, 256)]
        
    def generate_json_logs(self, num_logs: int, output_file: str):
        """Generate JSON format logs"""
        logs = []
        base_time = datetime.now() - timedelta(days=7)
        
        for i in range(num_logs):
            timestamp = base_time + timedelta(
                seconds=random.randint(0, 7 * 24 * 3600)
            )
            
            log_entry = {
                'timestamp': timestamp.isoformat(),
                'service': random.choice(self.services),
                'level': random.choice(self.log_levels),
                'message': self._generate_message(),
                'request_id': f"req_{random.randint(100000, 999999)}",
                'user_id': f"user_{random.randint(1000, 9999)}",
                'ip_address': random.choice(self.ip_addresses),
                'response_time': random.randint(10, 2000),
                'status_code': random.choice([200, 201, 400, 401, 403, 404, 500, 502, 503])
            }
            
            logs.append(json.dumps(log_entry))
        
        with open(output_file, 'w') as f:
            f.write('\n'.join(logs))
        
        print(f"Generated {num_logs} JSON logs in {output_file}")
    
    def generate_apache_logs(self, num_logs: int, output_file: str):
        """Generate Apache/Nginx style logs"""
        logs = []
        base_time = datetime.now() - timedelta(days=7)
        
        for i in range(num_logs):
            timestamp = base_time + timedelta(
                seconds=random.randint(0, 7 * 24 * 3600)
            )
            
            ip = random.choice(self.ip_addresses)
            method = random.choice(['GET', 'POST', 'PUT', 'DELETE'])
            endpoint = random.choice([
                '/api/users', '/api/orders', '/api/products', 
                '/login', '/logout', '/dashboard', '/health'
            ])
            status = random.choice([200, 201, 400, 401, 403, 404, 500, 502])
            size = random.randint(100, 10000)
            user_agent = random.choice([
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
                'curl/7.68.0', 'Python-requests/2.25.1'
            ])
            
            log_line = f'{ip} - - [{timestamp.strftime("%d/%b/%Y:%H:%M:%S +0000")}] "{method} {endpoint} HTTP/1.1" {status} {size} "-" "{user_agent}"'
            logs.append(log_line)
        
        with open(output_file, 'w') as f:
            f.write('\n'.join(logs))
        
        print(f"Generated {num_logs} Apache-style logs in {output_file}")
    
    def _generate_message(self) -> str:
        """Generate realistic log messages"""
        message_types = [
            f"Processing request for endpoint {random.choice(['/api/users', '/api/orders', '/api/products'])}",
            f"Database query executed in {random.randint(1, 100)}ms",
            f"User authentication {random.choice(['successful', 'failed'])}",
            f"Cache {random.choice(['hit', 'miss'])} for key {random.randint(1000, 9999)}",
            random.choice(self.error_messages),
            f"Service health check {random.choice(['passed', 'failed'])}",
            f"Rate limiting applied to IP {random.choice(self.ip_addresses)}"
        ]
        
        return random.choice(message_types)

def generate_sample_data():
    """Generate sample data for testing"""
    generator = LogDataGenerator()
    
    # Ensure output directory exists
    os.makedirs('data/input', exist_ok=True)
    
    # Generate different types of logs
    generator.generate_json_logs(10000, 'data/input/json_logs.txt')
    generator.generate_apache_logs(5000, 'data/input/apache_logs.txt')
    
    # Generate large dataset for performance testing
    generator.generate_json_logs(50000, 'data/input/large_dataset.txt')
    
    print("Sample data generation completed!")

if __name__ == "__main__":
    generate_sample_data()
