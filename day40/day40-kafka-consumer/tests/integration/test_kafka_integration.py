import pytest
import json
import time
import threading
from confluent_kafka import Producer
from src.config.kafka_config import KafkaConsumerConfig
from src.consumer.kafka_consumer import KafkaLogConsumer

@pytest.mark.integration
class TestKafkaIntegration:
    @pytest.fixture
    def producer(self):
        """Create Kafka producer for testing"""
        return Producer({'bootstrap.servers': 'localhost:9092'})
        
    @pytest.fixture  
    def consumer_config(self):
        """Create test consumer configuration"""
        config = KafkaConsumerConfig()
        config.group_id = 'test-group'
        config.topics = ['test-logs']
        config.consumer_timeout_ms = 5000
        return config
        
    def test_message_consumption(self, producer, consumer_config):
        """Test end-to-end message consumption"""
        # Send test message
        test_message = {
            'type': 'web_access',
            'endpoint': '/api/test',
            'status_code': 200,
            'response_time': 50,
            'timestamp': time.time()
        }
        
        producer.produce(
            topic='test-logs',
            key='test',
            value=json.dumps(test_message)
        )
        producer.flush()
        
        # Create and start consumer
        consumer = KafkaLogConsumer(consumer_config)
        
        # Run consumer in thread for limited time
        def run_consumer():
            consumer.start()
            
        consumer_thread = threading.Thread(target=run_consumer)
        consumer_thread.daemon = True
        consumer_thread.start()
        
        # Wait for processing
        time.sleep(10)
        consumer.stop()
        
        # Verify message was processed
        assert consumer.processed_count > 0
        
    def test_batch_processing(self, producer, consumer_config):
        """Test batch message processing"""
        # Send multiple messages
        for i in range(10):
            test_message = {
                'type': 'application',
                'level': 'INFO',
                'service': 'test-service',
                'message': f'Test message {i}',
                'timestamp': time.time()
            }
            
            producer.produce(
                topic='test-logs',
                key=f'test-{i}',
                value=json.dumps(test_message)
            )
        
        producer.flush()
        
        # Process with consumer
        consumer = KafkaLogConsumer(consumer_config)
        
        def run_consumer():
            consumer.start()
            
        consumer_thread = threading.Thread(target=run_consumer)
        consumer_thread.daemon = True
        consumer_thread.start()
        
        # Wait for batch processing
        time.sleep(15)
        consumer.stop()
        
        # Verify batch processing
        assert consumer.processed_count >= 10
        stats = consumer.metrics.get_current_metrics()
        assert stats['total_batches'] > 0
