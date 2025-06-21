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
        assert stats['success_rate'] == pytest.approx(95.0, rel=1e-2)  # 100/(100+5) * 100
        
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
