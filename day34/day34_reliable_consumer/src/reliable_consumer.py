import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import json
import time
import pika
import threading
from typing import Callable, Optional
import structlog
from config.config import config
from src.ack_tracker import AckTracker, MessageStatus
from src.redelivery_handler import RedeliveryHandler, RetryableError, FatalError

logger = structlog.get_logger()

class ReliableConsumer:
    def __init__(self, processing_callback: Callable[[dict], None]):
        self.processing_callback = processing_callback
        self.connection: Optional[pika.BlockingConnection] = None
        self.channel: Optional[pika.channel.Channel] = None
        self.ack_tracker = AckTracker(timeout_seconds=config.ack_timeout)
        self.redelivery_handler = RedeliveryHandler(
            max_retries=config.max_retries,
            base_delay=config.retry_delay_base,
            max_delay=config.retry_delay_max
        )
        self.is_consuming = False
        self.stats = {
            'messages_processed': 0,
            'messages_acknowledged': 0,
            'messages_failed': 0,
            'messages_redelivered': 0
        }
        
        # Set up callbacks
        self.ack_tracker.set_timeout_callback(self._handle_timeout)
        self.redelivery_handler.set_redelivery_callback(self._handle_redelivery)
    
    def connect(self):
        """Establish connection to RabbitMQ"""
        try:
            credentials = pika.PlainCredentials(config.rabbitmq_user, config.rabbitmq_password)
            parameters = pika.ConnectionParameters(
                host=config.rabbitmq_host,
                port=config.rabbitmq_port,
                credentials=credentials,
                heartbeat=600,
                blocked_connection_timeout=300
            )
            
            self.connection = pika.BlockingConnection(parameters)
            self.channel = self.connection.channel()
            
            # Configure channel
            self.channel.basic_qos(prefetch_count=config.prefetch_count)
            
            # Declare queues and exchanges
            self._setup_queues()
            
            logger.info("Connected to RabbitMQ successfully")
            
        except Exception as e:
            logger.error("Failed to connect to RabbitMQ", error=str(e))
            raise
    
    def _setup_queues(self):
        """Set up queues, exchanges, and bindings"""
        # Declare exchange
        self.channel.exchange_declare(
            exchange=config.exchange_name,
            exchange_type='direct',
            durable=True
        )
        
        # Declare main queue with DLX
        self.channel.queue_declare(
            queue=config.queue_name,
            durable=True,
            arguments={
                'x-dead-letter-exchange': '',
                'x-dead-letter-routing-key': config.dead_letter_queue,
                'x-message-ttl': 300000  # 5 minutes TTL
            }
        )
        
        # Declare dead letter queue
        self.channel.queue_declare(
            queue=config.dead_letter_queue,
            durable=True
        )
        
        # Bind queue to exchange
        self.channel.queue_bind(
            exchange=config.exchange_name,
            queue=config.queue_name,
            routing_key='log.processing'
        )
    
    def start_consuming(self):
        """Start consuming messages with reliable processing"""
        if not self.channel:
            raise RuntimeError("Not connected to RabbitMQ")
        
        self.channel.basic_consume(
            queue=config.queue_name,
            on_message_callback=self._on_message,
            consumer_tag=config.consumer_tag
        )
        
        self.is_consuming = True
        logger.info("Started consuming messages", queue=config.queue_name)
        
        try:
            self.channel.start_consuming()
        except KeyboardInterrupt:
            logger.info("Stopping consumer...")
            self.stop_consuming()
    
    def stop_consuming(self):
        """Stop consuming messages gracefully"""
        if self.channel and self.is_consuming:
            try:
                self.channel.stop_consuming()
            except Exception as e:
                logger.warning("Error stopping consumer", error=str(e))
            self.is_consuming = False
            logger.info("Stopped consuming messages")
    
    def _on_message(self, channel, method, properties, body):
        """Handle incoming message with reliability features"""
        delivery_tag = method.delivery_tag
        
        try:
            # Start tracking the message
            self.ack_tracker.track_message(delivery_tag)
            self.ack_tracker.mark_processing(delivery_tag)
            
            # Parse message
            try:
                message_data = json.loads(body.decode('utf-8'))
            except json.JSONDecodeError as e:
                logger.error("Invalid JSON in message", 
                           delivery_tag=delivery_tag, 
                           error=str(e))
                self._handle_fatal_error(delivery_tag, f"Invalid JSON: {str(e)}")
                return
            
            # Process message with retry logic
            try:
                self._process_with_retry(message_data, delivery_tag)
                
                # Success - acknowledge message
                channel.basic_ack(delivery_tag=delivery_tag)
                self.ack_tracker.acknowledge(delivery_tag)
                self.redelivery_handler.cancel_redelivery(delivery_tag)
                self.stats['messages_acknowledged'] += 1
                
                logger.info("Message processed successfully", 
                          delivery_tag=delivery_tag)
                
            except RetryableError as e:
                # Retryable error - schedule for redelivery
                self.ack_tracker.mark_failed(delivery_tag, str(e))
                
                if self.redelivery_handler.schedule_redelivery(
                    delivery_tag, body, method.routing_key, 
                    self.ack_tracker.get_message_state(delivery_tag).retry_count - 1
                ):
                    channel.basic_nack(delivery_tag=delivery_tag, requeue=False)
                    self.stats['messages_redelivered'] += 1
                else:
                    # Max retries exceeded
                    self._handle_fatal_error(delivery_tag, f"Max retries exceeded: {str(e)}")
                    
            except FatalError as e:
                # Fatal error - reject without requeue
                self._handle_fatal_error(delivery_tag, str(e))
                
        except Exception as e:
            logger.error("Unexpected error in message handler", 
                        delivery_tag=delivery_tag, 
                        error=str(e))
            self._handle_fatal_error(delivery_tag, f"Unexpected error: {str(e)}")
        
        finally:
            self.stats['messages_processed'] += 1
    
    def _process_with_retry(self, message_data: dict, delivery_tag: int):
        """Process message with retry logic"""
        try:
            # Add delivery tag to message for tracking
            message_data['_delivery_tag'] = delivery_tag
            message_data['_processing_timestamp'] = time.time()
            
            # Call the user-provided processing function
            self.processing_callback(message_data)
            
        except Exception as e:
            # Determine if error is retryable
            error_msg = str(e)
            
            # Example retryable conditions
            if any(keyword in error_msg.lower() for keyword in 
                  ['timeout', 'connection', 'temporary', 'unavailable']):
                raise RetryableError(f"Retryable error: {error_msg}")
            else:
                raise FatalError(f"Fatal error: {error_msg}")
    
    def _handle_fatal_error(self, delivery_tag: int, error: str):
        """Handle fatal errors that shouldn't be retried"""
        self.ack_tracker.mark_failed(delivery_tag, error)
        self.channel.basic_nack(delivery_tag=delivery_tag, requeue=False)
        self.stats['messages_failed'] += 1
        
        logger.error("Fatal error - message rejected", 
                    delivery_tag=delivery_tag, 
                    error=error)
    
    def _handle_timeout(self, delivery_tag: int):
        """Handle message processing timeouts"""
        logger.warning("Message processing timeout", delivery_tag=delivery_tag)
        # Implementation would depend on your timeout strategy
        # For this demo, we'll just log it
    
    def _handle_redelivery(self, attempt):
        """Handle message redelivery"""
        # Republish message to the queue
        try:
            if self.connection and not self.connection.is_closed and self.channel and self.channel.is_open:
                self.channel.basic_publish(
                    exchange=config.exchange_name,
                    routing_key=attempt.routing_key,
                    body=attempt.original_message,
                    properties=pika.BasicProperties(
                        headers={'retry_count': attempt.attempt_count}
                    )
                )
                logger.info("Message redelivered", 
                           delivery_tag=attempt.delivery_tag,
                           attempt=attempt.attempt_count)
            else:
                logger.warning("Connection closed, cannot redeliver message",
                             delivery_tag=attempt.delivery_tag)
        except Exception as e:
            logger.error("Failed to redeliver message", 
                        delivery_tag=attempt.delivery_tag,
                        error=str(e))
    
    def get_stats(self) -> dict:
        """Get consumer statistics"""
        stats = self.stats.copy()
        stats.update(self.ack_tracker.get_stats())
        stats.update(self.redelivery_handler.get_stats())
        return stats
    
    def close(self):
        """Close connection and cleanup"""
        if self.is_consuming:
            self.stop_consuming()
        
        self.ack_tracker.stop()
        self.redelivery_handler.stop()
        
        if self.connection and not self.connection.is_closed:
            self.connection.close()
            logger.info("Connection closed")
