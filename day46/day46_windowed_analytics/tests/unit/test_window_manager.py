import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock
import time

from src.windowing.manager.window_manager import WindowManager, Window

@pytest.fixture
def mock_redis():
    redis_mock = AsyncMock()
    redis_mock.get = AsyncMock(return_value=None)
    redis_mock.set = AsyncMock()
    redis_mock.keys = AsyncMock(return_value=[])
    redis_mock.publish = AsyncMock()
    return redis_mock

@pytest.fixture
def window_config():
    return {
        'windowing': {
            'grace_period': 60,
            'max_active_windows': 100,
            'timezone': 'UTC'
        },
        'window_types': [
            {'name': '5min', 'size': 300, 'retention': 3600},
            {'name': '1hour', 'size': 3600, 'retention': 86400}
        ]
    }

@pytest.mark.asyncio
class TestWindowManager:
    async def test_align_timestamp_to_window(self, mock_redis, window_config):
        manager = WindowManager(mock_redis, window_config)
        
        # Test 5-minute alignment
        timestamp = 1640995830  # 2022-01-01 00:03:50
        aligned = manager.align_timestamp_to_window(timestamp, 300)
        expected = 1640995800  # 2022-01-01 00:00:00
        
        assert aligned == expected
        
    async def test_create_window(self, mock_redis, window_config):
        manager = WindowManager(mock_redis, window_config)
        timestamp = int(time.time())
        
        window = await manager.get_or_create_window(timestamp, '5min')
        
        assert window.window_type == '5min'
        assert window.state == 'active'
        assert window.start_time <= timestamp
        assert window.end_time > timestamp
        
    async def test_add_event_to_window(self, mock_redis, window_config):
        manager = WindowManager(mock_redis, window_config)
        timestamp = int(time.time())
        
        event_data = {
            'level': 'INFO',
            'service': 'test-service',
            'response_time': 100
        }
        
        result = await manager.add_event_to_window(timestamp, event_data)
        assert result is True
        
        # Check window was created and event added
        window_id = f"5min_{manager.align_timestamp_to_window(timestamp, 300)}"
        assert window_id in manager.active_windows
        
        window = manager.active_windows[window_id]
        assert window.event_count == 1
        assert 'aggregations' in window.data
        
    async def test_late_event_rejection(self, mock_redis, window_config):
        manager = WindowManager(mock_redis, window_config)
        
        # Event from 10 minutes ago (beyond grace period)
        old_timestamp = int(time.time()) - 600
        event_data = {'level': 'INFO', 'service': 'test'}
        
        result = await manager.add_event_to_window(old_timestamp, event_data)
        assert result is False
