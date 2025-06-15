import pika
import json
import random
import time
from datetime import datetime
from config.config import Config

class LogProducer:
    def __init__(self):
        self.connection = None
        self.channel = None
        
    def connect(self):
        """Connect to RabbitMQ"""
        credentials = pika.PlainCredentials(Config.RABBITMQ_USER, Config.RABBITMQ_PASSWORD)
        parameters = pika.ConnectionParameters(
            host=Config.RABBITMQ_HOST,
            port=Config.RABBITMQ_PORT,
            credentials=credentials
        )
        self.connection = pika.BlockingConnection(parameters)
        self.channel = self.connection.channel()
        
    def create_log_message(self, service, component, level, message):
        """Create structured log message"""
        return {
            'timestamp': datetime.now().isoformat(),
            'service': service,
            'component': component,
            'level': level,
            'message': message,
            'routing_key': f"{service}.{component}.{level}",
            'metadata': {
                'source_ip': f"192.168.1.{random.randint(1, 255)}",
                'request_id': f"req_{random.randint(1000, 9999)}"
            }
        }
        
    def publish_to_direct(self, routing_key, message):
        """Publish to direct exchange"""
        self.channel.basic_publish(
            exchange=Config.DIRECT_EXCHANGE,
            routing_key=routing_key,
            body=json.dumps(message),
            properties=pika.BasicProperties(delivery_mode=2)  # Persistent
        )
        
    def publish_to_topic(self, routing_key, message):
        """Publish to topic exchange"""
        self.channel.basic_publish(
            exchange=Config.TOPIC_EXCHANGE,
            routing_key=routing_key,
            body=json.dumps(message),
            properties=pika.BasicProperties(delivery_mode=2)
        )
        
    def publish_to_fanout(self, message):
        """Publish to fanout exchange"""
        self.channel.basic_publish(
            exchange=Config.FANOUT_EXCHANGE,
            routing_key='',  # Ignored for fanout
            body=json.dumps(message),
            properties=pika.BasicProperties(delivery_mode=2)
        )
        
    def generate_sample_logs(self, count=10):
        """Generate sample log messages"""
        services = ['database', 'api', 'security', 'analytics', 'monitoring']
        components = ['postgres', 'redis', 'auth', 'gateway', 'metrics']
        levels = ['info', 'warning', 'error', 'debug']
        
        for i in range(count):
            service = random.choice(services)
            component = random.choice(components)
            level = random.choice(levels)
            
            message = self.create_log_message(
                service, component, level,
                f"Sample log message {i+1} from {service}.{component}"
            )
            
            # Route to different exchanges based on criteria
            if level == 'error':
                self.publish_to_direct(message['routing_key'], message)
                print(f"🎯 Direct: {message['routing_key']}")
            elif service in ['security', 'monitoring']:
                self.publish_to_fanout(message)
                print(f"📢 Fanout: Critical {service} message")
            else:
                self.publish_to_topic(message['routing_key'], message)
                print(f"🏷️  Topic: {message['routing_key']}")
                
            time.sleep(0.1)  # Throttle for demo
            
    def close(self):
        if self.connection and not self.connection.is_closed:
            self.connection.close()
