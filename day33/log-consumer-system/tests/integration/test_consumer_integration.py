import pytest
import asyncio
import json
import redis.asyncio as redis
from src.consumers.log_consumer import LogConsumer, ConsumerConfig
from src.processors.log_processor import LogProcessor

@pytest.fixture
def integration_config():
    return ConsumerConfig(
        redis_url="redis://localhost:6379",
        queue_name="test-logs",
        consumer_group="test-processors",
        consumer_id="test-consumer-integration"
    )

@pytest.mark.asyncio
async def test_end_to_end_processing(integration_config):
    """Test complete message flow from queue to processing"""
    # Create Redis client
    redis_client = redis.from_url("redis://localhost:6379")
    
    # Setup
    processor = LogProcessor()
    consumer = LogConsumer(integration_config, processor.process)
    
    # Add test message to stream
    test_message = {
        "id": "integration-test-1",
        "timestamp": 1234567890.0,
        "level": "INFO",
        "message": "Integration test message",
        "source": "test-app"
    }
    
    await redis_client.xadd(
        integration_config.queue_name,
        {"data": json.dumps(test_message)}
    )
    
    # Connect consumer and process messages
    await consumer.connect()
    
    # Process for a short time
    consume_task = asyncio.create_task(consumer.consume())
    await asyncio.sleep(2)  # Let it process
    
    await consumer.stop()
    consume_task.cancel()
    
    # Clean up
    await redis_client.close()
    
    # Verify processing
    assert consumer.processed_count > 0
    assert processor.metrics["total_processed"] > 0
