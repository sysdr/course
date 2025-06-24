import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock
from src.consumers.log_consumer import LogConsumer, ConsumerConfig, LogMessage

@pytest.fixture
def consumer_config():
    return ConsumerConfig(
        redis_url="redis://localhost:6379",
        consumer_id="test-consumer"
    )

@pytest.fixture
def mock_processor():
    return MagicMock(return_value=True)

@pytest.fixture
def log_consumer(consumer_config, mock_processor):
    return LogConsumer(consumer_config, mock_processor)

@pytest.mark.asyncio
async def test_consumer_creation(log_consumer):
    """Test consumer can be created with valid config"""
    assert log_consumer.config.consumer_id == "test-consumer"
    assert log_consumer.processed_count == 0
    assert log_consumer.error_count == 0

@pytest.mark.asyncio
async def test_process_single_message(log_consumer):
    """Test processing a single log message"""
    log_message = LogMessage(
        id="test-1",
        timestamp=1234567890.0,
        level="INFO",
        message="Test log message",
        source="test-app"
    )
    
    result = await log_consumer._process_single_message(log_message)
    assert result is True
    log_consumer.processor.assert_called_once_with(log_message)

def test_get_stats(log_consumer):
    """Test getting consumer statistics"""
    log_consumer.processed_count = 10
    log_consumer.error_count = 2
    
    stats = log_consumer.get_stats()
    assert stats["processed_count"] == 10
    assert stats["error_count"] == 2
    assert abs(stats["success_rate"] - (10/12)) < 0.001
