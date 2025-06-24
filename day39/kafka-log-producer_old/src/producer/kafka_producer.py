import json
import time
import threading
from typing import Optional, Dict, Any, Callable
from confluent_kafka import Producer, KafkaError
from confluent_kafka.admin import AdminClient, NewTopic
import structlog
import yaml
from pathlib import Path

from models.log_entry import LogEntry
from monitoring.producer_metrics import ProducerMetrics

logger = structlog.get_logger()

class KafkaLogProducer:
    """High-performance Kafka producer for log ingestion"""
    
    def __init__(self, config_path: str = "config/producer_config.yaml"):
        self.config = self._load_config(config_path)
        self.producer = None
        self.metrics = ProducerMetrics(self.config['monitoring']['metrics_port'])
        self.running = False
        self._callbacks = {}
        
        # Initialize producer with retry logic
        self._initialize_producer_with_retry()
        self._create_topics_with_retry()
        
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            raise
            
    def _initialize_producer_with_retry(self, max_retries: int = 10, retry_delay: float = 3.0):
        """Initialize Kafka producer with retry logic"""
        producer_config = {
            'bootstrap.servers': self.config['kafka']['bootstrap.servers'],
            'client.id': self.config['kafka']['client.id'],
            'security.protocol': self.config['kafka']['security.protocol'],
            'acks': self.config['producer']['acks'],
            'retries': self.config['producer']['retries'],
            'batch.size': self.config['producer']['batch.size'],
            'linger.ms': self.config['producer']['linger.ms'],
            'compression.type': self.config['producer']['compression.type'],
            'enable.idempotence': self.config['producer']['enable.idempotence'],
            'request.timeout.ms': self.config['producer']['request.timeout.ms'],
        }
        
        for attempt in range(max_retries):
            try:
                self.producer = Producer(producer_config)
                # Test the connection by getting metadata
                self.producer.list_topics(timeout=5)
                logger.info("Kafka producer initialized successfully")
                return
            except Exception as e:
                logger.warning(f"Producer initialization attempt {attempt + 1}/{max_retries} failed: {e}")
                if attempt < max_retries - 1:
                    logger.info(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                else:
                    logger.error(f"Failed to initialize producer after {max_retries} attempts")
                    raise
            
    def _create_topics_with_retry(self, max_retries: int = 5, retry_delay: float = 2.0):
        """Ensure required topics exist with retry logic"""
        admin_client = AdminClient({
            'bootstrap.servers': self.config['kafka']['bootstrap.servers']
        })
        
        topics = [
            NewTopic(topic, num_partitions=3, replication_factor=1)
            for topic in self.config['topics'].values()
        ]
        
        for attempt in range(max_retries):
            try:
                fs = admin_client.create_topics(topics)
                for topic, f in fs.items():
                    try:
                        f.result()  # The result itself is None
                        logger.info(f"Topic {topic} created")
                    except Exception as e:
                        if "already exists" not in str(e):
                            logger.error(f"Failed to create topic {topic}: {e}")
                logger.info("All topics created successfully")
                return
            except Exception as e:
                logger.warning(f"Topic creation attempt {attempt + 1}/{max_retries} failed: {e}")
                if attempt < max_retries - 1:
                    logger.info(f"Retrying topic creation in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                else:
                    logger.error(f"Failed to create topics after {max_retries} attempts")
                    # Don't raise here, as the producer might still work with existing topics
            
    def _delivery_callback(self, err, msg):
        """Callback for message delivery confirmation"""
        if err is not None:
            error_type = err.name() if hasattr(err, 'name') else str(type(err).__name__)
            self.metrics.record_message_failed(msg.topic(), error_type)
            logger.error(f"Message delivery failed: {err}")
        else:
            self.metrics.record_message_sent(
                msg.topic(), 
                msg.partition(), 
                len(msg.value())
            )
            logger.debug(f"Message delivered to {msg.topic()}[{msg.partition()}]")
            
    def send_log(self, log_entry: LogEntry, callback: Optional[Callable] = None) -> bool:
        """Send a single log entry to Kafka"""
        try:
            start_time = time.time()
            
            topic = log_entry.get_topic()
            key = log_entry.get_partition_key()
            message = log_entry.to_kafka_message()
            
            # Send to Kafka
            self.producer.produce(
                topic=topic,
                key=key.encode('utf-8') if key else None,
                value=message,
                callback=self._delivery_callback
            )
            
            # Record metrics
            latency = time.time() - start_time
            self.metrics.record_send_latency(topic, latency)
            
            logger.debug(f"Log sent to topic {topic}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to send log: {e}")
            self.metrics.record_message_failed("unknown", str(type(e).__name__))
            return False
            
    def send_logs_batch(self, log_entries: list[LogEntry]) -> Dict[str, int]:
        """Send multiple log entries efficiently"""
        results = {"sent": 0, "failed": 0}
        
        try:
            for log_entry in log_entries:
                if self.send_log(log_entry):
                    results["sent"] += 1
                else:
                    results["failed"] += 1
                    
            # Trigger send of batched messages
            self.producer.poll(0)
            
            return results
            
        except Exception as e:
            logger.error(f"Batch send failed: {e}")
            results["failed"] = len(log_entries)
            return results
            
    def flush(self, timeout: float = 10.0):
        """Flush pending messages"""
        try:
            remaining = self.producer.flush(timeout)
            if remaining > 0:
                logger.warning(f"{remaining} messages still pending after flush")
            else:
                logger.info("All messages flushed successfully")
        except Exception as e:
            logger.error(f"Flush failed: {e}")
            
    def close(self):
        """Close producer and clean up resources"""
        if self.producer:
            logger.info("Closing Kafka producer")
            self.flush()
            self.producer = None
            
    def get_stats(self) -> Dict[str, Any]:
        """Get producer statistics"""
        if not self.producer:
            return {}
            
        try:
            stats_json = self.producer.list_topics(timeout=5)
            return {
                "topics": len(stats_json.topics),
                "brokers": len(stats_json.brokers),
                "producer_active": self.producer is not None
            }
        except Exception as e:
            logger.error(f"Failed to get stats: {e}")
            return {
                "topics": 0,
                "brokers": 0,
                "producer_active": False
            }
