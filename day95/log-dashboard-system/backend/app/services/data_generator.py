import random
import json
from datetime import datetime, timedelta
from typing import List, Dict, Any
from faker import Faker

fake = Faker()

class LogDataGenerator:
    def __init__(self):
        self.services = ['web-api', 'auth-service', 'db-service', 'cache-service']
        self.log_levels = ['INFO', 'WARNING', 'ERROR', 'DEBUG']
        self.endpoints = ['/api/users', '/api/orders', '/api/products', '/health']
        
    def generate_log_entry(self) -> Dict[str, Any]:
        return {
            'id': fake.uuid4(),
            'timestamp': datetime.now().isoformat(),
            'level': random.choice(self.log_levels),
            'service': random.choice(self.services),
            'endpoint': random.choice(self.endpoints),
            'message': fake.sentence(),
            'response_time': random.uniform(10, 500),
            'status_code': random.choices([200, 201, 400, 404, 500], weights=[70, 10, 10, 5, 5])[0],
            'user_id': fake.uuid4() if random.random() > 0.3 else None,
            'ip_address': fake.ipv4(),
        }
    
    def generate_log_batch(self, count: int = 10) -> List[Dict[str, Any]]:
        return [self.generate_log_entry() for _ in range(count)]
    
    def generate_metrics(self) -> Dict[str, Any]:
        return {
            'requests_per_second': random.uniform(100, 1000),
            'error_rate': random.uniform(0.01, 0.1),
            'avg_response_time': random.uniform(50, 200),
            'active_users': random.randint(500, 5000),
            'cpu_usage': random.uniform(0.1, 0.9),
            'memory_usage': random.uniform(0.3, 0.8),
            'disk_usage': random.uniform(0.2, 0.7),
        }
