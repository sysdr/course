import pytest
import asyncio
import json
from unittest.mock import AsyncMock, MagicMock
import sys
import os

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from producer.producer import LogProducer
from models.log_entry import LogEntry

@pytest.mark.asyncio
async def test_log_entry_creation():
    """Test LogEntry creation and serialization"""
    log_data = {
        'level': 'INFO',
        'message': 'Test message',
        'source': 'test_app',
        'user_id': 12345
    }
    
    entry = LogEntry.from_dict(log_data)
    assert entry.level == 'INFO'
    assert entry.message == 'Test message'
    assert entry.source == 'test_app'
    assert entry.metadata['user_id'] == 12345
    
    # Test JSON serialization
    json_str = entry.to_json()
    parsed = json.loads(json_str)
    assert parsed['level'] == 'INFO'
    assert 'formatted_time' in parsed

@pytest.mark.asyncio
async def test_batch_manager():
    """Test batch manager functionality"""
    from producer.batch_manager import BatchManager
    
    batch_manager = BatchManager(max_size=3, max_wait_ms=50)
    
    # Add logs
    for i in range(2):
        log = LogEntry('INFO', f'Message {i}', 'test')
        await batch_manager.add_log(log)
    
    # Should not have a batch yet (size < 3)
    batch = await batch_manager.get_batch()
    assert batch is None
    
    # Add one more to trigger size-based flush
    log = LogEntry('INFO', 'Message 2', 'test')
    await batch_manager.add_log(log)
    
    # Should have a batch now
    batch = await batch_manager.get_batch()
    assert batch is not None
    assert len(batch) == 3

@pytest.mark.asyncio
async def test_health_monitor():
    """Test health monitoring"""
    from producer.health_monitor import HealthMonitor
    
    monitor = HealthMonitor()
    
    # Record some activity
    monitor.record_log_received()
    monitor.record_batch_published(5, 0.1)
    
    status = await monitor.get_health_status()
    assert status['healthy'] is True
    assert status['logs_received'] == 1
    assert status['logs_published'] == 5
    
    metrics = await monitor.get_metrics()
    assert 'average_batch_size' in metrics

def test_circuit_breaker():
    """Test circuit breaker functionality"""
    from producer.connection_pool import CircuitBreaker
    
    cb = CircuitBreaker(failure_threshold=3, recovery_timeout=1)
    
    # Initially closed
    assert not cb.is_open()
    
    # Record failures
    for _ in range(3):
        cb.record_failure()
    
    # Should be open now
    assert cb.is_open()
    
    # Record success should reset
    cb.record_success()
    assert not cb.is_open()

if __name__ == "__main__":
    pytest.main([__file__])
