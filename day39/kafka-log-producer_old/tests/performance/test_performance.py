import pytest
import time
import asyncio
from unittest.mock import Mock, patch
from src.producer.kafka_producer import KafkaLogProducer
from src.utils.log_generator import LogGenerator
from src.monitoring.producer_metrics import ProducerMetrics

@pytest.fixture(autouse=True)
def clear_metrics_registry():
    """Clear metrics registry before each test"""
    ProducerMetrics.clear_registry()
    yield
    ProducerMetrics.clear_registry()

@pytest.mark.asyncio
async def test_throughput_performance():
    """Test producer throughput performance"""
    
    with patch('src.producer.kafka_producer.Producer') as mock_kafka_producer, \
         patch('src.producer.kafka_producer.AdminClient') as mock_admin:
        
        # Setup mocks
        producer_instance = Mock()
        mock_kafka_producer.return_value = producer_instance
        producer_instance.produce.return_value = None
        producer_instance.poll.return_value = None
        producer_instance.flush.return_value = 0
        
        admin_instance = Mock()
        mock_admin.return_value = admin_instance
        admin_instance.create_topics.return_value = {}
        
        # Create producer and generator
        producer = KafkaLogProducer("config/producer_config.yaml")
        generator = LogGenerator()
        
        # Performance test parameters
        num_messages = 1000
        start_time = time.time()
        
        # Generate and send logs
        logs = generator.generate_batch(num_messages, 1)
        
        successful_sends = 0
        for log in logs:
            if producer.send_log(log):
                successful_sends += 1
                
        # Flush remaining messages
        producer.flush()
        
        elapsed_time = time.time() - start_time
        throughput = successful_sends / elapsed_time
        
        # Performance assertions
        assert successful_sends == num_messages
        assert throughput > 100  # Should handle >100 messages/second
        assert elapsed_time < 30  # Should complete within 30 seconds
        
        print(f"Throughput: {throughput:.1f} messages/second")
        print(f"Total time: {elapsed_time:.2f} seconds")

def test_batch_performance():
    """Test batch sending performance"""
    
    with patch('src.producer.kafka_producer.Producer') as mock_kafka_producer, \
         patch('src.producer.kafka_producer.AdminClient') as mock_admin:
        
        # Setup mocks
        producer_instance = Mock()
        mock_kafka_producer.return_value = producer_instance
        producer_instance.produce.return_value = None
        producer_instance.poll.return_value = None
        
        admin_instance = Mock()
        mock_admin.return_value = admin_instance
        admin_instance.create_topics.return_value = {}
        
        # Create producer and generator
        producer = KafkaLogProducer("config/producer_config.yaml")
        generator = LogGenerator()
        
        # Test different batch sizes
        batch_sizes = [1, 10, 50, 100]
        
        for batch_size in batch_sizes:
            logs = generator.generate_batch(batch_size, 1)
            
            start_time = time.time()
            results = producer.send_logs_batch(logs)
            elapsed_time = time.time() - start_time
            
            assert results['sent'] == batch_size
            assert results['failed'] == 0
            
            throughput = batch_size / elapsed_time
            print(f"Batch size {batch_size}: {throughput:.1f} messages/second")

def test_memory_usage():
    """Test memory usage doesn't grow excessively"""
    import psutil
    import gc
    
    with patch('src.producer.kafka_producer.Producer') as mock_kafka_producer, \
         patch('src.producer.kafka_producer.AdminClient') as mock_admin:
        
        # Setup mocks
        producer_instance = Mock()
        mock_kafka_producer.return_value = producer_instance
        producer_instance.produce.return_value = None
        producer_instance.poll.return_value = None
        
        admin_instance = Mock()
        mock_admin.return_value = admin_instance
        admin_instance.create_topics.return_value = {}
        
        # Create producer and generator
        producer = KafkaLogProducer("config/producer_config.yaml")
        generator = LogGenerator()
        
        # Measure initial memory
        process = psutil.Process()
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        # Send many logs
        for _ in range(10):
            logs = generator.generate_batch(100, 1)
            producer.send_logs_batch(logs)
            gc.collect()  # Force garbage collection
        
        # Measure final memory
        final_memory = process.memory_info().rss / 1024 / 1024  # MB
        memory_growth = final_memory - initial_memory
        
        print(f"Initial memory: {initial_memory:.1f} MB")
        print(f"Final memory: {final_memory:.1f} MB")
        print(f"Memory growth: {memory_growth:.1f} MB")
        
        # Memory growth should be reasonable
        assert memory_growth < 100  # Less than 100MB growth
