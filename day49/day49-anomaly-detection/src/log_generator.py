import random
import json
import time
from datetime import datetime, timedelta
from faker import Faker
import threading
import queue
import numpy as np

fake = Faker()

class LogGenerator:
    def __init__(self):
        self.log_queue = queue.Queue()
        self.running = False
        self.anomaly_rate = 0.05  # 5% anomalies
        
    def generate_normal_log(self) -> dict:
        """Generate normal log entry"""
        return {
            'timestamp': datetime.now().isoformat(),
            'ip_address': fake.ipv4(),
            'user_agent': fake.user_agent(),
            'method': random.choice(['GET', 'POST', 'PUT', 'DELETE']),
            'url': fake.uri_path(),
            'status_code': random.choice([200, 201, 304, 404]),
            'response_time': max(0, np.random.normal(150, 50)),  # Normal: 150ms ± 50ms
            'bytes_sent': random.randint(1024, 8192),
            'session_id': fake.uuid4(),
            'user_id': fake.uuid4(),
            'session_duration': max(0, np.random.normal(300, 100)),  # 5 minutes ± 100s
            'page_views': random.randint(1, 10)
        }
    
    def generate_anomalous_log(self) -> dict:
        """Generate anomalous log entry"""
        log = self.generate_normal_log()
        
        # Different types of anomalies
        anomaly_type = random.choice(['slow_response', 'unusual_size', 'suspicious_agent', 'temporal'])
        
        if anomaly_type == 'slow_response':
            log['response_time'] = random.uniform(1000, 5000)  # Very slow
        elif anomaly_type == 'unusual_size':
            log['bytes_sent'] = random.randint(50000, 100000)  # Very large
        elif anomaly_type == 'suspicious_agent':
            log['user_agent'] = 'Suspicious Bot/1.0'
            log['response_time'] = random.uniform(10, 30)  # Very fast
        elif anomaly_type == 'temporal':
            # Unusual hour pattern
            if datetime.now().hour < 6:  # Early morning
                log['page_views'] = random.randint(50, 100)  # Unusual activity
                log['session_duration'] = random.randint(1800, 3600)  # Long session
        
        log['anomaly_type'] = anomaly_type
        return log
    
    def start_generation(self):
        """Start generating logs"""
        self.running = True
        
        def generate_logs():
            while self.running:
                if random.random() < self.anomaly_rate:
                    log = self.generate_anomalous_log()
                else:
                    log = self.generate_normal_log()
                
                self.log_queue.put(log)
                time.sleep(random.uniform(0.1, 0.5))  # Variable rate
        
        thread = threading.Thread(target=generate_logs)
        thread.daemon = True
        thread.start()
    
    def stop_generation(self):
        """Stop generating logs"""
        self.running = False
    
    def get_log(self):
        """Get next log from queue"""
        try:
            return self.log_queue.get_nowait()
        except queue.Empty:
            return None

# Global generator instance
log_generator = LogGenerator()
