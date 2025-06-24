import asyncio
import logging
import json
from typing import List, Dict, Any
import pika
import time

class ConnectionPool:
    def __init__(self, rabbitmq_config: Dict[str, Any]):
        self.config = rabbitmq_config
        self.connection = None
        self.channel = None
        self.circuit_breaker = CircuitBreaker()
        
    async def initialize(self):
        """Initialize RabbitMQ connection"""
        try:
            # Create connection
            connection_params = pika.ConnectionParameters(
                host=self.config['host'],
                port=self.config['port'],
                heartbeat=600,
                blocked_connection_timeout=300
            )
            
            self.connection = pika.BlockingConnection(connection_params)
            self.channel = self.connection.channel()
            
            # Declare exchange
            self.channel.exchange_declare(
                exchange=self.config['exchange'],
                exchange_type='topic',
                durable=True
            )
            
            logging.info("RabbitMQ connection established")
            self.circuit_breaker.reset()
            
        except Exception as e:
            logging.error(f"Failed to initialize RabbitMQ connection: {e}")
            self.circuit_breaker.record_failure()
            raise
    
    async def publish_batch(self, messages: List[str]) -> bool:
        """Publish a batch of messages"""
        if self.circuit_breaker.is_open():
            logging.warning("Circuit breaker is open, skipping publish")
            return False
        
        try:
            for message in messages:
                self.channel.basic_publish(
                    exchange=self.config['exchange'],
                    routing_key=self.config['routing_key'],
                    body=message,
                    properties=pika.BasicProperties(
                        delivery_mode=2,  # Make message persistent
                        timestamp=int(time.time())
                    )
                )
            
            self.circuit_breaker.record_success()
            return True
            
        except Exception as e:
            logging.error(f"Failed to publish batch: {e}")
            self.circuit_breaker.record_failure()
            
            # Attempt to reconnect
            try:
                await self.initialize()
            except:
                pass
            
            return False
    
    async def close(self):
        """Close connection"""
        try:
            if self.channel:
                self.channel.close()
            if self.connection:
                self.connection.close()
        except Exception as e:
            logging.error(f"Error closing connection: {e}")

class CircuitBreaker:
    def __init__(self, failure_threshold: int = 5, recovery_timeout: int = 60):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.failure_count = 0
        self.last_failure_time = None
        self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN
    
    def record_success(self):
        """Record a successful operation"""
        self.failure_count = 0
        self.state = "CLOSED"
    
    def record_failure(self):
        """Record a failed operation"""
        self.failure_count += 1
        self.last_failure_time = time.time()
        
        if self.failure_count >= self.failure_threshold:
            self.state = "OPEN"
    
    def is_open(self) -> bool:
        """Check if circuit breaker is open"""
        if self.state == "CLOSED":
            return False
        
        if self.state == "OPEN":
            # Check if we should move to half-open
            if (time.time() - self.last_failure_time) > self.recovery_timeout:
                self.state = "HALF_OPEN"
                return False
            return True
        
        return False  # HALF_OPEN
    
    def reset(self):
        """Reset circuit breaker"""
        self.failure_count = 0
        self.last_failure_time = None
        self.state = "CLOSED"
