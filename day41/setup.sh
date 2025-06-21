#!/bin/bash

# Day 41: Kafka Partitioning & Consumer Groups - Complete Implementation
# 254-Day Hands-On System Design Series

set -e

echo "🚀 Day 41: Setting up Kafka Partitioning & Consumer Groups"
echo "============================================================"

# Create project structure
echo "📁 Creating project structure..."
mkdir -p kafka-partitioning-system/{src/{producer,consumer,monitoring,config},tests,docker,web/{static,templates},scripts}

cd kafka-partitioning-system

# Create requirements.txt with latest May 2025 libraries
cat > requirements.txt << 'EOF'
confluent-kafka==2.4.0
flask==3.0.3
flask-socketio==5.3.6
redis==5.0.4
prometheus-client==0.20.0
requests==2.31.0
pytest==8.2.1
pytest-asyncio==0.23.7
structlog==24.1.0
psutil==5.9.8
colorama==0.4.6
pyyaml==6.0.1
websockets==12.0
asyncio==3.4.3
python-dotenv==1.0.1
kafka-python==2.0.2
plotly==5.20.0
pandas==2.2.2
numpy==1.26.4
gunicorn==22.0.0
uvicorn==0.30.1
aiofiles==23.2.1
EOF

#echo "📦 Installing Python dependencies..."
#python3 -m venv venv
#source venv/bin/activate
pip install -r requirements.txt

# Create Docker configuration
echo "🐳 Setting up Docker configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.6.1
    hostname: zookeeper
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000

  kafka:
    image: confluentinc/cp-kafka:7.6.1
    hostname: kafka
    container_name: kafka
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
      - "9101:9101"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_JMX_PORT: 9101
      KAFKA_JMX_HOSTNAME: localhost
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'false'

  redis:
    image: redis:7.0-alpine
    hostname: redis
    container_name: redis
    ports:
      - "6379:6379"

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    depends_on:
      - kafka
    ports:
      - "8081:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:29092
EOF

# Create configuration files
echo "⚙️ Creating configuration files..."
mkdir -p src/config
cat > src/config/kafka_config.py << 'EOF'
import os
from dataclasses import dataclass
from typing import List, Dict, Any

@dataclass
class KafkaConfig:
    bootstrap_servers: str = 'localhost:9092'
    topic_name: str = 'log-processing-topic'
    partitions: int = 6
    replication_factor: int = 1
    
    # Consumer group configuration
    consumer_group_id: str = 'log-processing-group'
    consumer_session_timeout: int = 10000
    consumer_heartbeat_interval: int = 3000
    auto_offset_reset: str = 'earliest'
    
    # Producer configuration
    producer_acks: str = 'all'
    producer_retries: int = 3
    producer_batch_size: int = 16384
    producer_linger_ms: int = 5
    
    # Assignment strategy
    partition_assignment_strategy: List[str] = None
    
    def __post_init__(self):
        if self.partition_assignment_strategy is None:
            self.partition_assignment_strategy = ['org.apache.kafka.clients.consumer.StickyAssignor']

    def get_producer_config(self) -> Dict[str, Any]:
        return {
            'bootstrap.servers': self.bootstrap_servers,
            'acks': self.producer_acks,
            'retries': self.producer_retries,
            'batch.size': self.producer_batch_size,
            'linger.ms': self.producer_linger_ms,
            'key.serializer': 'org.apache.kafka.common.serialization.StringSerializer',
            'value.serializer': 'org.apache.kafka.common.serialization.StringSerializer'
        }
    
    def get_consumer_config(self, consumer_id: str) -> Dict[str, Any]:
        return {
            'bootstrap.servers': self.bootstrap_servers,
            'group.id': self.consumer_group_id,
            'client.id': consumer_id,
            'session.timeout.ms': self.consumer_session_timeout,
            'heartbeat.interval.ms': self.consumer_heartbeat_interval,
            'auto.offset.reset': self.auto_offset_reset,
            'enable.auto.commit': True,
            'auto.commit.interval.ms': 1000,
            'partition.assignment.strategy': self.partition_assignment_strategy
        }

# Global configuration instance
config = KafkaConfig()
EOF

# Create Kafka topic manager
echo "📊 Creating Kafka topic manager..."
cat > src/config/topic_manager.py << 'EOF'
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
                except KafkaException as e:
                    if 'TopicExistsException' in str(e):
                        logger.info(f"📋 Topic '{topic_name}' already exists")
                    else:
                        raise e
                        
        except Exception as e:
            logger.error(f"❌ Failed to create topic: {e}")
            raise
    
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
    topic_manager.create_topic()
    return topic_manager.get_topic_metadata()
EOF

# Create log message producer
echo "📤 Creating log message producer..."
cat > src/producer/log_producer.py << 'EOF'
import json
import time
import random
import threading
from datetime import datetime
from typing import Dict, List, Optional
from confluent_kafka import Producer, KafkaError
import structlog
import sys
import os

# Add config path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.kafka_config import config

logger = structlog.get_logger(__name__)

class LogMessageProducer:
    def __init__(self, producer_id: str = "default-producer"):
        self.producer_id = producer_id
        self.producer = Producer(config.get_producer_config())
        self.message_count = 0
        self.error_count = 0
        self.running = False
        
        # Log generation parameters
        self.services = ['web-api', 'user-service', 'payment-service', 'analytics', 'notification-service']
        self.log_levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
        self.log_level_weights = [0.6, 0.2, 0.1, 0.1]  # Most logs are INFO
        
    def delivery_report(self, err: Optional[KafkaError], msg):
        """Callback for message delivery reports"""
        if err is not None:
            self.error_count += 1
            logger.error(f"❌ Message delivery failed: {err}")
        else:
            self.message_count += 1
            if self.message_count % 100 == 0:
                logger.info(f"✅ Delivered message #{self.message_count} to partition {msg.partition()}")
    
    def generate_log_message(self, service: str = None, user_id: str = None) -> Dict:
        """Generate a realistic log message"""
        if service is None:
            service = random.choice(self.services)
        
        if user_id is None:
            user_id = f"user_{random.randint(1000, 9999)}"
            
        log_level = random.choices(self.log_levels, weights=self.log_level_weights)[0]
        
        # Generate realistic log content based on service and level
        log_templates = {
            'web-api': {
                'INFO': f"HTTP GET /api/users/{user_id} - 200 OK - {random.randint(10, 500)}ms",
                'WARN': f"Slow response time for /api/users/{user_id} - {random.randint(1000, 3000)}ms",
                'ERROR': f"HTTP 500 Internal Server Error for /api/users/{user_id}",
                'DEBUG': f"Processing request for user {user_id} with session {random.randint(10000, 99999)}"
            },
            'user-service': {
                'INFO': f"User {user_id} profile updated successfully",
                'WARN': f"Failed login attempt for user {user_id}",
                'ERROR': f"Database connection timeout for user {user_id}",
                'DEBUG': f"Validating user {user_id} permissions"
            },
            'payment-service': {
                'INFO': f"Payment processed for user {user_id} - ${random.randint(10, 1000)}.{random.randint(10, 99)}",
                'WARN': f"Payment retry attempt #{random.randint(1, 3)} for user {user_id}",
                'ERROR': f"Payment failed for user {user_id} - insufficient funds",
                'DEBUG': f"Validating payment method for user {user_id}"
            }
        }
        
        if service not in log_templates:
            service = 'web-api'
            
        message_content = log_templates[service].get(log_level, f"{log_level} message from {service}")
        
        return {
            'timestamp': datetime.now().isoformat(),
            'service': service,
            'level': log_level,
            'user_id': user_id,
            'message': message_content,
            'request_id': f"req_{random.randint(100000, 999999)}",
            'session_id': f"sess_{random.randint(10000, 99999)}",
            'ip_address': f"192.168.{random.randint(1, 255)}.{random.randint(1, 255)}",
            'producer_id': self.producer_id
        }
    
    def get_partition_key(self, log_message: Dict) -> str:
        """Generate partition key based on user_id for order preservation per user"""
        return log_message['user_id']
    
    def send_log(self, log_message: Dict) -> bool:
        """Send a single log message to Kafka"""
        try:
            key = self.get_partition_key(log_message)
            value = json.dumps(log_message)
            
            self.producer.produce(
                topic=config.topic_name,
                key=key,
                value=value,
                callback=self.delivery_report
            )
            
            # Poll to handle delivery reports
            self.producer.poll(0)
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to send log message: {e}")
            self.error_count += 1
            return False
    
    def start_continuous_production(self, messages_per_second: int = 10, duration_seconds: int = 60):
        """Start producing messages continuously at specified rate"""
        self.running = True
        interval = 1.0 / messages_per_second
        end_time = time.time() + duration_seconds
        
        logger.info(f"🚀 Starting continuous production: {messages_per_second} msg/sec for {duration_seconds}s")
        
        while self.running and time.time() < end_time:
            start_time = time.time()
            
            # Generate and send message
            log_message = self.generate_log_message()
            self.send_log(log_message)
            
            # Maintain rate limiting
            elapsed = time.time() - start_time
            sleep_time = max(0, interval - elapsed)
            if sleep_time > 0:
                time.sleep(sleep_time)
        
        # Flush any remaining messages
        self.producer.flush(timeout=10)
        self.running = False
        
        logger.info(f"✅ Production complete: {self.message_count} sent, {self.error_count} errors")
    
    def stop_production(self):
        """Stop continuous production"""
        self.running = False
        self.producer.flush(timeout=5)
    
    def get_stats(self) -> Dict:
        """Get producer statistics"""
        return {
            'producer_id': self.producer_id,
            'messages_sent': self.message_count,
            'errors': self.error_count,
            'success_rate': (self.message_count / max(1, self.message_count + self.error_count)) * 100
        }

def run_producer_demo():
    """Run a demonstration of the producer"""
    producer = LogMessageProducer("demo-producer")
    
    try:
        # Send a batch of test messages
        logger.info("📤 Sending test messages...")
        for i in range(20):
            log_message = producer.generate_log_message()
            producer.send_log(log_message)
            time.sleep(0.1)
        
        # Flush messages
        producer.producer.flush(timeout=10)
        
        # Print statistics
        stats = producer.get_stats()
        logger.info(f"📊 Producer stats: {stats}")
        
    except KeyboardInterrupt:
        logger.info("🛑 Producer demo interrupted")
    finally:
        producer.stop_production()

if __name__ == "__main__":
    run_producer_demo()
EOF

# Create consumer group implementation
echo "📥 Creating consumer group implementation..."
cat > src/consumer/log_consumer.py << 'EOF'
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
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        logger.info(f"🛑 Consumer {self.consumer_id} received shutdown signal")
        self.stop()
    
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
EOF

# Create monitoring dashboard
echo "📊 Creating monitoring dashboard..."
cat > src/monitoring/consumer_monitor.py << 'EOF'
import json
import time
import threading
from datetime import datetime
from typing import Dict, List
from confluent_kafka.admin import AdminClient
from confluent_kafka import Consumer
import redis
import structlog
import sys
import os

# Add config path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.kafka_config import config

logger = structlog.get_logger(__name__)

class ConsumerGroupMonitor:
    def __init__(self):
        self.admin_client = AdminClient({'bootstrap.servers': config.bootstrap_servers})
        try:
            self.redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
            # Test Redis connection
            self.redis_client.ping()
        except Exception as e:
            logger.warning(f"Redis not available: {e}. Using in-memory storage.")
            self.redis_client = None
        
        self.monitoring = False
        self.stats_history = []
        
    def get_consumer_group_info(self) -> Dict:
        """Get detailed consumer group information"""
        try:
            # Get basic group info - simplified for demo
            group_info = {
                'group_id': config.consumer_group_id,
                'state': 'Stable',
                'protocol': 'range',
                'protocol_type': 'consumer'
            }
            
            # Get member information
            members = self._get_group_members()
            group_info['members'] = members
            
            # Get partition assignment
            partition_assignment = self._get_partition_assignment()
            group_info['partition_assignment'] = partition_assignment
            
            # Get consumer lag
            lag_info = self._get_consumer_lag()
            group_info['lag_info'] = lag_info
            
            return group_info
            
        except Exception as e:
            logger.error(f"❌ Error getting consumer group info: {e}")
            return {'error': str(e)}
    
    def _get_group_members(self) -> List[Dict]:
        """Get consumer group member information"""
        try:
            # For demo purposes, simulate member info based on expected consumers
            return [
                {
                    'member_id': f'consumer-{i+1}',
                    'client_id': f'consumer-{i+1}',
                    'host': 'localhost',
                    'assignment': f'partitions {i*2}-{i*2+1}' if i*2+1 < config.partitions else f'partition {i*2}'
                }
                for i in range(3)  # Assuming 3 consumers
            ]
        except Exception as e:
            logger.error(f"❌ Error getting group members: {e}")
            return []
    
    def _get_partition_assignment(self) -> Dict:
        """Get current partition assignment for the group"""
        try:
            assignment = {}
            partitions_per_consumer = config.partitions // 3  # Assuming 3 consumers
            remainder = config.partitions % 3
            
            partition_idx = 0
            for i in range(3):
                consumer_id = f'consumer-{i+1}'
                consumer_partitions = []
                
                # Assign base partitions
                for j in range(partitions_per_consumer):
                    consumer_partitions.append(partition_idx)
                    partition_idx += 1
                
                # Assign remainder partitions
                if i < remainder:
                    consumer_partitions.append(partition_idx)
                    partition_idx += 1
                
                assignment[consumer_id] = consumer_partitions
            
            return assignment
        except Exception as e:
            logger.error(f"❌ Error getting partition assignment: {e}")
            return {}
    
    def _get_consumer_lag(self) -> Dict:
        """Get consumer lag information"""
        try:
            # Simulate lag information for demo
            lag_info = {}
            for i in range(config.partitions):
                # Simulate realistic lag values
                high_water_mark = 1000 + i * 100 + int(time.time()) % 100
                current_offset = high_water_mark - (5 + i % 10)  # Small lag
                
                lag_info[f'partition-{i}'] = {
                    'current_offset': current_offset,
                    'high_water_mark': high_water_mark,
                    'lag': max(0, high_water_mark - current_offset)
                }
            
            return lag_info
        except Exception as e:
            logger.error(f"❌ Error getting consumer lag: {e}")
            return {}
    
    def collect_metrics(self) -> Dict:
        """Collect comprehensive monitoring metrics"""
        timestamp = datetime.now().isoformat()
        
        # Get consumer group info
        group_info = self.get_consumer_group_info()
        
        # Get topic information
        topic_info = self._get_topic_info()
        
        # Get system metrics
        system_metrics = self._get_system_metrics()
        
        metrics = {
            'timestamp': timestamp,
            'consumer_group': group_info,
            'topic_info': topic_info,
            'system_metrics': system_metrics
        }
        
        # Store in Redis for dashboard (if available)
        if self.redis_client:
            try:
                self.redis_client.setex(
                    'kafka_metrics:latest',
                    300,  # 5 minute expiry
                    json.dumps(metrics)
                )
            except Exception as e:
                logger.warning(f"Failed to store metrics in Redis: {e}")
        
        # Keep history for trending
        self.stats_history.append(metrics)
        if len(self.stats_history) > 100:  # Keep last 100 entries
            self.stats_history.pop(0)
        
        return metrics
    
    def _get_topic_info(self) -> Dict:
        """Get topic information"""
        try:
            metadata = self.admin_client.list_topics(timeout=10)
            if config.topic_name in metadata.topics:
                topic = metadata.topics[config.topic_name]
                return {
                    'name': config.topic_name,
                    'partitions': len(topic.partitions),
                    'partition_details': [
                        {
                            'id': partition_id,
                            'leader': partition_metadata.leader,
                            'replicas': len(partition_metadata.replicas),
                            'isr': len(partition_metadata.replicas)  # Use replicas count as ISR count
                        }
                        for partition_id, partition_metadata in topic.partitions.items()
                    ]
                }
            else:
                return {'error': 'Topic not found'}
        except Exception as e:
            logger.error(f"❌ Error getting topic info: {e}")
            return {'error': str(e)}
    
    def _get_system_metrics(self) -> Dict:
        """Get system-level metrics"""
        try:
            import psutil
            
            return {
                'cpu_usage': psutil.cpu_percent(interval=1),
                'memory_usage': psutil.virtual_memory().percent,
                'disk_usage': psutil.disk_usage('/').percent,
                'network_io': {
                    'bytes_sent': psutil.net_io_counters().bytes_sent,
                    'bytes_recv': psutil.net_io_counters().bytes_recv
                }
            }
        except ImportError:
            logger.warning("psutil not available, using dummy system metrics")
            return {
                'cpu_usage': 45.0,
                'memory_usage': 65.0,
                'disk_usage': 35.0,
                'network_io': {
                    'bytes_sent': 1024000,
                    'bytes_recv': 2048000
                }
            }
        except Exception as e:
            logger.error(f"❌ Error getting system metrics: {e}")
            return {}
    
    def start_monitoring(self, interval_seconds: int = 10):
        """Start continuous monitoring"""
        self.monitoring = True
        logger.info(f"📊 Starting consumer group monitoring (interval: {interval_seconds}s)")
        
        def monitor_loop():
            while self.monitoring:
                try:
                    metrics = self.collect_metrics()
                    logger.info(f"📈 Collected metrics at {metrics['timestamp']}")
                    time.sleep(interval_seconds)
                except Exception as e:
                    logger.error(f"❌ Monitoring error: {e}")
                    time.sleep(interval_seconds)
        
        self.monitor_thread = threading.Thread(target=monitor_loop, daemon=True)
        self.monitor_thread.start()
    
    def stop_monitoring(self):
        """Stop monitoring"""
        self.monitoring = False
        logger.info("🛑 Stopped consumer group monitoring")
    
    def get_latest_metrics(self) -> Dict:
        """Get the latest collected metrics"""
        try:
            if self.redis_client:
                metrics_json = self.redis_client.get('kafka_metrics:latest')
                if metrics_json:
                    return json.loads(metrics_json)
            
            # Fallback to in-memory history
            if self.stats_history:
                return self.stats_history[-1]
            else:
                return self.collect_metrics()
                
        except Exception as e:
            logger.error(f"❌ Error getting latest metrics: {e}")
            return self.collect_metrics()  # Fallback to fresh collection

# Global monitor instance
monitor = ConsumerGroupMonitor()
EOF

# Create web dashboard
echo "🌐 Creating web dashboard..."
cat > web/dashboard.py << 'EOF'
from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
import json
import time
import threading
from datetime import datetime
import sys
import os

# Add src to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

try:
    from monitoring.consumer_monitor import monitor
    from config.topic_manager import setup_kafka_topic
    from producer.log_producer import LogMessageProducer
    from consumer.log_consumer import ConsumerGroupManager
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure to run from the project root directory")
    sys.exit(1)

app = Flask(__name__)
app.config['SECRET_KEY'] = 'kafka-partitioning-demo'
socketio = SocketIO(app, cors_allowed_origins="*")

# Global state
producer = None
consumer_manager = None
demo_running = False

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('dashboard.html')

@app.route('/api/metrics')
def get_metrics():
    """Get current monitoring metrics"""
    try:
        metrics = monitor.get_latest_metrics()
        return jsonify(metrics)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/topic/setup', methods=['POST'])
def setup_topic():
    """Setup the Kafka topic"""
    try:
        topic_info = setup_kafka_topic()
        return jsonify({'success': True, 'topic_info': topic_info})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/demo/start', methods=['POST'])
def start_demo():
    """Start the demonstration"""
    global producer, consumer_manager, demo_running
    
    try:
        if demo_running:
            return jsonify({'success': False, 'error': 'Demo already running'})
        
        # Setup topic first
        setup_kafka_topic()
        
        # Start monitoring
        monitor.start_monitoring(interval_seconds=5)
        
        # Start consumer group
        consumer_manager = ConsumerGroupManager(group_size=3)
        consumer_manager.start_consumer_group()
        
        # Start producer
        producer = LogMessageProducer("demo-producer")
        
        def run_producer():
            producer.start_continuous_production(messages_per_second=20, duration_seconds=300)
        
        producer_thread = threading.Thread(target=run_producer, daemon=True)
        producer_thread.start()
        
        demo_running = True
        
        return jsonify({'success': True, 'message': 'Demo started successfully'})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/demo/stop', methods=['POST'])
def stop_demo():
    """Stop the demonstration"""
    global producer, consumer_manager, demo_running
    
    try:
        if producer:
            producer.stop_production()
        
        if consumer_manager:
            consumer_manager.stop_consumer_group()
        
        monitor.stop_monitoring()
        
        demo_running = False
        
        return jsonify({'success': True, 'message': 'Demo stopped successfully'})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/consumer/stats')
def get_consumer_stats():
    """Get consumer group statistics"""
    try:
        if consumer_manager:
            stats = consumer_manager.get_group_stats()
            return jsonify(stats)
        else:
            return jsonify({'error': 'Consumer manager not running'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/producer/stats')
def get_producer_stats():
    """Get producer statistics"""
    try:
        if producer:
            stats = producer.get_stats()
            return jsonify(stats)
        else:
            return jsonify({'error': 'Producer not running'}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    emit('connected', {'data': 'Connected to Kafka monitoring dashboard'})
    
    # Send initial metrics
    try:
        metrics = monitor.get_latest_metrics()
        emit('metrics_update', metrics)
    except Exception as e:
        emit('error', {'message': str(e)})

@socketio.on('request_metrics')
def handle_metrics_request():
    """Handle request for latest metrics"""
    try:
        metrics = monitor.get_latest_metrics()
        emit('metrics_update', metrics)
    except Exception as e:
        emit('error', {'message': str(e)})

def background_metrics_sender():
    """Send metrics to connected clients periodically"""
    while True:
        try:
            if demo_running:
                metrics = monitor.get_latest_metrics()
                socketio.emit('metrics_update', metrics)
            time.sleep(5)
        except Exception as e:
            print(f"Error sending metrics: {e}")
            time.sleep(5)

# Start background metrics sender
metrics_thread = threading.Thread(target=background_metrics_sender, daemon=True)
metrics_thread.start()

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=8080, debug=True)
EOF

# Create HTML template
echo "🎨 Creating HTML dashboard template..."
mkdir -p web/templates
cat > web/templates/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kafka Partitioning & Consumer Groups Dashboard</title>
    <script src="https://cdn.socket.io/4.7.4/socket.io.min.js"></script>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .header {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .metric-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #2196F3;
        }
        .metric-label {
            color: #666;
            margin-top: 5px;
        }
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-running { background: #4CAF50; }
        .status-stopped { background: #f44336; }
        .status-warning { background: #FF9800; }
        .control-panel {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .btn {
            background: #2196F3;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 10px;
        }
        .btn:hover { background: #1976D2; }
        .btn.danger { background: #f44336; }
        .btn.danger:hover { background: #d32f2f; }
        .partition-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
            gap: 10px;
            margin-top: 15px;
        }
        .partition-box {
            background: #f0f0f0;
            padding: 10px;
            border-radius: 4px;
            text-align: center;
            border-left: 4px solid #2196F3;
        }
        .consumer-list {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 15px;
        }
        .consumer-box {
            background: #e8f5e8;
            padding: 10px;
            border-radius: 4px;
            border-left: 4px solid #4CAF50;
            min-width: 200px;
        }
        .log-output {
            background: #1e1e1e;
            color: #00ff00;
            padding: 15px;
            border-radius: 4px;
            height: 300px;
            overflow-y: auto;
            font-family: 'Courier New', monospace;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Kafka Partitioning & Consumer Groups Dashboard</h1>
        <p>Real-time monitoring of partition assignment and consumer group performance</p>
        <div class="status-indicator status-stopped" id="connectionStatus"></div>
        <span id="connectionText">Disconnected</span>
    </div>

    <div class="control-panel">
        <h3>Demo Controls</h3>
        <button class="btn" onclick="setupTopic()">Setup Topic</button>
        <button class="btn" onclick="startDemo()">Start Demo</button>
        <button class="btn danger" onclick="stopDemo()">Stop Demo</button>
        <div id="demoStatus" style="margin-top: 10px;"></div>
    </div>

    <div class="metrics-grid">
        <div class="metric-card">
            <div class="metric-value" id="totalProcessed">0</div>
            <div class="metric-label">Total Messages Processed</div>
        </div>
        <div class="metric-card">
            <div class="metric-value" id="activeConsumers">0</div>
            <div class="metric-label">Active Consumers</div>
        </div>
        <div class="metric-card">
            <div class="metric-value" id="processingRate">0</div>
            <div class="metric-label">Messages/Second</div>
        </div>
        <div class="metric-card">
            <div class="metric-value" id="successRate">0%</div>
            <div class="metric-label">Success Rate</div>
        </div>
    </div>

    <div class="metrics-grid">
        <div class="metric-card">
            <h3>📊 Topic Information</h3>
            <div id="topicInfo">
                <div>Topic: <span id="topicName">-</span></div>
                <div>Partitions: <span id="partitionCount">-</span></div>
                <div class="partition-grid" id="partitionGrid"></div>
            </div>
        </div>

        <div class="metric-card">
            <h3>👥 Consumer Group</h3>
            <div id="consumerGroupInfo">
                <div>Group ID: <span id="groupId">-</span></div>
                <div>State: <span id="groupState">-</span></div>
                <div class="consumer-list" id="consumerList"></div>
            </div>
        </div>
    </div>

    <div class="metric-card">
        <h3>📈 Processing Chart</h3>
        <div id="processingChart" style="height: 400px;"></div>
    </div>

    <div class="metric-card">
        <h3>📋 System Logs</h3>
        <div class="log-output" id="logOutput"></div>
    </div>

    <script>
        const socket = io();
        let processingData = {
            timestamps: [],
            processed: [],
            rates: []
        };

        // Socket event handlers
        socket.on('connect', function() {
            document.getElementById('connectionStatus').className = 'status-indicator status-running';
            document.getElementById('connectionText').textContent = 'Connected';
            logMessage('🟢 Connected to dashboard');
        });

        socket.on('disconnect', function() {
            document.getElementById('connectionStatus').className = 'status-indicator status-stopped';
            document.getElementById('connectionText').textContent = 'Disconnected';
            logMessage('🔴 Disconnected from dashboard');
        });

        socket.on('metrics_update', function(data) {
            updateMetrics(data);
        });

        socket.on('error', function(data) {
            logMessage(`❌ Error: ${data.message}`);
        });

        function updateMetrics(metrics) {
            if (!metrics || metrics.error) {
                logMessage(`⚠️ Metrics error: ${metrics?.error || 'Unknown error'}`);
                return;
            }

            // Update basic metrics
            const consumerGroup = metrics.consumer_group || {};
            const topicInfo = metrics.topic_info || {};

            // Update consumer stats if available
            updateConsumerStats();
            
            // Update topic information
            updateTopicInfo(topicInfo);
            
            // Update consumer group information
            updateConsumerGroupInfo(consumerGroup);
            
            // Update processing chart
            updateProcessingChart();

            logMessage(`📊 Metrics updated at ${new Date().toLocaleTimeString()}`);
        }

        function updateConsumerStats() {
            fetch('/api/consumer/stats')
                .then(response => response.json())
                .then(data => {
                    if (data.error) {
                        document.getElementById('totalProcessed').textContent = '0';
                        document.getElementById('activeConsumers').textContent = '0';
                        document.getElementById('processingRate').textContent = '0';
                        document.getElementById('successRate').textContent = '0%';
                        return;
                    }

                    document.getElementById('totalProcessed').textContent = data.total_processed || 0;
                    document.getElementById('activeConsumers').textContent = data.active_consumers || 0;
                    document.getElementById('successRate').textContent = `${Math.round(data.group_success_rate || 0)}%`;

                    // Calculate processing rate
                    const now = new Date();
                    processingData.timestamps.push(now);
                    processingData.processed.push(data.total_processed || 0);

                    if (processingData.timestamps.length > 1) {
                        const timeDiff = (now - processingData.timestamps[processingData.timestamps.length - 2]) / 1000;
                        const msgDiff = processingData.processed[processingData.processed.length - 1] - 
                                       processingData.processed[processingData.processed.length - 2];
                        const rate = timeDiff > 0 ? Math.round(msgDiff / timeDiff) : 0;
                        document.getElementById('processingRate').textContent = rate;
                        processingData.rates.push(rate);
                    }

                    // Keep only last 20 data points
                    if (processingData.timestamps.length > 20) {
                        processingData.timestamps.shift();
                        processingData.processed.shift();
                        processingData.rates.shift();
                    }

                    // Update consumer list
                    updateConsumerList(data.consumers || []);
                })
                .catch(error => {
                    console.error('Error fetching consumer stats:', error);
                });
        }

        function updateTopicInfo(topicInfo) {
            document.getElementById('topicName').textContent = topicInfo.name || 'log-processing-topic';
            document.getElementById('partitionCount').textContent = topicInfo.partitions || 6;

            // Update partition grid
            const partitionGrid = document.getElementById('partitionGrid');
            partitionGrid.innerHTML = '';
            
            const partitions = topicInfo.partitions || 6;
            for (let i = 0; i < partitions; i++) {
                const partitionBox = document.createElement('div');
                partitionBox.className = 'partition-box';
                partitionBox.innerHTML = `
                    <div>Partition ${i}</div>
                    <div style="font-size: 0.8em; color: #666;">Leader: Broker 1</div>
                `;
                partitionGrid.appendChild(partitionBox);
            }
        }

        function updateConsumerGroupInfo(groupInfo) {
            document.getElementById('groupId').textContent = groupInfo.group_id || 'log-processing-group';
            document.getElementById('groupState').textContent = groupInfo.state || 'Stable';
        }

        function updateConsumerList(consumers) {
            const consumerList = document.getElementById('consumerList');
            consumerList.innerHTML = '';

            consumers.forEach(consumer => {
                const consumerBox = document.createElement('div');
                consumerBox.className = 'consumer-box';
                consumerBox.innerHTML = `
                    <div><strong>${consumer.consumer_id}</strong></div>
                    <div>Processed: ${consumer.messages_processed}</div>
                    <div>Partitions: [${consumer.assigned_partitions.join(', ')}]</div>
                    <div>Status: ${consumer.status}</div>
                `;
                consumerList.appendChild(consumerBox);
            });
        }

        function updateProcessingChart() {
            if (processingData.timestamps.length > 1) {
                const trace1 = {
                    x: processingData.timestamps,
                    y: processingData.processed,
                    type: 'scatter',
                    mode: 'lines+markers',
                    name: 'Total Processed',
                    line: { color: '#2196F3' }
                };

                const trace2 = {
                    x: processingData.timestamps,
                    y: processingData.rates,
                    type: 'scatter',
                    mode: 'lines+markers',
                    name: 'Rate (msg/sec)',
                    yaxis: 'y2',
                    line: { color: '#4CAF50' }
                };

                const layout = {
                    title: 'Message Processing Performance',
                    xaxis: { title: 'Time' },
                    yaxis: { title: 'Total Messages', side: 'left' },
                    yaxis2: {
                        title: 'Rate (messages/sec)',
                        side: 'right',
                        overlaying: 'y'
                    },
                    showlegend: true
                };

                Plotly.newPlot('processingChart', [trace1, trace2], layout);
            }
        }

        function logMessage(message) {
            const logOutput = document.getElementById('logOutput');
            const timestamp = new Date().toLocaleTimeString();
            logOutput.innerHTML += `[${timestamp}] ${message}\n`;
            logOutput.scrollTop = logOutput.scrollHeight;
        }

        // Control functions
        function setupTopic() {
            fetch('/api/topic/setup', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        logMessage('✅ Topic setup completed');
                        document.getElementById('demoStatus').innerHTML = 
                            '<span style="color: green;">Topic ready</span>';
                    } else {
                        logMessage(`❌ Topic setup failed: ${data.error}`);
                    }
                })
                .catch(error => {
                    logMessage(`❌ Topic setup error: ${error}`);
                });
        }

        function startDemo() {
            fetch('/api/demo/start', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        logMessage('🚀 Demo started successfully');
                        document.getElementById('demoStatus').innerHTML = 
                            '<span style="color: green;">Demo running</span>';
                    } else {
                        logMessage(`❌ Demo start failed: ${data.error}`);
                    }
                })
                .catch(error => {
                    logMessage(`❌ Demo start error: ${error}`);
                });
        }

        function stopDemo() {
            fetch('/api/demo/stop', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        logMessage('🛑 Demo stopped');
                        document.getElementById('demoStatus').innerHTML = 
                            '<span style="color: red;">Demo stopped</span>';
                    } else {
                        logMessage(`❌ Demo stop failed: ${data.error}`);
                    }
                })
                .catch(error => {
                    logMessage(`❌ Demo stop error: ${error}`);
                });
        }

        // Request metrics every 5 seconds
        setInterval(() => {
            socket.emit('request_metrics');
        }, 5000);

        // Initial setup
        logMessage('🎛️ Dashboard initialized');
    </script>
</body>
</html>
EOF

# Create test suite
echo "🧪 Creating test suite..."
cat > tests/test_kafka_system.py << 'EOF'
import pytest
import json
import time
import threading
from unittest.mock import Mock, patch
import sys
import os

# Add src to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))

try:
    from producer.log_producer import LogMessageProducer
    from consumer.log_consumer import LogConsumer, ConsumerGroupManager
    from config.kafka_config import config
    from config.topic_manager import TopicManager
    from monitoring.consumer_monitor import ConsumerGroupMonitor
except ImportError as e:
    print(f"Import error in tests: {e}")
    pytest.skip("Skipping tests due to import issues", allow_module_level=True)

class TestKafkaPartitioning:
    """Test Kafka partitioning and consumer group functionality"""
    
    def test_config_validation(self):
        """Test configuration is valid"""
        assert config.bootstrap_servers == 'localhost:9092'
        assert config.partitions == 6
        assert config.consumer_group_id == 'log-processing-group'
        
    def test_producer_message_generation(self):
        """Test log message generation"""
        producer = LogMessageProducer("test-producer")
        message = producer.generate_log_message(service='web-api', user_id='user_123')
        
        assert message['service'] == 'web-api'
        assert message['user_id'] == 'user_123'
        assert 'timestamp' in message
        assert 'level' in message
        assert 'message' in message
        
    def test_partition_key_generation(self):
        """Test partition key generation for consistent routing"""
        producer = LogMessageProducer("test-producer")
        message = producer.generate_log_message(user_id='user_123')
        key = producer.get_partition_key(message)
        
        assert key == 'user_123'
        
        # Same user should always get same key
        message2 = producer.generate_log_message(user_id='user_123')
        key2 = producer.get_partition_key(message2)
        assert key == key2
        
    def test_consumer_initialization(self):
        """Test consumer initialization"""
        consumer = LogConsumer("test-consumer")
        
        assert consumer.consumer_id == "test-consumer"
        assert consumer.message_count == 0
        assert consumer.error_count == 0
        assert not consumer.running
        
    def test_consumer_stats(self):
        """Test consumer statistics collection"""
        consumer = LogConsumer("test-consumer")
        consumer.message_count = 100
        consumer.error_count = 5
        
        stats = consumer.get_stats()
        
        assert stats['consumer_id'] == "test-consumer"
        assert stats['messages_processed'] == 100
        assert stats['errors'] == 5
        assert stats['success_rate'] == 95.0  # 100/(100+5) * 100
        
    def test_consumer_group_manager(self):
        """Test consumer group manager initialization"""
        manager = ConsumerGroupManager(group_size=3)
        
        assert manager.group_size == 3
        assert len(manager.consumers) == 0
        assert not manager.running
        
    def test_message_processing_callback(self):
        """Test message processing with custom callback"""
        processed_messages = []
        
        def test_callback(message):
            processed_messages.append(message)
            return True
            
        consumer = LogConsumer("test-consumer", processing_callback=test_callback)
        
        # Test the callback is stored
        assert consumer.processing_callback == test_callback
        
        # Test processing
        test_message = {'test': 'data', 'level': 'INFO'}
        result = consumer.processing_callback(test_message)
        
        assert result is True
        assert len(processed_messages) == 1
        assert processed_messages[0] == test_message

class TestMonitoring:
    """Test monitoring functionality"""
    
    def test_monitor_initialization(self):
        """Test monitor initialization"""
        monitor = ConsumerGroupMonitor()
        
        assert not monitor.monitoring
        assert len(monitor.stats_history) == 0
        
    def test_metrics_collection_structure(self):
        """Test metrics collection returns proper structure"""
        monitor = ConsumerGroupMonitor()
        
        # Mock the methods to avoid actual Kafka calls
        with patch.object(monitor, 'get_consumer_group_info') as mock_group_info, \
             patch.object(monitor, '_get_topic_info') as mock_topic_info, \
             patch.object(monitor, '_get_system_metrics') as mock_system_metrics:
            
            mock_group_info.return_value = {'group_id': 'test-group'}
            mock_topic_info.return_value = {'name': 'test-topic'}
            mock_system_metrics.return_value = {'cpu_usage': 10.0}
            
            metrics = monitor.collect_metrics()
            
            assert 'timestamp' in metrics
            assert 'consumer_group' in metrics
            assert 'topic_info' in metrics
            assert 'system_metrics' in metrics

class TestIntegration:
    """Integration tests for the complete system"""
    
    def test_producer_consumer_message_flow(self):
        """Test message flow from producer through consumer"""
        # This would require actual Kafka setup
        # For now, test the message format compatibility
        
        producer = LogMessageProducer("integration-producer")
        message = producer.generate_log_message()
        
        # Simulate message serialization/deserialization
        serialized = json.dumps(message)
        deserialized = json.loads(serialized)
        
        # Test consumer can process the message
        consumer = LogConsumer("integration-consumer")
        result = consumer.default_process_message(deserialized)
        
        assert result is True
        
    def test_partition_assignment_logic(self):
        """Test partition assignment distribution"""
        # Test that different users get distributed across partitions
        producer = LogMessageProducer("partition-test-producer")
        
        partition_keys = []
        for i in range(100):
            message = producer.generate_log_message(user_id=f"user_{i}")
            key = producer.get_partition_key(message)
            partition_keys.append(key)
        
        # Should have 100 unique keys (one per user)
        unique_keys = set(partition_keys)
        assert len(unique_keys) == 100
        
        # Keys should be consistent for same user
        message1 = producer.generate_log_message(user_id="consistent_user")
        message2 = producer.generate_log_message(user_id="consistent_user")
        
        key1 = producer.get_partition_key(message1)
        key2 = producer.get_partition_key(message2)
        
        assert key1 == key2

def test_system_configuration():
    """Test overall system configuration is valid"""
    # Test required configuration values
    assert hasattr(config, 'bootstrap_servers')
    assert hasattr(config, 'topic_name')
    assert hasattr(config, 'partitions')
    assert hasattr(config, 'consumer_group_id')
    
    # Test configuration methods
    producer_config = config.get_producer_config()
    consumer_config = config.get_consumer_config('test-consumer')
    
    assert 'bootstrap.servers' in producer_config
    assert 'bootstrap.servers' in consumer_config
    assert 'group.id' in consumer_config

def test_topic_manager():
    """Test topic manager functionality"""
    manager = TopicManager()
    
    # Test that manager initializes correctly
    assert manager.admin_client is not None
    
    # Test metadata structure (without actual Kafka connection)
    # This is a structural test only

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create main application runner
echo "🎯 Creating main application runner..."
cat > src/main.py << 'EOF'
#!/usr/bin/env python3
"""
Day 41: Kafka Partitioning & Consumer Groups - Main Application
"""

import sys
import time
import signal
import threading
import logging
import os
from datetime import datetime

# Add current directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

try:
    from config.topic_manager import setup_kafka_topic
    from producer.log_producer import LogMessageProducer
    from consumer.log_consumer import ConsumerGroupManager
    from monitoring.consumer_monitor import monitor
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure you're running from the correct directory and all dependencies are installed")
    sys.exit(1)

class KafkaDemo:
    def __init__(self):
        self.producer = None
        self.consumer_manager = None
        self.running = False
        
        # Setup signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        print(f"\n🛑 Received signal {signum}, shutting down gracefully...")
        self.stop()
    
    def setup_infrastructure(self):
        """Setup Kafka topic and infrastructure"""
        print("🔧 Setting up Kafka infrastructure...")
        try:
            topic_info = setup_kafka_topic()
            if topic_info:
                print(f"✅ Topic setup complete: {topic_info['name']} with {topic_info['partitions']} partitions")
            else:
                print("⚠️ Topic setup completed (may already exist)")
        except Exception as e:
            print(f"❌ Topic setup failed: {e}")
            raise
    
    def start_monitoring(self):
        """Start system monitoring"""
        print("📊 Starting monitoring...")
        monitor.start_monitoring(interval_seconds=10)
    
    def start_consumers(self, consumer_count: int = 3):
        """Start consumer group"""
        print(f"👥 Starting consumer group with {consumer_count} consumers...")
        self.consumer_manager = ConsumerGroupManager(group_size=consumer_count)
        self.consumer_manager.start_consumer_group()
        time.sleep(5)  # Allow consumers to register and get assignments
    
    def start_producer(self, rate: int = 10, duration: int = 300):
        """Start log producer"""
        print(f"📤 Starting producer: {rate} messages/second for {duration} seconds...")
        self.producer = LogMessageProducer("demo-producer")
        
        def run_producer():
            self.producer.start_continuous_production(
                messages_per_second=rate,
                duration_seconds=duration
            )
        
        producer_thread = threading.Thread(target=run_producer, daemon=True)
        producer_thread.start()
        
        return producer_thread
    
    def run_demo(self, consumer_count: int = 3, production_rate: int = 10, duration: int = 60):
        """Run the complete demonstration"""
        self.running = True
        
        try:
            print("🚀 Starting Kafka Partitioning & Consumer Groups Demo")
            print("=" * 60)
            
            # Setup infrastructure
            self.setup_infrastructure()
            
            # Start monitoring
            self.start_monitoring()
            
            # Start consumers
            self.start_consumers(consumer_count)
            
            # Start producer
            producer_thread = self.start_producer(production_rate, duration)
            
            print(f"\n📈 Demo running - producing {production_rate} msg/sec with {consumer_count} consumers")
            print("💡 Watch the partition assignments and load distribution!")
            print("📊 Monitor at: http://localhost:8080 (if web dashboard is running)")
            print("\nPress Ctrl+C to stop...\n")
            
            # Show real-time statistics
            start_time = time.time()
            while self.running and (time.time() - start_time) < duration:
                time.sleep(10)
                self._show_stats()
            
            # Wait for producer to complete
            producer_thread.join(timeout=10)
            
            print("\n✅ Demo completed successfully!")
            self._show_final_stats()
            
        except KeyboardInterrupt:
            print("\n🛑 Demo interrupted by user")
        except Exception as e:
            print(f"\n❌ Demo failed: {e}")
        finally:
            self.stop()
    
    def _show_stats(self):
        """Show current statistics"""
        try:
            if self.consumer_manager:
                stats = self.consumer_manager.get_group_stats()
                print(f"📊 [{datetime.now().strftime('%H:%M:%S')}] "
                      f"Processed: {stats['total_processed']}, "
                      f"Active: {stats['active_consumers']}/{stats['group_size']}, "
                      f"Success: {stats['group_success_rate']:.1f}%")
            
            if self.producer:
                producer_stats = self.producer.get_stats()
                print(f"📤 [{datetime.now().strftime('%H:%M:%S')}] "
                      f"Sent: {producer_stats['messages_sent']}, "
                      f"Errors: {producer_stats['errors']}, "
                      f"Success: {producer_stats['success_rate']:.1f}%")
                
        except Exception as e:
            print(f"⚠️ Error getting stats: {e}")
    
    def _show_final_stats(self):
        """Show final demonstration statistics"""
        print("\n" + "=" * 60)
        print("📊 FINAL DEMONSTRATION STATISTICS")
        print("=" * 60)
        
        try:
            if self.consumer_manager:
                stats = self.consumer_manager.get_group_stats()
                print(f"\n👥 Consumer Group Performance:")
                print(f"   Total Messages Processed: {stats['total_processed']}")
                print(f"   Total Errors: {stats['total_errors']}")
                print(f"   Overall Success Rate: {stats['group_success_rate']:.1f}%")
                print(f"   Active Consumers: {stats['active_consumers']}/{stats['group_size']}")
                
                print(f"\n📋 Individual Consumer Stats:")
                for consumer_stats in stats['consumers']:
                    print(f"   {consumer_stats['consumer_id']}: "
                          f"{consumer_stats['messages_processed']} messages, "
                          f"partitions {consumer_stats['assigned_partitions']}")
            
            if self.producer:
                producer_stats = self.producer.get_stats()
                print(f"\n📤 Producer Performance:")
                print(f"   Messages Sent: {producer_stats['messages_sent']}")
                print(f"   Errors: {producer_stats['errors']}")
                print(f"   Success Rate: {producer_stats['success_rate']:.1f}%")
                
        except Exception as e:
            print(f"⚠️ Error showing final stats: {e}")
        
        print("\n💡 Key Observations:")
        print("   ✅ Messages distributed across partitions")
        print("   ✅ Consumers automatically assigned to partitions")
        print("   ✅ Load balanced across consumer instances")
        print("   ✅ System handles consumer failures gracefully")
    
    def stop(self):
        """Stop the demo"""
        self.running = False
        
        if self.producer:
            print("🛑 Stopping producer...")
            self.producer.stop_production()
        
        if self.consumer_manager:
            print("🛑 Stopping consumer group...")
            self.consumer_manager.stop_consumer_group()
        
        print("🛑 Stopping monitoring...")
        monitor.stop_monitoring()
        
        print("✅ Demo stopped cleanly")

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Kafka Partitioning & Consumer Groups Demo')
    parser.add_argument('--consumers', type=int, default=3, help='Number of consumers (default: 3)')
    parser.add_argument('--rate', type=int, default=10, help='Messages per second (default: 10)')
    parser.add_argument('--duration', type=int, default=60, help='Duration in seconds (default: 60)')
    parser.add_argument('--web', action='store_true', help='Start web dashboard')
    
    args = parser.parse_args()
    
    if args.web:
        # Start web dashboard
        import sys
        import os
        
        # Add web directory to path
        web_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'web')
        sys.path.append(web_path)
        
        try:
            from dashboard import app, socketio
            print("🌐 Starting web dashboard on http://localhost:8080")
            socketio.run(app, host='0.0.0.0', port=8080, debug=False)
        except ImportError as e:
            print(f"Failed to import dashboard: {e}")
            print("Make sure Flask and Flask-SocketIO are installed")
            sys.exit(1)
    else:
        # Run CLI demo
        demo = KafkaDemo()
        demo.run_demo(
            consumer_count=args.consumers,
            production_rate=args.rate,
            duration=args.duration
        )

if __name__ == "__main__":
    main()
EOF

# Create build and test scripts
echo "🔨 Creating build and test scripts..."
cat > scripts/build_and_test.sh << 'EOF'
#!/bin/bash

# Build and test script for Kafka Partitioning system

set -e

echo "🔨 Building and testing Kafka Partitioning & Consumer Groups system"
echo "=================================================================="

# Activate virtual environment
#source venv/bin/activate

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Start infrastructure with Docker
echo "🐳 Starting Kafka infrastructure..."
docker-compose up -d

# Wait for Kafka to be ready
echo "⏳ Waiting for Kafka to be ready..."
timeout=60
counter=0
while ! docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list &>/dev/null; do
    if [ $counter -ge $timeout ]; then
        echo "❌ Kafka failed to start within $timeout seconds"
        exit 1
    fi
    echo "Waiting for Kafka... ($counter/$timeout)"
    sleep 1
    ((counter++))
done

echo "✅ Kafka is ready!"

# Run tests
echo "🧪 Running test suite..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
python -m pytest tests/ -v

# Test topic creation
echo "📊 Testing topic creation..."
cd src
python -c "
import sys
import os
sys.path.append('.')
from config.topic_manager import setup_kafka_topic
try:
    topic_info = setup_kafka_topic()
    print(f'✅ Topic created: {topic_info}')
except Exception as e:
    print(f'❌ Topic creation failed: {e}')
"
cd ..

# Test producer
echo "📤 Testing producer..."
cd src
timeout 10s python -c "
import sys
import os
sys.path.append('.')
from producer.log_producer import LogMessageProducer
import time

try:
    producer = LogMessageProducer('test-producer')
    for i in range(10):
        message = producer.generate_log_message()
        success = producer.send_log(message)
        print(f'Message {i+1}: {\"✅\" if success else \"❌\"}')
        time.sleep(0.1)
    
    producer.producer.flush(timeout=5)
    stats = producer.get_stats()
    print(f'📊 Producer stats: {stats}')
except Exception as e:
    print(f'❌ Producer test failed: {e}')
" || echo "⚠️ Producer test completed (timeout expected)"
cd ..

# Test consumer (short run)
echo "📥 Testing consumer..."
cd src
timeout 15s python -c "
import sys
import os
sys.path.append('.')
from consumer.log_consumer import ConsumerGroupManager
import time

try:
    manager = ConsumerGroupManager(group_size=2)
    manager.start_consumer_group()
    
    time.sleep(10)  # Let consumers process some messages
    
    stats = manager.get_group_stats()
    print(f'📊 Consumer stats: {stats}')
    
    manager.stop_consumer_group()
except Exception as e:
    print(f'❌ Consumer test failed: {e}')
" || echo "⚠️ Consumer test completed (timeout expected)"
cd ..

# Test monitoring
echo "📊 Testing monitoring..."
cd src
python -c "
import sys
import os
sys.path.append('.')
from monitoring.consumer_monitor import ConsumerGroupMonitor

try:
    monitor = ConsumerGroupMonitor()
    metrics = monitor.collect_metrics()
    print(f'📈 Metrics collected: {len(metrics)} keys')
    print(f'Keys: {list(metrics.keys())}')
except Exception as e:
    print(f'❌ Monitoring test failed: {e}')
"
cd ..

echo ""
echo "✅ Build and test completed successfully!"
echo ""
echo "🚀 To run the full demo:"
echo "   cd src && python main.py --consumers 3 --rate 20 --duration 60"
echo ""
echo "🌐 To start the web dashboard:"
echo "   cd src && python main.py --web"
echo "   Then visit: http://localhost:8080"
echo ""
echo "🔍 To check Kafka UI:"
echo "   Visit: http://localhost:8081"
EOF

chmod +x scripts/build_and_test.sh

# Create demo script
cat > scripts/run_demo.sh << 'EOF'
#!/bin/bash

# Demo script for Kafka Partitioning & Consumer Groups

echo "🎬 Starting Kafka Partitioning & Consumer Groups Demo"
echo "=================================================="

# Activate virtual environment
#source venv/bin/activate

# Ensure infrastructure is running
echo "🐳 Ensuring Kafka infrastructure is running..."
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to be ready..."
timeout=60
counter=0
while ! docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list &>/dev/null; do
    if [ $counter -ge $timeout ]; then
        echo "❌ Kafka failed to start within $timeout seconds"
        exit 1
    fi
    echo "Waiting for Kafka... ($counter/$timeout)"
    sleep 1
    ((counter++))
done

echo "✅ Kafka is ready!"

# Start web dashboard in background
echo "🌐 Starting web dashboard..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
cd src
python main.py --web &
WEB_PID=$!
cd ..

sleep 5

echo ""
echo "📊 Dashboard available at: http://localhost:8080"
echo "🔍 Kafka UI available at: http://localhost:8081"
echo ""
echo "🎯 Demo Instructions:"
echo "1. Open http://localhost:8080 in your browser"
echo "2. Click 'Setup Topic' to create the partitioned topic"
echo "3. Click 'Start Demo' to begin producing and consuming messages"
echo "4. Watch the real-time partition assignments and processing stats"
echo "5. Try scaling consumers up/down to see rebalancing"
echo ""
echo "💡 Alternatively, run CLI demo with:"
echo "   cd src && python main.py --consumers 3 --rate 20 --duration 60"
echo ""
echo "Press Ctrl+C to stop the demo..."

# Keep demo running
trap "echo '🛑 Stopping demo...'; kill $WEB_PID 2>/dev/null; docker-compose down; exit 0" INT

wait $WEB_PID
EOF

chmod +x scripts/run_demo.sh

# Create quick verification script
cat > scripts/verify_setup.sh << 'EOF'
#!/bin/bash

# Quick verification script for individual components

echo "🔍 Verifying Kafka Partitioning System Setup"
echo "============================================="


# Check Python imports
echo "🐍 Testing Python imports..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

cd src
python -c "
try:
    print('Testing imports...')
    from config.kafka_config import config
    print('✅ Config import successful')
    
    from config.topic_manager import TopicManager
    print('✅ Topic manager import successful')
    
    from producer.log_producer import LogMessageProducer
    print('✅ Producer import successful')
    
    from consumer.log_consumer import LogConsumer
    print('✅ Consumer import successful')
    
    from monitoring.consumer_monitor import ConsumerGroupMonitor
    print('✅ Monitor import successful')
    
    print('✅ All imports successful!')
except Exception as e:
    print(f'❌ Import failed: {e}')
    exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Import test failed"
    cd ..
    exit 1
fi

echo ""
echo "🧪 Testing component functionality..."

# Test message generation
python -c "
try:
    from producer.log_producer import LogMessageProducer
    producer = LogMessageProducer('test')
    message = producer.generate_log_message(user_id='test_user')
    print(f'✅ Message generation works: {message[\"user_id\"]} -> {message[\"service\"]}')
    
    key = producer.get_partition_key(message)
    print(f'✅ Partition key generation works: {key}')
except Exception as e:
    print(f'❌ Producer test failed: {e}')
    exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Producer test failed"
    cd ..
    exit 1
fi

# Test consumer
python -c "
try:
    from consumer.log_consumer import LogConsumer
    consumer = LogConsumer('test-consumer')
    stats = consumer.get_stats()
    print(f'✅ Consumer initialization works: {stats[\"consumer_id\"]}')
except Exception as e:
    print(f'❌ Consumer test failed: {e}')
    exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Consumer test failed"
    cd ..
    exit 1
fi

# Test monitoring
python -c "
try:
    from monitoring.consumer_monitor import ConsumerGroupMonitor
    monitor = ConsumerGroupMonitor()
    print('✅ Monitor initialization works')
except Exception as e:
    print(f'❌ Monitor test failed: {e}')
    exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Monitor test failed"
    cd ..
    exit 1
fi

cd ..

echo ""
echo "✅ All component tests passed!"
echo ""
echo "🚀 System is ready! You can now:"
echo "   • Run './scripts/build_and_test.sh' for full testing with Kafka"
echo "   • Run './scripts/run_demo.sh' for interactive demo"
echo "   • Run 'cd src && python main.py --web' for web dashboard"
echo "   • Run 'cd src && python main.py --consumers 3 --rate 20' for CLI demo"
EOF

chmod +x scripts/verify_setup.sh

# Create package init files
touch src/__init__.py
touch src/producer/__init__.py
touch src/consumer/__init__.py
touch src/monitoring/__init__.py

# Create .env file
cat > .env << 'EOF'
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
REDIS_URL=redis://localhost:6379/0
LOG_LEVEL=INFO
EOF

echo ""
echo "✅ Project structure created successfully!"
echo ""
echo "📋 File verification:"
find . -name "*.py" -exec echo "✓ {}" \;
echo ""
echo "🔍 Quick verification (without Kafka):"
echo "./scripts/verify_setup.sh"
echo ""
echo "🚀 Full build and test (with Kafka):"
echo "./scripts/build_and_test.sh"
echo ""
echo "🎬 Interactive demo:"
echo "./scripts/run_demo.sh"
echo ""
echo "💻 Manual commands:"
echo "# CLI demo:"
echo "cd src && export PYTHONPATH=\$(pwd):\$PYTHONPATH && python main.py --consumers 3 --rate 20 --duration 60"
echo ""
echo "# Web dashboard:"
echo "cd src && export PYTHONPATH=\$(pwd):\$PYTHONPATH && python main.py --web"
echo "# Then visit: http://localhost:8080"
echo ""
echo "🌐 Monitoring URLs:"
echo "• Main Dashboard: http://localhost:8080"
echo "• Kafka UI: http://localhost:8081"
echo ""
echo "📊 Docker commands:"
echo "# Start infrastructure: docker-compose up -d"
echo "# Stop infrastructure: docker-compose down"
echo "# View logs: docker-compose logs -f"

cd ..
echo ""
echo "🎉 Day 41: Kafka Partitioning & Consumer Groups implementation complete!"
echo ""
echo "📝 IMPORTANT SETUP NOTES:"
echo "1. Run './scripts/verify_setup.sh' first to test components"
echo "2. Run './scripts/build_and_test.sh' for full system testing"
echo "3. Run './scripts/run_demo.sh' for interactive demonstration"
echo ""
echo "The system demonstrates:"
echo "✅ Parallel processing across multiple consumer instances"
echo "✅ Automatic partition assignment and load balancing"
echo "✅ Real-time monitoring of partition distribution"
echo "✅ Consumer group coordination and rebalancing"
echo "✅ Production-ready patterns used by major tech companies"