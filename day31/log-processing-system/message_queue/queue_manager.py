"""
Queue management utilities for log processing system.
"""
import pika
import json
import logging
from datetime import datetime
from typing import Dict, Any, Optional
from message_queue.rabbitmq_setup import RabbitMQSetup

class QueueManager:
    def __init__(self, config_path: str = 'config/rabbitmq_config.yaml'):
        self.setup = RabbitMQSetup(config_path)
        self.connection = None
        self.channel = None
        
    def connect(self) -> bool:
        """Connect to RabbitMQ."""
        if self.setup.connect():
            self.connection = self.setup.connection
            self.channel = self.setup.channel
            return True
        return False
        
    def publish_message(self, routing_key: str, message: Dict[str, Any]) -> bool:
        """Publish a message to the exchange."""
        try:
            exchange_name = self.setup.config['exchanges']['log_exchange']['name']
            
            # Add metadata to message
            enriched_message = {
                'timestamp': datetime.utcnow().isoformat(),
                'routing_key': routing_key,
                'data': message
            }
            
            self.channel.basic_publish(
                exchange=exchange_name,
                routing_key=routing_key,
                body=json.dumps(enriched_message),
                properties=pika.BasicProperties(
                    delivery_mode=2,  # Make message persistent
                    content_type='application/json'
                )
            )
            
            logging.info(f"Published message with routing key: {routing_key}")
            return True
            
        except Exception as e:
            logging.error(f"Failed to publish message: {e}")
            return False
            
    def get_queue_info(self, queue_name: str) -> Optional[Dict[str, Any]]:
        """Get information about a specific queue."""
        try:
            method = self.channel.queue_declare(queue=queue_name, passive=True)
            return {
                'queue_name': queue_name,
                'message_count': method.method.message_count,
                'consumer_count': method.method.consumer_count
            }
        except Exception as e:
            logging.error(f"Failed to get queue info: {e}")
            return None
            
    def purge_queue(self, queue_name: str) -> bool:
        """Remove all messages from a queue."""
        try:
            self.channel.queue_purge(queue=queue_name)
            logging.info(f"Purged queue: {queue_name}")
            return True
        except Exception as e:
            logging.error(f"Failed to purge queue: {e}")
            return False
            
    def close(self):
        """Close connection."""
        if self.setup:
            self.setup.close_connection()

def main():
    """Demo queue operations."""
    logging.basicConfig(level=logging.INFO)
    
    manager = QueueManager()
    
    if not manager.connect():
        print("❌ Failed to connect to RabbitMQ")
        return
        
    try:
        # Publish test messages
        test_messages = [
            ('logs.info.web', {'level': 'INFO', 'source': 'web-server', 'message': 'User login successful'}),
            ('logs.error.db', {'level': 'ERROR', 'source': 'database', 'message': 'Connection timeout'}),
            ('logs.debug.api', {'level': 'DEBUG', 'source': 'api', 'message': 'Request processed'})
        ]
        
        for routing_key, message in test_messages:
            manager.publish_message(routing_key, message)
            
        # Check queue status
        queues = ['log_messages', 'error_messages', 'debug_messages']
        for queue in queues:
            info = manager.get_queue_info(queue)
            if info:
                print(f"📊 Queue {queue}: {info['message_count']} messages, {info['consumer_count']} consumers")
                
    finally:
        manager.close()

if __name__ == "__main__":
    main()
