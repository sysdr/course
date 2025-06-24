import os
from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class ReliableConsumerConfig:
    # RabbitMQ Configuration
    rabbitmq_host: str = os.getenv('RABBITMQ_HOST', 'localhost')
    rabbitmq_port: int = int(os.getenv('RABBITMQ_PORT', '5672'))
    rabbitmq_user: str = os.getenv('RABBITMQ_USER', 'guest')
    rabbitmq_password: str = os.getenv('RABBITMQ_PASSWORD', 'guest')
    
    # Queue Configuration
    queue_name: str = 'log_processing_queue'
    dead_letter_queue: str = 'dlq_log_processing'
    exchange_name: str = 'log_exchange'
    
    # Acknowledgment Configuration
    ack_timeout: int = 30  # seconds
    max_retries: int = 3
    retry_delay_base: int = 1  # seconds
    retry_delay_max: int = 30  # seconds
    
    # Consumer Configuration
    prefetch_count: int = 10
    consumer_tag: str = 'reliable_log_consumer'
    
    # Web Interface
    web_port: int = 8000
    
    def get_connection_params(self) -> Dict[str, Any]:
        return {
            'host': self.rabbitmq_host,
            'port': self.rabbitmq_port,
            'credentials': f"{self.rabbitmq_user}:{self.rabbitmq_password}"
        }

config = ReliableConsumerConfig()
