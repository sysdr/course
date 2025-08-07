import time
import json
import structlog
from typing import Dict, Optional
from enum import Enum

logger = structlog.get_logger()

class QuotaType(Enum):
    REQUESTS = "requests"
    COMPUTE_TIME = "compute_time"
    DATA_PROCESSED = "data_processed"
    STORAGE = "storage"

class QuotaManager:
    def __init__(self, redis_client):
        self.redis = redis_client
        self.quota_configs = {
            "free": {
                QuotaType.REQUESTS: {"daily": 10000, "monthly": 300000},
                QuotaType.COMPUTE_TIME: {"daily": 3600, "monthly": 108000},  # seconds
                QuotaType.DATA_PROCESSED: {"daily": 1024**3, "monthly": 30*1024**3}  # bytes
            },
            "premium": {
                QuotaType.REQUESTS: {"daily": 100000, "monthly": 3000000},
                QuotaType.COMPUTE_TIME: {"daily": 36000, "monthly": 1080000},
                QuotaType.DATA_PROCESSED: {"daily": 10*1024**3, "monthly": 300*1024**3}
            },
            "enterprise": {
                QuotaType.REQUESTS: {"daily": -1, "monthly": -1},  # Unlimited
                QuotaType.COMPUTE_TIME: {"daily": -1, "monthly": -1},
                QuotaType.DATA_PROCESSED: {"daily": -1, "monthly": -1}
            }
        }
    
    async def check_quota(self, user_id: str, quota_type: QuotaType, 
                         amount: int = 1, user_tier: str = "free") -> tuple[bool, Dict]:
        """Check if user has sufficient quota"""
        current_time = int(time.time())
        
        # Get quota configuration for user tier
        user_config = self.quota_configs.get(user_tier, self.quota_configs["free"])
        quotas = user_config.get(quota_type, {"daily": 0, "monthly": 0})
        
        results = {}
        allowed = True
        
        for period in ["daily", "monthly"]:
            quota_limit = quotas[period]
            if quota_limit == -1:  # Unlimited
                results[period] = {
                    "current_usage": 0,
                    "limit": -1,
                    "remaining": -1,
                    "reset_time": 0
                }
                continue
            
            usage_key = f"quota:{user_id}:{quota_type.value}:{period}"
            current_usage = await self._get_current_usage(usage_key, period, current_time)
            
            if current_usage + amount > quota_limit:
                allowed = False
            
            results[period] = {
                "current_usage": current_usage,
                "limit": quota_limit,
                "remaining": max(0, quota_limit - current_usage),
                "reset_time": self._get_reset_time(period, current_time)
            }
        
        # If allowed, consume the quota
        if allowed:
            await self._consume_quota(user_id, quota_type, amount, current_time)
        
        return allowed, results
    
    async def _get_current_usage(self, key: str, period: str, current_time: int) -> int:
        """Get current usage for a period"""
        if period == "daily":
            # Reset daily usage at midnight UTC
            day_start = current_time - (current_time % 86400)
            usage_data = await self.redis.hget(key, str(day_start))
        else:  # monthly
            # Reset monthly usage on 1st of month
            import datetime
            dt = datetime.datetime.fromtimestamp(current_time)
            month_start = int(datetime.datetime(dt.year, dt.month, 1).timestamp())
            usage_data = await self.redis.hget(key, str(month_start))
        
        return int(usage_data) if usage_data else 0
    
    async def _consume_quota(self, user_id: str, quota_type: QuotaType, 
                           amount: int, current_time: int):
        """Consume quota for user"""
        for period in ["daily", "monthly"]:
            usage_key = f"quota:{user_id}:{quota_type.value}:{period}"
            
            if period == "daily":
                period_start = current_time - (current_time % 86400)
                ttl = 86400 * 2  # Keep for 2 days
            else:
                import datetime
                dt = datetime.datetime.fromtimestamp(current_time)
                period_start = int(datetime.datetime(dt.year, dt.month, 1).timestamp())
                ttl = 86400 * 35  # Keep for 35 days
            
            await self.redis.hincrby(usage_key, str(period_start), amount)
            await self.redis.expire(usage_key, ttl)
    
    def _get_reset_time(self, period: str, current_time: int) -> int:
        """Get when quota resets"""
        if period == "daily":
            return current_time + (86400 - (current_time % 86400))
        else:  # monthly
            import datetime
            dt = datetime.datetime.fromtimestamp(current_time)
            if dt.month == 12:
                next_month = datetime.datetime(dt.year + 1, 1, 1)
            else:
                next_month = datetime.datetime(dt.year, dt.month + 1, 1)
            return int(next_month.timestamp())
    
    async def get_quota_status(self, user_id: str, user_tier: str = "free") -> Dict:
        """Get comprehensive quota status for user"""
        current_time = int(time.time())
        status = {}
        
        for quota_type in QuotaType:
            _, quota_info = await self.check_quota(user_id, quota_type, 0, user_tier)
            status[quota_type.value] = quota_info
        
        return {
            "current_usage": sum([info["daily"]["current_usage"] for info in status.values() if info["daily"]["limit"] != -1]),
            "limit": sum([info["daily"]["limit"] for info in status.values() if info["daily"]["limit"] != -1 and info["daily"]["limit"] > 0]),
            "reset_time": min([info["daily"]["reset_time"] for info in status.values() if info["daily"]["reset_time"] > 0]),
            "burst_available": 100,  # Burst allowance
            "detailed": status
        }
