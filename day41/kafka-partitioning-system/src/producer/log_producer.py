import json
import time
import random
import threading
from datetime import datetime
from typing import Dict, List, Optional
from confluent_kafka import Producer, KafkaError
import structlog
import sys
import os

# Add config path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.kafka_config import config

logger = structlog.get_logger(__name__)

class LogMessageProducer:
    def __init__(self, producer_id: str = "default-producer"):
        self.producer_id = producer_id
        self.producer = Producer(config.get_producer_config())
        self.message_count = 0
        self.error_count = 0
        self.running = False
        
        # Log generation parameters
        self.services = ['web-api', 'user-service', 'payment-service', 'analytics', 'notification-service']
        self.log_levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
        self.log_level_weights = [0.6, 0.2, 0.1, 0.1]  # Most logs are INFO
        
    def delivery_report(self, err: Optional[KafkaError], msg):
        """Callback for message delivery reports"""
        if err is not None:
            self.error_count += 1
            logger.error(f"❌ Message delivery failed: {err}")
        else:
            self.message_count += 1
            if self.message_count % 100 == 0:
                logger.info(f"✅ Delivered message #{self.message_count} to partition {msg.partition()}")
    
    def generate_log_message(self, service: str = None, user_id: str = None) -> Dict:
        """Generate a realistic log message"""
        if service is None:
            service = random.choice(self.services)
        
        if user_id is None:
            user_id = f"user_{random.randint(1000, 9999)}"
            
        log_level = random.choices(self.log_levels, weights=self.log_level_weights)[0]
        
        # Generate realistic log content based on service and level
        log_templates = {
            'web-api': {
                'INFO': f"HTTP GET /api/users/{user_id} - 200 OK - {random.randint(10, 500)}ms",
                'WARN': f"Slow response time for /api/users/{user_id} - {random.randint(1000, 3000)}ms",
                'ERROR': f"HTTP 500 Internal Server Error for /api/users/{user_id}",
                'DEBUG': f"Processing request for user {user_id} with session {random.randint(10000, 99999)}"
            },
            'user-service': {
                'INFO': f"User {user_id} profile updated successfully",
                'WARN': f"Failed login attempt for user {user_id}",
                'ERROR': f"Database connection timeout for user {user_id}",
                'DEBUG': f"Validating user {user_id} permissions"
            },
            'payment-service': {
                'INFO': f"Payment processed for user {user_id} - ${random.randint(10, 1000)}.{random.randint(10, 99)}",
                'WARN': f"Payment retry attempt #{random.randint(1, 3)} for user {user_id}",
                'ERROR': f"Payment failed for user {user_id} - insufficient funds",
                'DEBUG': f"Validating payment method for user {user_id}"
            }
        }
        
        if service not in log_templates:
            service = 'web-api'
            
        message_content = log_templates[service].get(log_level, f"{log_level} message from {service}")
        
        return {
            'timestamp': datetime.now().isoformat(),
            'service': service,
            'level': log_level,
            'user_id': user_id,
            'message': message_content,
            'request_id': f"req_{random.randint(100000, 999999)}",
            'session_id': f"sess_{random.randint(10000, 99999)}",
            'ip_address': f"192.168.{random.randint(1, 255)}.{random.randint(1, 255)}",
            'producer_id': self.producer_id
        }
    
    def get_partition_key(self, log_message: Dict) -> str:
        """Generate partition key based on user_id for order preservation per user"""
        return log_message['user_id']
    
    def send_log(self, log_message: Dict) -> bool:
        """Send a single log message to Kafka"""
        try:
            key = self.get_partition_key(log_message)
            value = json.dumps(log_message)
            
            self.producer.produce(
                topic=config.topic_name,
                key=key,
                value=value,
                callback=self.delivery_report
            )
            
            # Poll to handle delivery reports
            self.producer.poll(0)
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to send log message: {e}")
            self.error_count += 1
            return False
    
    def start_continuous_production(self, messages_per_second: int = 10, duration_seconds: int = 60):
        """Start producing messages continuously at specified rate"""
        self.running = True
        interval = 1.0 / messages_per_second
        end_time = time.time() + duration_seconds
        
        logger.info(f"🚀 Starting continuous production: {messages_per_second} msg/sec for {duration_seconds}s")
        
        while self.running and time.time() < end_time:
            start_time = time.time()
            
            # Generate and send message
            log_message = self.generate_log_message()
            self.send_log(log_message)
            
            # Maintain rate limiting
            elapsed = time.time() - start_time
            sleep_time = max(0, interval - elapsed)
            if sleep_time > 0:
                time.sleep(sleep_time)
        
        # Flush any remaining messages
        self.producer.flush(timeout=10)
        self.running = False
        
        logger.info(f"✅ Production complete: {self.message_count} sent, {self.error_count} errors")
    
    def stop_production(self):
        """Stop continuous production"""
        self.running = False
        self.producer.flush(timeout=5)
    
    def get_stats(self) -> Dict:
        """Get producer statistics"""
        return {
            'producer_id': self.producer_id,
            'messages_sent': self.message_count,
            'errors': self.error_count,
            'success_rate': (self.message_count / max(1, self.message_count + self.error_count)) * 100
        }

def run_producer_demo():
    """Run a demonstration of the producer"""
    producer = LogMessageProducer("demo-producer")
    
    try:
        # Send a batch of test messages
        logger.info("📤 Sending test messages...")
        for i in range(20):
            log_message = producer.generate_log_message()
            producer.send_log(log_message)
            time.sleep(0.1)
        
        # Flush messages
        producer.producer.flush(timeout=10)
        
        # Print statistics
        stats = producer.get_stats()
        logger.info(f"📊 Producer stats: {stats}")
        
    except KeyboardInterrupt:
        logger.info("🛑 Producer demo interrupted")
    finally:
        producer.stop_production()

if __name__ == "__main__":
    run_producer_demo()
