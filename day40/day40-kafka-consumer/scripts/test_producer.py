#!/usr/bin/env python3
import json
import random
import time
from datetime import datetime
from confluent_kafka import Producer
import uuid

class TestLogProducer:
    """Generate realistic test logs for consumer testing"""
    
    def __init__(self, bootstrap_servers="localhost:9092"):
        self.producer = Producer({'bootstrap.servers': bootstrap_servers})
        
        # Sample data for realistic logs
        self.endpoints = [
            '/api/users', '/api/orders', '/api/products', '/api/auth',
            '/api/search', '/api/recommendations', '/api/cart', '/api/checkout'
        ]
        
        self.services = ['web-server', 'api-gateway', 'user-service', 'order-service']
        self.user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
        ]
        
        self.ip_ranges = ['192.168.1.', '10.0.0.', '172.16.0.', '203.0.113.']
        
    def generate_web_access_log(self) -> dict:
        """Generate a realistic web access log"""
        status_codes = [200, 200, 200, 200, 201, 404, 500, 503]  # Weighted towards success
        
        return {
            'type': 'web_access',
            'timestamp': datetime.now().isoformat(),
            'request_id': str(uuid.uuid4()),
            'client_ip': random.choice(self.ip_ranges) + str(random.randint(1, 254)),
            'method': random.choice(['GET', 'POST', 'PUT', 'DELETE']),
            'endpoint': random.choice(self.endpoints),
            'status_code': random.choice(status_codes),
            'response_time': random.uniform(10, 500),  # milliseconds
            'user_agent': random.choice(self.user_agents),
            'bytes_sent': random.randint(100, 5000),
            'referer': 'https://example.com',
            'service': 'web-server'
        }
    
    def generate_application_log(self) -> dict:
        """Generate application log"""
        log_levels = ['DEBUG', 'INFO', 'INFO', 'WARN', 'ERROR']  # Weighted towards INFO
        
        messages = [
            'User authentication successful',
            'Order processed successfully', 
            'Cache miss for user data',
            'Database connection established',
            'API rate limit exceeded',
            'Memory usage warning',
            'Background job completed'
        ]
        
        return {
            'type': 'application',
            'timestamp': datetime.now().isoformat(),
            'level': random.choice(log_levels),
            'service': random.choice(self.services),
            'message': random.choice(messages),
            'thread_id': f"thread-{random.randint(1, 10)}",
            'user_id': random.randint(1000, 9999) if random.random() > 0.3 else None,
            'session_id': str(uuid.uuid4())[:8]
        }
    
    def generate_error_log(self) -> dict:
        """Generate error log"""
        error_types = [
            'DatabaseConnectionError',
            'TimeoutException', 
            'ValidationError',
            'AuthenticationError',
            'RateLimitExceeded'
        ]
        
        severities = ['low', 'medium', 'high', 'critical']
        
        return {
            'type': 'error',
            'timestamp': datetime.now().isoformat(),
            'error_type': random.choice(error_types),
            'severity': random.choice(severities),
            'service': random.choice(self.services),
            'message': f"Error occurred in {random.choice(self.services)}",
            'stack_trace': "at com.example.service.method(Service.java:123)",
            'user_id': random.randint(1000, 9999) if random.random() > 0.5 else None
        }
        
    def send_log(self, topic: str, log_data: dict):
        """Send log to Kafka topic"""
        key = log_data.get('service', 'unknown')
        
        self.producer.produce(
            topic=topic,
            key=key,
            value=json.dumps(log_data),
            callback=self._delivery_report
        )
        
    def _delivery_report(self, err, msg):
        """Delivery report callback"""
        if err is not None:
            print(f'Message delivery failed: {err}')
        else:
            print(f'Message delivered to {msg.topic()} [{msg.partition()}] @ {msg.offset()}')
            
    def generate_continuous_logs(self, duration_seconds=300, rate_per_second=10):
        """Generate continuous stream of logs"""
        print(f"Generating logs for {duration_seconds} seconds at {rate_per_second} logs/second")
        
        end_time = time.time() + duration_seconds
        
        while time.time() < end_time:
            cycle_start = time.time()
            
            for _ in range(rate_per_second):
                # Choose log type with weighted distribution
                log_type = random.choices(
                    ['web_access', 'application', 'error'],
                    weights=[60, 35, 5]  # 60% web, 35% app, 5% error
                )[0]
                
                if log_type == 'web_access':
                    log_data = self.generate_web_access_log()
                    topic = 'web-logs'
                elif log_type == 'application':
                    log_data = self.generate_application_log()
                    topic = 'app-logs'
                else:
                    log_data = self.generate_error_log()
                    topic = 'error-logs'
                
                self.send_log(topic, log_data)
            
            # Flush producer
            self.producer.flush()
            
            # Sleep to maintain rate
            cycle_time = time.time() - cycle_start
            sleep_time = max(0, 1.0 - cycle_time)
            time.sleep(sleep_time)
            
        print(f"Log generation completed")

def main():
    """Main function for test producer"""
    producer = TestLogProducer()
    
    print("🚀 Starting test log generation...")
    print("📊 Generating realistic logs for consumer testing")
    print("🎯 Topics: web-logs, app-logs, error-logs")
    
    try:
        # Generate logs for 5 minutes at 20 logs/second
        producer.generate_continuous_logs(duration_seconds=300, rate_per_second=20)
    except KeyboardInterrupt:
        print("\n⏹️  Log generation stopped by user")
    except Exception as e:
        print(f"❌ Error during log generation: {e}")

if __name__ == "__main__":
    main()
