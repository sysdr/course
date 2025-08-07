import time
import asyncio
import structlog
from typing import Dict, Optional, Tuple

logger = structlog.get_logger()

class SlidingWindowLimiter:
    def __init__(self, redis_client, window_size: int = 60, default_limit: int = 1000):
        self.redis = redis_client
        self.window_size = window_size
        self.default_limit = default_limit
        self.user_limits = {}  # In production, this would be in database
    
    async def is_allowed(self, user_id: str, weight: int = 1) -> Tuple[bool, Dict]:
        """Check if request is allowed and return status info"""
        current_time = int(time.time())
        window_start = current_time - self.window_size
        
        key = f"rate_limit:{user_id}"
        
        # Get user's specific limit
        user_limit = self.user_limits.get(user_id, self.default_limit)
        
        # Use Redis pipeline for atomic operations
        pipe = self.redis.pipeline()
        
        # Remove expired entries
        pipe.zremrangebyscore(key, 0, window_start)
        
        # Count current requests in window
        pipe.zcard(key)
        
        # Add current request with weight
        for _ in range(weight):
            pipe.zadd(key, {f"{current_time}:{asyncio.current_task().get_name()}": current_time})
        
        # Set expiration
        pipe.expire(key, self.window_size + 10)
        
        results = await pipe.execute()
        current_count = results[1] + weight
        
        is_allowed = current_count <= user_limit
        
        if not is_allowed:
            # Remove the requests we just added since they're not allowed
            for _ in range(weight):
                await self.redis.zpopmax(key)
        
        status = {
            "requests_remaining": max(0, user_limit - current_count),
            "reset_time": current_time + self.window_size,
            "retry_after": 60 if not is_allowed else 0,
            "current_usage": current_count,
            "limit": user_limit
        }
        
        logger.info("Rate limit check", 
                   user_id=user_id, 
                   allowed=is_allowed, 
                   current=current_count, 
                   limit=user_limit)
        
        return is_allowed, status
    
    async def get_limit_status(self, user_id: str) -> Dict:
        """Get current rate limit status for user"""
        current_time = int(time.time())
        window_start = current_time - self.window_size
        key = f"rate_limit:{user_id}"
        
        # Clean and count
        await self.redis.zremrangebyscore(key, 0, window_start)
        current_count = await self.redis.zcard(key)
        
        user_limit = self.user_limits.get(user_id, self.default_limit)
        
        return {
            "requests_remaining": max(0, user_limit - current_count),
            "reset_time": current_time + self.window_size,
            "retry_after": 0
        }
    
    def set_user_limit(self, user_id: str, limit: int):
        """Set custom limit for user"""
        self.user_limits[user_id] = limit
        logger.info("Updated user limit", user_id=user_id, limit=limit)
