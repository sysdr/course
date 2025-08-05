import asyncio
from typing import Optional, Any
import json

# Simulated Redis client
class MockRedis:
    def __init__(self):
        self._data = {}
        self._ttl = {}
    
    async def get(self, key: str) -> Optional[str]:
        if key in self._data:
            return self._data[key]
        return None
    
    async def set(self, key: str, value: str) -> bool:
        self._data[key] = value
        return True
    
    async def setex(self, key: str, seconds: int, value: str) -> bool:
        self._data[key] = value
        self._ttl[key] = seconds
        # Simulate TTL expiration
        asyncio.create_task(self._expire_key(key, seconds))
        return True
    
    async def _expire_key(self, key: str, seconds: int):
        await asyncio.sleep(seconds)
        if key in self._data:
            del self._data[key]
        if key in self._ttl:
            del self._ttl[key]

_redis_client = None

async def init_redis():
    """Initialize Redis connection"""
    global _redis_client
    _redis_client = MockRedis()
    print("✅ Redis initialized")

async def get_redis() -> MockRedis:
    """Get Redis client"""
    if _redis_client is None:
        await init_redis()
    return _redis_client

async def close_redis():
    """Close Redis connection"""
    global _redis_client
    _redis_client = None
    print("✅ Redis connection closed")
