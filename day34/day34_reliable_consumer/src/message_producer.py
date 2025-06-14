#!/usr/bin/env python3
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import json
import time
import random
import pika
from config.config import config
import structlog

logger = structlog.get_logger()

class LogMessageProducer:
    def __init__(self):
        self.connection = None
        self.channel = None
    
    def connect(self):
        """Connect to RabbitMQ"""
        credentials = pika.PlainCredentials(config.rabbitmq_user, config.rabbitmq_password)
        parameters = pika.ConnectionParameters(
            host=config.rabbitmq_host,
            port=config.rabbitmq_port,
            credentials=credentials
        )
        
        self.connection = pika.BlockingConnection(parameters)
        self.channel = self.connection.channel()
        
        # Only declare exchange - let consumer handle queue setup
        self.channel.exchange_declare(exchange=config.exchange_name, exchange_type='direct', durable=True)
        
        logger.info("Producer connected to RabbitMQ")
    
    def send_test_messages(self, count: int = 100):
        """Send test log messages"""
        log_types = ['error', 'warning', 'info', 'debug']
        services = ['auth-service', 'user-service', 'payment-service', 'notification-service']
        
        for i in range(count):
            message = {
                'id': f'log_{i:04d}',
                'timestamp': time.time(),
                'level': random.choice(log_types),
                'service': random.choice(services),
                'message': f'Test log message {i}',
                'metadata': {
                    'request_id': f'req_{random.randint(1000, 9999)}',
                    'user_id': f'user_{random.randint(100, 999)}',
                    'session_id': f'sess_{random.randint(10000, 99999)}'
                }
            }
            
            self.channel.basic_publish(
                exchange=config.exchange_name,
                routing_key='log.processing',
                body=json.dumps(message),
                properties=pika.BasicProperties(
                    delivery_mode=2,  # Make message persistent
                    content_type='application/json'
                )
            )
            
            if (i + 1) % 10 == 0:
                logger.info(f"Sent {i + 1} messages")
                time.sleep(1)  # Small delay to simulate real traffic
        
        logger.info(f"Finished sending {count} test messages")
    
    def close(self):
        """Close connection"""
        if self.connection and not self.connection.is_closed:
            self.connection.close()
            logger.info("Producer connection closed")

def main():
    producer = LogMessageProducer()
    try:
        producer.connect()
        producer.send_test_messages(50)  # Send 50 test messages
    finally:
        producer.close()

if __name__ == "__main__":
    main()
