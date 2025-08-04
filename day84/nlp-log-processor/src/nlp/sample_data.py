import json
import random
from datetime import datetime, timedelta

class SampleLogGenerator:
    """Generate sample log messages for testing NLP processing"""
    
    def __init__(self):
        self.log_templates = [
            # Error logs
            "ERROR: Database connection timeout after 30 seconds to server {ip}",
            "EXCEPTION: Failed to authenticate user {email} from {ip}",
            "ERROR: File not found: {filepath}",
            "CRITICAL: Memory usage exceeded 95% threshold on server {hostname}",
            
            # Warning logs
            "WARNING: High response time {response_time}ms for endpoint {endpoint}",
            "WARN: Deprecated API method used by client {ip}",
            "WARNING: Disk space running low on partition {partition}",
            
            # Info logs
            "INFO: User {email} successfully logged in from {ip}",
            "INFO: Backup completed for database {database_name}",
            "INFO: Service started on port {port}",
            "INFO: Processing batch job {job_id} with {record_count} records",
            
            # Security logs
            "SECURITY: Blocked suspicious IP address {ip}",
            "ALERT: Multiple failed login attempts for user {email}",
            "SECURITY: Unauthorized access attempt to {resource}",
            
            # Performance logs
            "PERF: Query execution time: {query_time}ms for table {table_name}",
            "METRICS: API response time {response_time}ms for {endpoint}",
            "PERF: Memory usage: {memory_usage}MB"
        ]
        
        self.sample_data = {
            'ip': ['192.168.1.100', '10.0.0.55', '172.16.0.10', '203.0.113.45'],
            'email': ['john.doe@company.com', 'admin@system.com', 'user@example.org'],
            'filepath': ['/var/log/app.log', 'C:\\Program Files\\App\\config.xml', '/home/user/data.json'],
            'hostname': ['web-server-01', 'db-primary', 'cache-node-03'],
            'endpoint': ['/api/users', '/api/orders', '/health', '/metrics'],
            'database_name': ['user_db', 'orders', 'analytics', 'logs'],
            'port': ['8080', '3306', '6379', '5432'],
            'resource': ['/admin/users', '/api/sensitive-data', '/config/settings'],
            'table_name': ['users', 'orders', 'products', 'sessions'],
            'partition': ['/var', '/home', '/tmp'],
            'job_id': ['job_12345', 'batch_67890', 'import_555'],
            'response_time': [random.randint(10, 500) for _ in range(10)],
            'query_time': [random.randint(5, 200) for _ in range(10)],
            'memory_usage': [random.randint(100, 8000) for _ in range(10)],
            'record_count': [random.randint(100, 10000) for _ in range(10)]
        }
    
    def generate_log_message(self):
        """Generate a single sample log message"""
        template = random.choice(self.log_templates)
        
        # Replace placeholders with sample data
        message = template
        for placeholder, values in self.sample_data.items():
            if f'{{{placeholder}}}' in message:
                message = message.replace(f'{{{placeholder}}}', str(random.choice(values)))
        
        return {
            'timestamp': datetime.utcnow().isoformat(),
            'message': message,
            'source': 'sample_generator',
            'level': self._extract_level(message)
        }
    
    def _extract_level(self, message):
        """Extract log level from message"""
        message_upper = message.upper()
        if 'ERROR' in message_upper or 'EXCEPTION' in message_upper or 'CRITICAL' in message_upper:
            return 'ERROR'
        elif 'WARNING' in message_upper or 'WARN' in message_upper:
            return 'WARNING'
        elif 'SECURITY' in message_upper or 'ALERT' in message_upper:
            return 'SECURITY'
        elif 'PERF' in message_upper or 'METRICS' in message_upper:
            return 'PERFORMANCE'
        else:
            return 'INFO'
    
    def generate_batch(self, count=10):
        """Generate a batch of sample log messages"""
        return [self.generate_log_message() for _ in range(count)]

if __name__ == '__main__':
    generator = SampleLogGenerator()
    sample_logs = generator.generate_batch(20)
    
    print(json.dumps(sample_logs, indent=2))
