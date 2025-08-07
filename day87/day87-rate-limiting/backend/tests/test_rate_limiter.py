import pytest
import asyncio
import time
from unittest.mock import AsyncMock, MagicMock
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from rate_limiter.sliding_window import SlidingWindowLimiter

@pytest.fixture
def mock_redis():
    redis_mock = AsyncMock()
    
    # Mock pipeline
    pipeline_mock = MagicMock()
    pipeline_mock.zremrangebyscore = MagicMock()
    pipeline_mock.zcard = MagicMock()
    pipeline_mock.zadd = MagicMock()
    pipeline_mock.expire = MagicMock()
    pipeline_mock.execute = AsyncMock(return_value=[None, 5, None, None])  # current count = 5
    
    # Make pipeline() return the mock directly, not as a coroutine
    redis_mock.pipeline = MagicMock(return_value=pipeline_mock)
    
    # Mock other operations
    redis_mock.zcard.return_value = 5
    redis_mock.zremrangebyscore.return_value = None
    redis_mock.zpopmax.return_value = None
    
    return redis_mock

@pytest.mark.asyncio
async def test_rate_limiter_allows_under_limit(mock_redis):
    limiter = SlidingWindowLimiter(mock_redis, window_size=60, default_limit=100)
    
    allowed, status = await limiter.is_allowed("test_user", 1)
    
    assert allowed == True
    assert status["requests_remaining"] == 94  # 100 - 5 - 1
    assert status["current_usage"] == 6  # 5 + 1
    assert status["limit"] == 100

@pytest.mark.asyncio  
async def test_rate_limiter_blocks_over_limit(mock_redis):
    # Mock high current count
    pipeline_mock = MagicMock()
    pipeline_mock.zremrangebyscore = MagicMock()
    pipeline_mock.zcard = MagicMock()
    pipeline_mock.zadd = MagicMock()
    pipeline_mock.expire = MagicMock()
    pipeline_mock.execute = AsyncMock(return_value=[None, 99, None, None])  # current count = 99
    mock_redis.pipeline = MagicMock(return_value=pipeline_mock)
    
    limiter = SlidingWindowLimiter(mock_redis, window_size=60, default_limit=100)
    
    allowed, status = await limiter.is_allowed("test_user", 5)  # Would exceed limit
    
    assert allowed == False
    assert status["requests_remaining"] == 0
    assert status["retry_after"] == 60

@pytest.mark.asyncio
async def test_custom_user_limits(mock_redis):
    limiter = SlidingWindowLimiter(mock_redis, window_size=60, default_limit=100)
    limiter.set_user_limit("premium_user", 1000)
    
    allowed, status = await limiter.is_allowed("premium_user", 1)
    
    assert status["limit"] == 1000
    assert status["requests_remaining"] == 994  # 1000 - 5 - 1
