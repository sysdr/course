import json
import logging
import signal
import threading
import time
from typing import Dict, List, Callable, Optional
from datetime import datetime
from confluent_kafka import Consumer, KafkaException, KafkaError
from dataclasses import asdict
import structlog

from config.kafka_config import KafkaConsumerConfig
from processor.message_processor import MessageProcessor
from monitoring.metrics_collector import MetricsCollector

logger = structlog.get_logger()

class KafkaLogConsumer:
    """High-performance Kafka consumer for log processing"""
    
    def __init__(self, config: KafkaConsumerConfig):
        self.config = config
        self.consumer = None
        self.processor = MessageProcessor()
        self.metrics = MetricsCollector()
        self.running = False
        self.processed_count = 0
        self.error_count = 0
        self.last_commit_time = time.time()
        
        # Thread safety
        self.lock = threading.Lock()
        
        # Graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.stop()
        
    def _create_consumer(self) -> Consumer:
        """Create and configure Kafka consumer"""
        consumer_config = {
            'bootstrap.servers': self.config.bootstrap_servers,
            'group.id': self.config.group_id,
            'auto.offset.reset': self.config.auto_offset_reset,
            'enable.auto.commit': self.config.enable_auto_commit,

            'session.timeout.ms': self.config.session_timeout_ms,
            'heartbeat.interval.ms': self.config.heartbeat_interval_ms,
            'max.poll.interval.ms': self.config.max_poll_interval_ms,
            'log.connection.close': False
        }
        
        consumer = Consumer(consumer_config)
        logger.info("Kafka consumer created", config=consumer_config)
        return consumer
        
    def start(self):
        """Start consuming messages"""
        try:
            self.consumer = self._create_consumer()
            self.consumer.subscribe(self.config.topics)
            self.running = True
            
            logger.info("Starting Kafka consumer", 
                       topics=self.config.topics, 
                       group_id=self.config.group_id)
            
            self._consume_loop()
            
        except Exception as e:
            logger.error("Failed to start consumer", error=str(e))
            raise
            
    def _consume_loop(self):
        """Main consumption loop"""
        batch = []
        batch_start_time = time.time()
        
        while self.running:
            try:
                # Poll for messages
                msg = self.consumer.poll(timeout=1.0)
                
                if msg is None:
                    # No message received, check if we should flush batch
                    if batch and (time.time() - batch_start_time) > 5.0:
                        self._process_batch(batch)
                        batch = []
                        batch_start_time = time.time()
                    continue
                    
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        logger.debug("Reached end of partition", 
                                   topic=msg.topic(), 
                                   partition=msg.partition())
                    else:
                        logger.error("Consumer error", error=msg.error())
                        self.error_count += 1
                    continue
                
                # Add message to batch
                batch.append(msg)
                
                # Process batch when it reaches target size or timeout
                if (len(batch) >= self.config.batch_size or 
                    (time.time() - batch_start_time) > 5.0):
                    self._process_batch(batch)
                    batch = []
                    batch_start_time = time.time()
                    
            except KeyboardInterrupt:
                logger.info("Interrupted by user")
                break
            except Exception as e:
                logger.error("Error in consumption loop", error=str(e))
                self.error_count += 1
                time.sleep(1)  # Brief pause before retrying
                
        # Process any remaining messages in batch
        if batch:
            self._process_batch(batch)
            
        self._cleanup()
        
    def _process_batch(self, batch: List):
        """Process a batch of messages"""
        if not batch:
            return
            
        start_time = time.time()
        success_count = 0
        
        try:
            for msg in batch:
                try:
                    # Decode message
                    log_data = json.loads(msg.value().decode('utf-8'))
                    
                    # Add metadata
                    log_data['_kafka_metadata'] = {
                        'topic': msg.topic(),
                        'partition': msg.partition(),
                        'offset': msg.offset(),
                        'timestamp': msg.timestamp()[1] if msg.timestamp()[1] else int(time.time() * 1000),
                        'key': msg.key().decode('utf-8') if msg.key() else None
                    }
                    
                    # Process message
                    self.processor.process_log_entry(log_data)
                    success_count += 1
                    
                except json.JSONDecodeError as e:
                    logger.error("JSON decode error", 
                               topic=msg.topic(), 
                               partition=msg.partition(), 
                               offset=msg.offset(),
                               error=str(e))
                    self.error_count += 1
                    
                except Exception as e:
                    logger.error("Processing error", 
                               topic=msg.topic(), 
                               partition=msg.partition(), 
                               offset=msg.offset(),
                               error=str(e))
                    self.error_count += 1
            
            # Commit offsets after successful processing
            self.consumer.commit(asynchronous=False)
            self.processed_count += success_count
            
            # Update metrics
            processing_time = time.time() - start_time
            self.metrics.record_batch_processed(len(batch), success_count, processing_time)
            
            logger.info("Batch processed", 
                       batch_size=len(batch), 
                       success_count=success_count, 
                       processing_time=f"{processing_time:.3f}s")
            
        except Exception as e:
            logger.error("Batch processing failed", error=str(e))
            self.error_count += len(batch)
            
    def get_stats(self) -> Dict:
        """Get consumer statistics"""
        return {
            'processed_count': self.processed_count,
            'error_count': self.error_count,
            'success_rate': (self.processed_count / (self.processed_count + self.error_count)) * 100 
                           if (self.processed_count + self.error_count) > 0 else 0,
            'running': self.running,
            'topics': self.config.topics,
            'group_id': self.config.group_id,
            'processor_stats': self.processor.get_stats(),
            'metrics': self.metrics.get_current_metrics()
        }
        
    def stop(self):
        """Stop the consumer gracefully"""
        logger.info("Stopping Kafka consumer...")
        self.running = False
        
    def _cleanup(self):
        """Clean up resources"""
        if self.consumer:
            logger.info("Closing Kafka consumer...")
            self.consumer.close()
            
        logger.info("Consumer shutdown complete", 
                   processed=self.processed_count, 
                   errors=self.error_count)
