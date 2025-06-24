import pytest
import time
from unittest.mock import Mock, patch
from src.producer.kafka_producer import KafkaLogProducer
from src.models.log_entry import LogEntry, LogLevel
from src.utils.log_generator import LogGenerator

@pytest.fixture
def mock_producer():
    """Create a mock producer for testing"""
    with patch('src.producer.kafka_producer.Producer') as mock_kafka_producer, \
         patch('src.producer.kafka_producer.AdminClient') as mock_admin:
        
        # Mock the Kafka producer
        producer_instance = Mock()
        mock_kafka_producer.return_value = producer_instance
        
        # Mock admin client
        admin_instance = Mock()
        mock_admin.return_value = admin_instance
        admin_instance.create_topics.return_value = {}
        
        # Create producer with mocked dependencies
        producer = KafkaLogProducer("config/producer_config.yaml")
        
        yield producer, producer_instance

def test_producer_initialization(mock_producer):
    """Test producer initialization"""
    producer, kafka_instance = mock_producer
    
    assert producer.producer is not None
    assert producer.metrics is not None
    assert producer.config is not None

def test_send_single_log(mock_producer):
    """Test sending a single log entry"""
    producer, kafka_instance = mock_producer
    
    log = LogEntry(
        level=LogLevel.INFO,
        message="Test log",
        service="test-service"
    )
    
    # Mock successful send
    kafka_instance.produce.return_value = None
    
    result = producer.send_log(log)
    
    assert result is True
    kafka_instance.produce.assert_called_once()
    
    # Verify the call arguments
    call_args = kafka_instance.produce.call_args
    assert call_args[1]['topic'] == 'logs-application'
    assert call_args[1]['key'] == b'test-service'

def test_send_batch_logs(mock_producer):
    """Test sending a batch of logs"""
    producer, kafka_instance = mock_producer
    
    generator = LogGenerator()
    logs = generator.generate_batch(5, 1)
    
    # Mock successful sends
    kafka_instance.produce.return_value = None
    kafka_instance.poll.return_value = None
    
    results = producer.send_logs_batch(logs)
    
    assert results['sent'] == 5
    assert results['failed'] == 0
    assert kafka_instance.produce.call_count == 5

def test_producer_error_handling(mock_producer):
    """Test error handling in producer"""
    producer, kafka_instance = mock_producer
    
    log = LogEntry(
        level=LogLevel.INFO,
        message="Test log",
        service="test-service"
    )
    
    # Mock failed send
    kafka_instance.produce.side_effect = Exception("Kafka error")
    
    result = producer.send_log(log)
    
    assert result is False

def test_producer_flush(mock_producer):
    """Test producer flush operation"""
    producer, kafka_instance = mock_producer
    
    # Mock flush
    kafka_instance.flush.return_value = 0  # No remaining messages
    
    producer.flush()
    
    kafka_instance.flush.assert_called_once()

def test_producer_stats(mock_producer):
    """Test producer statistics"""
    producer, kafka_instance = mock_producer
    
    # Mock list_topics response
    mock_metadata = Mock()
    mock_metadata.topics = {"topic1": None, "topic2": None}
    mock_metadata.brokers = {"broker1": None}
    kafka_instance.list_topics.return_value = mock_metadata
    
    stats = producer.get_stats()
    
    assert "topics" in stats
    assert "brokers" in stats
    assert stats["topics"] == 2
    assert stats["brokers"] == 1
