from confluent_kafka.admin import AdminClient, NewTopic, ConfigResource, ResourceType
from confluent_kafka import KafkaException
import logging
import sys
import os

# Add config path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from kafka_config import config

logger = logging.getLogger(__name__)

class TopicManager:
    def __init__(self):
        self.admin_client = AdminClient({'bootstrap.servers': config.bootstrap_servers})
    
    def create_topic(self):
        """Create the partitioned topic for log processing"""
        topic = NewTopic(
            topic=config.topic_name,
            num_partitions=config.partitions,
            replication_factor=config.replication_factor,
            config={
                'cleanup.policy': 'delete',
                'retention.ms': '604800000',  # 7 days
                'segment.ms': '86400000',     # 1 day
                'compression.type': 'snappy'
            }
        )
        
        try:
            # Create topic
            futures = self.admin_client.create_topics([topic])
            
            # Wait for operation to complete
            for topic_name, future in futures.items():
                try:
                    future.result()  # The result itself is None
                    logger.info(f"✅ Topic '{topic_name}' created with {config.partitions} partitions")
                    return True
                except KafkaException as e:
                    if 'TOPIC_ALREADY_EXISTS' in str(e) or 'TopicExistsException' in str(e):
                        logger.info(f"📋 Topic '{topic_name}' already exists - continuing")
                        return True
                    else:
                        logger.error(f"❌ Failed to create topic: {e}")
                        raise e
                        
        except Exception as e:
            logger.error(f"❌ Failed to create topic: {e}")
            # Don't raise - let the function continue
            return False
    
    def get_topic_metadata(self):
        """Get topic metadata including partition information"""
        try:
            metadata = self.admin_client.list_topics(timeout=10)
            if config.topic_name in metadata.topics:
                topic_metadata = metadata.topics[config.topic_name]
                return {
                    'name': config.topic_name,
                    'partitions': len(topic_metadata.partitions),
                    'partition_details': [
                        {
                            'id': partition_id,
                            'leader': partition_metadata.leader,
                            'replicas': [replica for replica in partition_metadata.replicas]
                        } for partition_id, partition_metadata in topic_metadata.partitions.items()
                    ]
                }
            else:
                return None
        except Exception as e:
            logger.error(f"❌ Failed to get topic metadata: {e}")
            return None

def setup_kafka_topic():
    """Setup the Kafka topic for the system"""
    topic_manager = TopicManager()
    
    # Try to create topic (will handle existing topics gracefully)
    topic_manager.create_topic()
    
    # Get metadata to confirm topic is available
    metadata = topic_manager.get_topic_metadata()
    if metadata:
        logger.info(f"✅ Topic setup complete: {metadata['name']} with {metadata['partitions']} partitions")
        return metadata
    else:
        logger.warning("⚠️ Topic metadata not available, but continuing...")
        return {
            'name': config.topic_name,
            'partitions': config.partitions,
            'status': 'unknown'
        }
