import yaml
import os
from typing import Dict, Any
from dataclasses import dataclass
from confluent_kafka.admin import AdminClient, NewTopic, ConfigResource, ResourceType
from confluent_kafka import Producer, Consumer
import structlog

logger = structlog.get_logger(__name__)


@dataclass
class KafkaConfig:
    bootstrap_servers: str
    topic_name: str
    partitions: int
    replication_factor: int
    compaction_config: Dict[str, Any]
    producer_config: Dict[str, Any]
    consumer_config: Dict[str, Any]
    
    @classmethod
    def from_yaml(cls, config_path: str = "config.yaml") -> 'KafkaConfig':
        """Load configuration from YAML file with environment variable override"""
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        kafka_config = config['kafka']
        
        # Check for environment variable override for bootstrap servers
        bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', kafka_config['bootstrap_servers'])
        
        logger.info(f"Using Kafka bootstrap servers: {bootstrap_servers}")
        
        return cls(
            bootstrap_servers=bootstrap_servers,
            topic_name=kafka_config['topic_name'],
            partitions=kafka_config['partitions'],
            replication_factor=kafka_config['replication_factor'],
            compaction_config=kafka_config['compaction'],
            producer_config=kafka_config['producer'],
            consumer_config=kafka_config['consumer']
        )
    
    def create_admin_client(self) -> AdminClient:
        """Create Kafka admin client"""
        admin_config = {
            'bootstrap.servers': self.bootstrap_servers
        }
        return AdminClient(admin_config)
    
    def create_producer(self) -> Producer:
        """Create Kafka producer with compaction-optimized settings"""
        producer_config = {
            'bootstrap.servers': self.bootstrap_servers,
            'acks': self.producer_config['acks'],
            'retries': self.producer_config['retries'],
            'enable.idempotence': self.producer_config['enable_idempotence'],
            'max.in.flight.requests.per.connection': self.producer_config['max_in_flight_requests_per_connection']
        }
        return Producer(producer_config)
    
    def create_consumer(self, group_id: str = None) -> Consumer:
        """Create Kafka consumer"""
        consumer_config = {
            'bootstrap.servers': self.bootstrap_servers,
            'group.id': group_id or self.consumer_config['group_id'],
            'auto.offset.reset': self.consumer_config['auto_offset_reset'],
            'enable.auto.commit': self.consumer_config['enable_auto_commit'],
            'isolation.level': self.consumer_config['isolation_level']
        }
        return Consumer(consumer_config)
    
    def create_compacted_topic(self) -> bool:
        """Create compacted topic with proper configuration"""
        admin = self.create_admin_client()
        
        try:
            # Check if topic exists
            topic_metadata = admin.list_topics(timeout=10)
            if self.topic_name in topic_metadata.topics:
                logger.info(f"Topic {self.topic_name} already exists")
                return True
            
            # Create topic with compaction settings
            topic_config = {
                'cleanup.policy': self.compaction_config['cleanup_policy'],
                'segment.bytes': str(self.compaction_config['segment_bytes']),
                'min.cleanable.dirty.ratio': str(self.compaction_config['min_cleanable_ratio']),
                'delete.retention.ms': str(self.compaction_config['delete_retention_ms'])
            }
            
            new_topic = NewTopic(
                topic=self.topic_name,
                num_partitions=self.partitions,
                replication_factor=self.replication_factor,
                config=topic_config
            )
            
            # Create topic
            futures = admin.create_topics([new_topic])
            
            # Wait for creation
            for topic, future in futures.items():
                try:
                    future.result()  # Block until topic is created
                    logger.info(f"✅ Created compacted topic: {topic}")
                    return True
                except Exception as e:
                    logger.error(f"Failed to create topic {topic}: {e}")
                    return False
                    
        except Exception as e:
            logger.error(f"Error managing topic: {e}")
            return False
