"""
RabbitMQ setup and configuration for log processing system.
"""
import pika
import yaml
import logging
from typing import Dict, Any
import time

class RabbitMQSetup:
    def __init__(self, config_path: str = 'config/rabbitmq_config.yaml'):
        self.config = self._load_config(config_path)
        self.connection = None
        self.channel = None
        
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load RabbitMQ configuration from YAML file."""
        try:
            with open(config_path, 'r') as file:
                return yaml.safe_load(file)
        except FileNotFoundError:
            logging.error(f"Config file not found: {config_path}")
            raise
            
    def connect(self, max_retries: int = 5) -> bool:
        """Establish connection to RabbitMQ with retry logic."""
        rabbitmq_config = self.config['rabbitmq']
        
        for attempt in range(max_retries):
            try:
                credentials = pika.PlainCredentials(
                    rabbitmq_config['username'],
                    rabbitmq_config['password']
                )
                
                parameters = pika.ConnectionParameters(
                    host=rabbitmq_config['host'],
                    port=rabbitmq_config['port'],
                    virtual_host=rabbitmq_config['virtual_host'],
                    credentials=credentials,
                    heartbeat=600,
                    blocked_connection_timeout=300
                )
                
                self.connection = pika.BlockingConnection(parameters)
                self.channel = self.connection.channel()
                
                logging.info("Successfully connected to RabbitMQ")
                return True
                
            except pika.exceptions.AMQPConnectionError as e:
                logging.warning(f"Connection attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                
        logging.error("Failed to connect to RabbitMQ after all retries")
        return False
        
    def setup_exchanges(self):
        """Create and configure exchanges."""
        exchanges = self.config['exchanges']
        
        for exchange_key, exchange_config in exchanges.items():
            self.channel.exchange_declare(
                exchange=exchange_config['name'],
                exchange_type=exchange_config['type'],
                durable=exchange_config['durable']
            )
            logging.info(f"Created exchange: {exchange_config['name']}")
            
    def setup_queues(self):
        """Create and configure queues with bindings."""
        queues = self.config['queues']
        exchange_name = self.config['exchanges']['log_exchange']['name']
        
        # Queue configurations with routing keys
        queue_bindings = {
            'log_messages': ['logs.info.*', 'logs.warning.*'],
            'error_messages': ['logs.error.*', 'logs.critical.*'],
            'debug_messages': ['logs.debug.*']
        }
        
        for queue_key, queue_config in queues.items():
            queue_name = queue_config['name']
            
            # Declare queue
            self.channel.queue_declare(
                queue=queue_name,
                durable=queue_config['durable'],
                auto_delete=queue_config['auto_delete']
            )
            
            # Bind queue to exchange with routing keys
            if queue_name in queue_bindings:
                for routing_key in queue_bindings[queue_name]:
                    self.channel.queue_bind(
                        exchange=exchange_name,
                        queue=queue_name,
                        routing_key=routing_key
                    )
                    
            logging.info(f"Created and bound queue: {queue_name}")
            
    def close_connection(self):
        """Close RabbitMQ connection."""
        if self.connection and not self.connection.is_closed:
            self.connection.close()
            logging.info("RabbitMQ connection closed")

def main():
    """Main setup function."""
    logging.basicConfig(level=logging.INFO)
    
    setup = RabbitMQSetup()
    
    if setup.connect():
        try:
            setup.setup_exchanges()
            setup.setup_queues()
            print("✅ RabbitMQ setup completed successfully!")
            print("🌐 Management UI available at: http://localhost:15672")
            print("👤 Default credentials: guest/guest")
        finally:
            setup.close_connection()
    else:
        print("❌ Failed to setup RabbitMQ")
        return False
        
    return True

if __name__ == "__main__":
    main()
