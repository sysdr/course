import pika
import json
import sys
from config.config import Config

class LogConsumer:
    def __init__(self, queue_name, consumer_id):
        self.queue_name = queue_name
        self.consumer_id = consumer_id
        self.connection = None
        self.channel = None
        self.message_count = 0
        
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
        
    def process_message(self, ch, method, properties, body):
        """Process incoming log message"""
        try:
            message = json.loads(body)
            self.message_count += 1
            
            print(f"\n🔍 [{self.consumer_id}] Processing message #{self.message_count}")
            print(f"    Queue: {self.queue_name}")
            print(f"    Service: {message.get('service', 'unknown')}")
            print(f"    Component: {message.get('component', 'unknown')}")
            print(f"    Level: {message.get('level', 'unknown')}")
            print(f"    Message: {message.get('message', '')}")
            print(f"    Timestamp: {message.get('timestamp', '')}")
            
            # Simulate processing based on message type
            if message.get('level') == 'error':
                print("    🚨 ERROR PROCESSING: Sending to incident management")
            elif message.get('service') == 'security':
                print("    🔒 SECURITY PROCESSING: Analyzing for threats")
            elif message.get('service') == 'database':
                print("    💾 DATABASE PROCESSING: Performance analysis")
            else:
                print("    ✅ STANDARD PROCESSING: Logged and indexed")
                
            # Acknowledge message
            ch.basic_ack(delivery_tag=method.delivery_tag)
            
        except Exception as e:
            print(f"❌ Error processing message: {e}")
            # Reject and requeue
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
            
    def start_consuming(self):
        """Start consuming messages"""
        self.channel.basic_qos(prefetch_count=1)
        self.channel.basic_consume(
            queue=self.queue_name,
            on_message_callback=self.process_message
        )
        
        print(f"🚀 [{self.consumer_id}] Starting to consume from {self.queue_name}")
        print("Press CTRL+C to stop...")
        
        try:
            self.channel.start_consuming()
        except KeyboardInterrupt:
            self.channel.stop_consuming()
            
    def close(self):
        if self.connection and not self.connection.is_closed:
            self.connection.close()
