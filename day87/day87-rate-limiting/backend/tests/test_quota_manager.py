import pytest
import asyncio
import time
from unittest.mock import AsyncMock
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from quota.quota_manager import QuotaManager, QuotaType

@pytest.fixture
def mock_redis():
    redis_mock = AsyncMock()
    redis_mock.hget.return_value = "50"  # Current usage
    redis_mock.hincrby.return_value = None
    redis_mock.expire.return_value = None
    return redis_mock

@pytest.mark.asyncio
async def test_quota_check_within_limits(mock_redis):
    manager = QuotaManager(mock_redis)
    
    allowed, results = await manager.check_quota("test_user", QuotaType.REQUESTS, 10, "free")
    
    assert allowed == True
    assert results["daily"]["current_usage"] == 50
    assert results["daily"]["limit"] == 10000
    assert results["daily"]["remaining"] == 9950

@pytest.mark.asyncio
async def test_quota_check_exceeds_limits(mock_redis):
    # Mock high usage
    mock_redis.hget.return_value = "9995"
    
    manager = QuotaManager(mock_redis)
    
    allowed, results = await manager.check_quota("test_user", QuotaType.REQUESTS, 10, "free")
    
    assert allowed == False
    assert results["daily"]["remaining"] == 5

@pytest.mark.asyncio
async def test_enterprise_unlimited_quota(mock_redis):
    manager = QuotaManager(mock_redis)
    
    allowed, results = await manager.check_quota("test_user", QuotaType.REQUESTS, 1000000, "enterprise")
    
    assert allowed == True
    assert results["daily"]["limit"] == -1
    assert results["daily"]["remaining"] == -1
