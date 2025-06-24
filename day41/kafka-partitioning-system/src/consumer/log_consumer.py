import json
import time
import signal
import threading
from datetime import datetime
from typing import Dict, List, Optional, Callable
from confluent_kafka import Consumer, KafkaError, TopicPartition
import structlog
import sys
import os

# Add config path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.kafka_config import config

logger = structlog.get_logger(__name__)

class LogConsumer:
    def __init__(self, consumer_id: str, processing_callback: Optional[Callable] = None):
        self.consumer_id = consumer_id
        self.consumer = Consumer(config.get_consumer_config(consumer_id))
        self.processing_callback = processing_callback or self.default_process_message
        self.running = False
        self.message_count = 0
        self.error_count = 0
        self.assigned_partitions = []
        self.stats = {
            'messages_processed': 0,
            'errors': 0,
            'processing_time_ms': 0,
            'last_processed': None,
            'assigned_partitions': []
        }
        
        # Note: Signal handlers are only set up in the main thread
        # to avoid "signal only works in main thread" errors
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        logger.info(f"🛑 Consumer {self.consumer_id} received shutdown signal")
        self.stop()
    
    def setup_signal_handlers(self):
        """Setup signal handlers (only call from main thread)"""
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def on_assign(self, consumer, partitions):
        """Callback when partitions are assigned to this consumer"""
        self.assigned_partitions = [p.partition for p in partitions]
        partition_list = ", ".join(str(p.partition) for p in partitions)
        logger.info(f"📍 Consumer {self.consumer_id} assigned partitions: [{partition_list}]")
        self.stats['assigned_partitions'] = self.assigned_partitions
    
    def on_revoke(self, consumer, partitions):
        """Callback when partitions are revoked from this consumer"""
        partition_list = ", ".join(str(p.partition) for p in partitions)
        logger.info(f"📤 Consumer {self.consumer_id} revoked partitions: [{partition_list}]")
        self.assigned_partitions = []
        self.stats['assigned_partitions'] = []
    
    def default_process_message(self, message_data: Dict) -> bool:
        """Default message processing logic"""
        try:
            # Simulate different processing times based on log level
            processing_time = {
                'DEBUG': 0.01,
                'INFO': 0.02,
                'WARN': 0.05,
                'ERROR': 0.1
            }.get(message_data.get('level', 'INFO'), 0.02)
            
            time.sleep(processing_time)
            
            # Log processing details periodically
            if self.message_count % 50 == 0:
                logger.info(f"🔄 Consumer {self.consumer_id} processed: {message_data.get('service', 'unknown')} "
                           f"- {message_data.get('level', 'INFO')} - User: {message_data.get('user_id', 'unknown')}")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Processing error in {self.consumer_id}: {e}")
            return False
    
    def start_consuming(self):
        """Start consuming messages from assigned partitions"""
        self.running = True
        
        # Subscribe to topic with rebalance callbacks
        self.consumer.subscribe([config.topic_name], 
                              on_assign=self.on_assign, 
                              on_revoke=self.on_revoke)
        
        logger.info(f"🚀 Consumer {self.consumer_id} started consuming from topic: {config.topic_name}")
        
        try:
            while self.running:
                # Poll for messages
                msg = self.consumer.poll(timeout=1.0)
                
                if msg is None:
                    continue
                    
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        logger.debug(f"📄 End of partition reached: {msg.topic()}[{msg.partition()}]")
                    else:
                        logger.error(f"❌ Consumer error: {msg.error()}")
                        self.error_count += 1
                    continue
                
                # Process the message
                start_time = time.time()
                success = self._process_kafka_message(msg)
                processing_time = (time.time() - start_time) * 1000
                
                if success:
                    self.message_count += 1
                    self.stats['messages_processed'] = self.message_count
                    self.stats['processing_time_ms'] += processing_time
                    self.stats['last_processed'] = datetime.now().isoformat()
                else:
                    self.error_count += 1
                    self.stats['errors'] = self.error_count
                    
        except KeyboardInterrupt:
            logger.info(f"🛑 Consumer {self.consumer_id} interrupted by user")
        except Exception as e:
            logger.error(f"❌ Consumer {self.consumer_id} error: {e}")
        finally:
            self.stop()
    
    def _process_kafka_message(self, msg) -> bool:
        """Process a Kafka message"""
        try:
            # Decode message
            key = msg.key().decode('utf-8') if msg.key() else None
            value = json.loads(msg.value().decode('utf-8'))
            
            # Add partition and offset info
            value['_kafka_partition'] = msg.partition()
            value['_kafka_offset'] = msg.offset()
            value['_consumer_id'] = self.consumer_id
            
            # Process using callback
            return self.processing_callback(value)
            
        except json.JSONDecodeError as e:
            logger.error(f"❌ JSON decode error in {self.consumer_id}: {e}")
            return False
        except Exception as e:
            logger.error(f"❌ Message processing error in {self.consumer_id}: {e}")
            return False
    
    def stop(self):
        """Stop the consumer gracefully"""
        self.running = False
        if self.consumer:
            self.consumer.close()
        logger.info(f"✅ Consumer {self.consumer_id} stopped. Processed: {self.message_count}, Errors: {self.error_count}")
    
    def get_stats(self) -> Dict:
        """Get consumer statistics"""
        avg_processing_time = (self.stats['processing_time_ms'] / max(1, self.message_count))
        
        return {
            'consumer_id': self.consumer_id,
            'messages_processed': self.message_count,
            'errors': self.error_count,
            'success_rate': (self.message_count / max(1, self.message_count + self.error_count)) * 100,
            'assigned_partitions': self.assigned_partitions,
            'avg_processing_time_ms': round(avg_processing_time, 2),
            'last_processed': self.stats['last_processed'],
            'status': 'running' if self.running else 'stopped'
        }

class ConsumerGroupManager:
    def __init__(self, group_size: int = 3):
        self.group_size = group_size
        self.consumers: List[LogConsumer] = []
        self.consumer_threads: List[threading.Thread] = []
        self.running = False
    
    def start_consumer_group(self):
        """Start a group of consumers"""
        self.running = True
        logger.info(f"🚀 Starting consumer group with {self.group_size} consumers")
        
        for i in range(self.group_size):
            consumer_id = f"consumer-{i+1}"
            consumer = LogConsumer(consumer_id)
            self.consumers.append(consumer)
            
            # Start consumer in separate thread
            thread = threading.Thread(target=consumer.start_consuming, daemon=True)
            thread.start()
            self.consumer_threads.append(thread)
            
            time.sleep(1)  # Stagger consumer starts
        
        logger.info(f"✅ Started {len(self.consumers)} consumers in group")
    
    def stop_consumer_group(self):
        """Stop all consumers in the group"""
        self.running = False
        logger.info("🛑 Stopping consumer group...")
        
        for consumer in self.consumers:
            consumer.stop()
        
        # Wait for threads to complete
        for thread in self.consumer_threads:
            thread.join(timeout=5)
        
        logger.info("✅ Consumer group stopped")
    
    def get_group_stats(self) -> Dict:
        """Get statistics for the entire consumer group"""
        total_processed = sum(c.message_count for c in self.consumers)
        total_errors = sum(c.error_count for c in self.consumers)
        
        consumer_stats = [c.get_stats() for c in self.consumers]
        
        return {
            'group_size': len(self.consumers),
            'total_processed': total_processed,
            'total_errors': total_errors,
            'group_success_rate': (total_processed / max(1, total_processed + total_errors)) * 100,
            'consumers': consumer_stats,
            'active_consumers': sum(1 for c in self.consumers if c.running)
        }

def run_consumer_demo():
    """Run a demonstration of the consumer group"""
    manager = ConsumerGroupManager(group_size=3)
    
    try:
        manager.start_consumer_group()
        
        # Run for demonstration period
        time.sleep(30)
        
        # Print statistics
        stats = manager.get_group_stats()
        logger.info(f"📊 Consumer group stats: {json.dumps(stats, indent=2)}")
        
    except KeyboardInterrupt:
        logger.info("🛑 Consumer demo interrupted")
    finally:
        manager.stop_consumer_group()

if __name__ == "__main__":
    run_consumer_demo()
