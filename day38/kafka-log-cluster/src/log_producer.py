#!/usr/bin/env python3
"""Multi-service log producer for Kafka."""

import json
import time
import random
from datetime import datetime, UTC
from confluent_kafka import Producer
from faker import Faker

fake = Faker()

class LogProducer:
    def __init__(self, bootstrap_servers='localhost:9092'):
        self.producer = Producer({
            'bootstrap.servers': bootstrap_servers,
        })
        
    def generate_web_api_log(self):
        """Generate web API log entry."""
        return {
            'timestamp': datetime.now(UTC).isoformat(),
            'service': 'web-api',
            'level': random.choice(['INFO', 'WARN', 'ERROR']),
            'method': random.choice(['GET', 'POST', 'PUT', 'DELETE']),
            'endpoint': random.choice(['/api/users', '/api/orders', '/api/products']),
            'status_code': random.choice([200, 201, 400, 404, 500]),
            'response_time_ms': random.randint(10, 2000),
            'user_id': fake.uuid4(),
            'ip_address': fake.ipv4(),
        }
    
    def generate_user_service_log(self):
        """Generate user service log entry."""
        return {
            'timestamp': datetime.now(UTC).isoformat(),
            'service': 'user-service',
            'level': random.choice(['INFO', 'WARN', 'ERROR']),
            'event_type': random.choice(['login', 'logout', 'register', 'password_reset']),
            'user_id': fake.uuid4(),
            'email': fake.email(),
            'success': random.choice([True, False]),
            'ip_address': fake.ipv4(),
        }
    
    def generate_payment_service_log(self):
        """Generate payment service log entry."""
        return {
            'timestamp': datetime.now(UTC).isoformat(),
            'service': 'payment-service',
            'level': random.choice(['INFO', 'WARN', 'ERROR']),
            'transaction_id': fake.uuid4(),
            'amount': round(random.uniform(1.0, 1000.0), 2),
            'currency': random.choice(['USD', 'EUR', 'GBP']),
            'status': random.choice(['pending', 'completed', 'failed']),
            'payment_method': random.choice(['credit_card', 'paypal', 'bank_transfer']),
        }
    
    def send_logs(self, duration_seconds=60):
        """Send logs to appropriate topics."""
        print(f"🚀 Starting log generation for {duration_seconds} seconds...")
        start_time = time.time()
        
        while time.time() - start_time < duration_seconds:
            # Generate and send different types of logs
            web_log = self.generate_web_api_log()
            self.producer.produce('web-api-logs', 
                                value=json.dumps(web_log), 
                                key=web_log['user_id'])
            
            user_log = self.generate_user_service_log()
            self.producer.produce('user-service-logs', 
                                value=json.dumps(user_log), 
                                key=user_log['user_id'])
            
            payment_log = self.generate_payment_service_log()
            self.producer.produce('payment-service-logs', 
                                value=json.dumps(payment_log), 
                                key=payment_log['transaction_id'])
            
            # Send critical logs for errors
            if web_log['level'] == 'ERROR' or user_log['level'] == 'ERROR' or payment_log['level'] == 'ERROR':
                critical_log = {
                    'timestamp': datetime.now(UTC).isoformat(),
                    'priority': 'CRITICAL',
                    'original_service': web_log.get('service', user_log.get('service', payment_log.get('service'))),
                    'error_details': 'System error detected'
                }
                self.producer.produce('critical-logs', value=json.dumps(critical_log))
            
            time.sleep(0.1)  # 10 messages per second per service
        
        self.producer.flush()
        print("✅ Log generation completed")

if __name__ == "__main__":
    producer = LogProducer()
    producer.send_logs(60)
