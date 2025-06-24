import json
import time
import random
import os
from datetime import datetime
from kafka import KafkaProducer
import threading

class LogDataGenerator:
    def __init__(self, bootstrap_servers=None):
        self.bootstrap_servers = bootstrap_servers or os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
        self.producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_servers,
            value_serializer=lambda x: json.dumps(x).encode('utf-8')
        )
        self.running = False
        
    def generate_log_event(self):
        """Generate realistic log event"""
        status_codes = [200, 200, 200, 201, 404, 500, 503]
        user_agents = ['Chrome', 'Firefox', 'Safari', 'Edge']
        
        return {
            'timestamp': datetime.now().isoformat(),
            'ip_address': f"192.168.1.{random.randint(1, 254)}",
            'status_code': random.choice(status_codes),
            'response_time': random.randint(50, 2000),
            'user_agent': random.choice(user_agents),
            'path': f"/api/v1/{random.choice(['users', 'orders', 'products'])}/{random.randint(1, 1000)}"
        }
        
    def generate_error_event(self):
        """Generate error event"""
        error_types = ['DatabaseError', 'TimeoutError', 'ValidationError', 'AuthError']
        severities = ['low', 'medium', 'high', 'critical']
        
        return {
            'timestamp': datetime.now().isoformat(),
            'error_type': random.choice(error_types),
            'severity': random.choice(severities),
            'message': 'Sample error message',
            'stack_trace': 'Sample stack trace'
        }
        
    def generate_user_event(self):
        """Generate user activity event"""
        actions = ['login', 'logout', 'purchase', 'view_product', 'add_to_cart']
        
        return {
            'timestamp': datetime.now().isoformat(),
            'user_id': f"user_{random.randint(1, 10000)}",
            'action': random.choice(actions),
            'session_id': f"session_{random.randint(1, 1000)}"
        }
        
    def start_generation(self):
        """Start generating events"""
        self.running = True
        
        def generate_events():
            while self.running:
                # Generate log events (most frequent)
                for _ in range(random.randint(5, 15)):
                    event = self.generate_log_event()
                    self.producer.send('log-events', event)
                    
                # Generate user events
                for _ in range(random.randint(1, 5)):
                    event = self.generate_user_event()
                    self.producer.send('user-events', event)
                    
                # Generate error events (less frequent)
                if random.random() < 0.3:
                    event = self.generate_error_event()
                    self.producer.send('error-events', event)
                    
                time.sleep(1)
                
        thread = threading.Thread(target=generate_events)
        thread.daemon = True
        thread.start()
        
    def stop(self):
        """Stop generating events"""
        self.running = False
        self.producer.close()

if __name__ == '__main__':
    generator = LogDataGenerator()
    print("Starting data generation...")
    generator.start_generation()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Stopping data generation...")
        generator.stop()
