import pytest
import asyncio
import json
import time
import redis.asyncio as redis
from src.consumers.consumer_manager import ConsumerManager

@pytest.mark.asyncio
async def test_consumer_load():
    """Load test with multiple messages"""
    # Configuration for load test
    config = {
        "redis_url": "redis://localhost:6379",
        "queue_name": "load-test-logs",
        "consumer_group": "load-test-processors",
        "num_consumers": 3,
        "batch_size": 50
    }
    
    # Generate test messages
    redis_client = redis.from_url(config["redis_url"])
    
    print("Generating test messages...")
    start_time = time.time()
    
    # Add 1000 test messages
    for i in range(1000):
        test_message = {
            "id": f"load-test-{i}",
            "timestamp": time.time(),
            "level": "INFO" if i % 4 != 2 else "ERROR",
            "message": f"Load test message {i}",
            "source": "load-test-app",
            "metadata": {
                "endpoint": f"/api/endpoint{i % 10}",
                "response_time": 20 + (i % 100),
                "status_code": 200 if i % 10 != 0 else 500
            }
        }
        
        await redis_client.xadd(
            config["queue_name"],
            {"data": json.dumps(test_message)}
        )
    
    generation_time = time.time() - start_time
    print(f"Generated 1000 messages in {generation_time:.2f} seconds")
    
    # Start consumer manager
    manager = ConsumerManager(config)
    
    processing_start = time.time()
    
    # Start processing (run for 30 seconds max)
    try:
        await asyncio.wait_for(manager.start(), timeout=30.0)
    except asyncio.TimeoutError:
        pass
    finally:
        await manager.stop()
    
    processing_time = time.time() - processing_start
    
    # Get final stats
    stats = manager.get_stats()
    
    print(f"Load Test Results:")
    print(f"Processing time: {processing_time:.2f} seconds")
    print(f"Total processed: {stats['total_processed']}")
    print(f"Total errors: {stats['total_errors']}")
    print(f"Messages per second: {stats['total_processed'] / processing_time:.2f}")
    
    await redis_client.close()
    
    # Assertions
    assert stats['total_processed'] > 0
    assert stats['total_processed'] / processing_time > 10  # At least 10 msg/sec
