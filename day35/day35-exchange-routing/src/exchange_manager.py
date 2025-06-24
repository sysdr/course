import pika
import json
import logging
from datetime import datetime
from config.config import Config

class ExchangeManager:
    def __init__(self):
        self.connection = None
        self.channel = None
        self.setup_logging()
        
    def setup_logging(self):
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
    def connect(self):
        """Establish connection to RabbitMQ"""
        try:
            credentials = pika.PlainCredentials(
                Config.RABBITMQ_USER, 
                Config.RABBITMQ_PASSWORD
            )
            parameters = pika.ConnectionParameters(
                host=Config.RABBITMQ_HOST,
                port=Config.RABBITMQ_PORT,
                virtual_host=Config.RABBITMQ_VHOST,
                credentials=credentials
            )
            self.connection = pika.BlockingConnection(parameters)
            self.channel = self.connection.channel()
            self.logger.info("Connected to RabbitMQ")
            return True
        except Exception as e:
            self.logger.error(f"Failed to connect to RabbitMQ: {e}")
            return False
            
    def setup_exchanges_and_queues(self):
        """Setup all exchanges, queues and bindings"""
        try:
            # Declare exchanges
            self.channel.exchange_declare(
                exchange=Config.DIRECT_EXCHANGE,
                exchange_type='direct',
                durable=True
            )
            
            self.channel.exchange_declare(
                exchange=Config.TOPIC_EXCHANGE,
                exchange_type='topic',
                durable=True
            )
            
            self.channel.exchange_declare(
                exchange=Config.FANOUT_EXCHANGE,
                exchange_type='fanout',
                durable=True
            )
            
            # Declare queues
            for queue_name in Config.QUEUES.values():
                self.channel.queue_declare(queue=queue_name, durable=True)
                
            # Setup direct exchange bindings
            self.channel.queue_bind(
                exchange=Config.DIRECT_EXCHANGE,
                queue=Config.QUEUES['database_logs'],
                routing_key='database.postgres.error'
            )
            
            # Setup topic exchange bindings
            for pattern, queue_key in Config.ROUTING_PATTERNS.items():
                self.channel.queue_bind(
                    exchange=Config.TOPIC_EXCHANGE,
                    queue=Config.QUEUES[queue_key],
                    routing_key=pattern
                )
                
            # Setup fanout exchange bindings
            self.channel.queue_bind(
                exchange=Config.FANOUT_EXCHANGE,
                queue=Config.QUEUES['broadcast_logs']
            )
            
            self.logger.info("Exchanges and queues setup completed")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to setup exchanges: {e}")
            return False
            
    def close(self):
        """Close connection"""
        if self.connection and not self.connection.is_closed:
            self.connection.close()
            self.logger.info("Connection closed")
