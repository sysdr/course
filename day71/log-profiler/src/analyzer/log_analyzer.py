import asyncio
import random
import json
import time
from typing import List, Dict, Any
import structlog

logger = structlog.get_logger()

class LogAnalyzer:
    """Simulates log processing workload for profiling testing"""
    
    def __init__(self):
        self.processed_count = 0
        self.error_count = 0
        self.processing_times = []
    
    def parse_log_entry(self, log_data: str) -> Dict[str, Any]:
        """Simulate log parsing with variable performance"""
        # Simulate parsing time (some entries are slower)
        if random.random() < 0.1:  # 10% of logs are slow to parse
            time.sleep(0.02)  # 20ms delay
        
        try:
            parsed = json.loads(log_data)
            # Simulate validation
            if not self._validate_log_entry(parsed):
                raise ValueError("Invalid log format")
            return parsed
        except (json.JSONDecodeError, ValueError) as e:
            self.error_count += 1
            raise e
    
    def _validate_log_entry(self, log_entry: Dict[str, Any]) -> bool:
        """Validate log entry structure"""
        required_fields = ['timestamp', 'level', 'message']
        return all(field in log_entry for field in required_fields)
    
    def extract_metrics(self, log_entry: Dict[str, Any]) -> Dict[str, Any]:
        """Extract metrics from log entry (CPU-intensive operation)"""
        start_time = time.time()
        
        # Simulate complex metric extraction
        metrics = {
            'response_time': self._extract_response_time(log_entry),
            'error_rate': self._calculate_error_rate(log_entry),
            'request_size': self._estimate_request_size(log_entry),
            'user_id': log_entry.get('user_id'),
            'endpoint': log_entry.get('endpoint')
        }
        
        # Simulate inefficient computation (optimization opportunity)
        for i in range(1000):  # Wasteful loop for testing
            _ = i * i
        
        processing_time = time.time() - start_time
        self.processing_times.append(processing_time)
        
        return metrics
    
    def _extract_response_time(self, log_entry: Dict[str, Any]) -> float:
        """Extract response time from log entry"""
        # Simulate regex parsing (optimization opportunity)
        message = log_entry.get('message', '')
        
        # Inefficient string operations for testing
        parts = message.split(' ')
        for part in parts:
            if 'response_time' in part.lower():
                try:
                    return float(part.split('=')[1].replace('ms', ''))
                except (IndexError, ValueError):
                    pass
        return 0.0
    
    def _calculate_error_rate(self, log_entry: Dict[str, Any]) -> float:
        """Calculate error rate (memory-intensive operation)"""
        # Simulate memory allocation for testing
        large_data = [random.random() for _ in range(10000)]  # Memory waste
        
        level = log_entry.get('level', '').upper()
        if level in ['ERROR', 'CRITICAL']:
            return 1.0
        elif level == 'WARNING':
            return 0.5
        return 0.0
    
    def _estimate_request_size(self, log_entry: Dict[str, Any]) -> int:
        """Estimate request size from log data"""
        # More inefficient operations for testing
        message = str(log_entry)
        return len(message.encode('utf-8'))
    
    async def process_log_batch(self, log_batch: List[str]) -> List[Dict[str, Any]]:
        """Process a batch of log entries"""
        results = []
        
        for log_data in log_batch:
            try:
                parsed_log = self.parse_log_entry(log_data)
                metrics = self.extract_metrics(parsed_log)
                
                results.append({
                    'status': 'success',
                    'log': parsed_log,
                    'metrics': metrics
                })
                self.processed_count += 1
                
            except Exception as e:
                results.append({
                    'status': 'error',
                    'error': str(e),
                    'log_data': log_data[:100]  # First 100 chars for debugging
                })
                self.error_count += 1
        
        return results
    
    def get_performance_stats(self) -> Dict[str, Any]:
        """Get analyzer performance statistics"""
        if not self.processing_times:
            return {'status': 'no_data'}
        
        return {
            'processed_count': self.processed_count,
            'error_count': self.error_count,
            'error_rate': self.error_count / max(self.processed_count + self.error_count, 1),
            'avg_processing_time_ms': sum(self.processing_times) / len(self.processing_times) * 1000,
            'max_processing_time_ms': max(self.processing_times) * 1000,
            'min_processing_time_ms': min(self.processing_times) * 1000
        }

def generate_test_logs(count: int = 100) -> List[str]:
    """Generate test log entries for profiling"""
    log_templates = [
        {
            'timestamp': '2025-05-20T{}:{}:{}.{}Z',
            'level': 'INFO',
            'message': 'User {} accessed endpoint {} - response_time={}ms',
            'user_id': 'user_{}',
            'endpoint': '/api/{}'
        },
        {
            'timestamp': '2025-05-20T{}:{}:{}.{}Z',
            'level': 'ERROR',
            'message': 'Database connection failed for user {} - error_code={}',
            'user_id': 'user_{}',
            'endpoint': '/api/database'
        },
        {
            'timestamp': '2025-05-20T{}:{}:{}.{}Z',
            'level': 'WARNING',
            'message': 'Slow query detected - duration={}ms query_id={}',
            'user_id': 'user_{}',
            'endpoint': '/api/query'
        }
    ]
    
    logs = []
    for i in range(count):
        template = random.choice(log_templates)
        
        # Generate timestamp
        hour = random.randint(0, 23)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        ms = random.randint(0, 999)
        
        # Generate values
        user_id = random.randint(1000, 9999)
        endpoint = random.choice(['users', 'orders', 'products', 'auth'])
        response_time = random.randint(10, 500)
        error_code = random.randint(500, 599)
        duration = random.randint(100, 2000)
        query_id = random.randint(10000, 99999)
        
        # Format log entry
        log_entry = {}
        for key, value in template.items():
            if '{}' in str(value):
                if key == 'timestamp':
                    log_entry[key] = value.format(hour, minute, second, ms)
                elif 'response_time' in str(value):
                    log_entry[key] = value.format(user_id, endpoint, response_time)
                elif 'error_code' in str(value):
                    log_entry[key] = value.format(user_id, error_code)
                elif 'duration' in str(value):
                    log_entry[key] = value.format(duration, query_id)
                elif key == 'user_id':
                    log_entry[key] = value.format(user_id)
                elif key == 'endpoint':
                    log_entry[key] = value.format(endpoint)
                else:
                    log_entry[key] = value
            else:
                log_entry[key] = value
        
        logs.append(json.dumps(log_entry))
    
    return logs
