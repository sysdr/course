from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import asyncio
import json
from collections import defaultdict

from models.log_models import LogEntry, LogLevel, ServiceType
from schemas.log_schema import LogEntryType, LogFilterInput, LogCreateInput, LogStats
from utils.database import get_db_connection
from utils.redis_client import get_redis
from utils.data_loader import LogDataLoader

class LogResolver:
    _data_loader = None
    
    @classmethod
    def get_data_loader(cls):
        if cls._data_loader is None:
            cls._data_loader = LogDataLoader()
        return cls._data_loader
    
    @classmethod
    async def get_logs(cls, filters: Optional[LogFilterInput] = None) -> List[LogEntryType]:
        """Get logs with flexible filtering and caching"""
        try:
            redis = await get_redis()
            
            # Create cache key based on filters
            cache_key = cls._create_cache_key("logs", filters)
            cached_result = await redis.get(cache_key)
            
            if cached_result:
                log_data = json.loads(cached_result)
                return [LogEntryType(**log) for log in log_data]
        except Exception:
            # If Redis is not available, continue without caching
            pass
        
        # Query database
        logs = await cls._query_logs_from_db(filters)
        
        # Cache results for 30 seconds (if Redis is available)
        try:
            redis = await get_redis()
            log_data = [log.__dict__ for log in logs]
            await redis.setex(cache_key, 30, json.dumps(log_data, default=str))
        except Exception:
            # If Redis is not available, skip caching
            pass
        
        return logs
    
    @classmethod
    async def get_log_by_id(cls, log_id: str) -> Optional[LogEntryType]:
        """Get a specific log by ID using DataLoader"""
        data_loader = cls.get_data_loader()
        return await data_loader.load_log(log_id)
    
    @classmethod
    async def get_logs_by_trace(cls, trace_id: str) -> List[LogEntryType]:
        """Get all logs for a specific trace ID"""
        data_loader = cls.get_data_loader()
        return await data_loader.load_logs_by_trace(trace_id)
    
    @classmethod
    async def create_log(cls, log_data: LogCreateInput) -> LogEntryType:
        """Create a new log entry"""
        log_entry = LogEntry(
            service=log_data.service,
            level=log_data.level,
            message=log_data.message,
            metadata=json.loads(log_data.metadata) if log_data.metadata else None,
            trace_id=log_data.trace_id
        )
        
        # Save to database (simulated)
        await cls._save_log_to_db(log_entry)
        
        # Publish to subscription stream
        from utils.subscription_manager import SubscriptionManager
        subscription_manager = SubscriptionManager()
        await subscription_manager.publish_log(log_entry)
        
        return LogEntryType(
            id=log_entry.id,
            timestamp=log_entry.timestamp,
            service=log_entry.service,
            level=log_entry.level,
            message=log_entry.message,
            metadata=log_entry.metadata,
            trace_id=log_entry.trace_id,
            span_id=log_entry.span_id
        )
    
    @classmethod
    async def bulk_create_logs(cls, logs: List[LogCreateInput]) -> List[LogEntryType]:
        """Create multiple logs efficiently"""
        log_entries = []
        for log_data in logs:
            log_entry = LogEntry(
                service=log_data.service,
                level=log_data.level,
                message=log_data.message,
                metadata=json.loads(log_data.metadata) if log_data.metadata else None,
                trace_id=log_data.trace_id
            )
            log_entries.append(log_entry)
        
        # Batch save to database
        await cls._bulk_save_logs_to_db(log_entries)
        
        return [LogEntryType(
            id=log.id,
            timestamp=log.timestamp,
            service=log.service,
            level=log.level,
            message=log.message,
            metadata=log.metadata,
            trace_id=log.trace_id,
            span_id=log.span_id
        ) for log in log_entries]
    
    @classmethod
    async def get_log_stats(cls, start_time: Optional[datetime] = None, 
                           end_time: Optional[datetime] = None) -> LogStats:
        """Get aggregated log statistics"""
        if not start_time:
            start_time = datetime.utcnow() - timedelta(hours=1)
        if not end_time:
            end_time = datetime.utcnow()
        
        # Simulate stats calculation
        stats = LogStats(
            total_logs=1250,
            error_count=23,
            warning_count=156,
            info_count=1071,
            services=["api-gateway", "user-service", "order-service", "payment-service"],
            time_range=f"{start_time.isoformat()} to {end_time.isoformat()}"
        )
        
        return stats
    
    @classmethod
    async def get_services(cls) -> List[str]:
        """Get list of all services"""
        return [service.value for service in ServiceType]
    
    @classmethod
    def _create_cache_key(cls, prefix: str, filters: Optional[LogFilterInput]) -> str:
        """Create cache key from filters"""
        if not filters:
            return f"{prefix}:all"
        
        key_parts = [prefix]
        if filters.service:
            key_parts.append(f"service:{filters.service}")
        if filters.level:
            key_parts.append(f"level:{filters.level}")
        if filters.search_text:
            key_parts.append(f"search:{filters.search_text}")
        
        return ":".join(key_parts)
    
    @classmethod
    async def _query_logs_from_db(cls, filters: Optional[LogFilterInput]) -> List[LogEntryType]:
        """Query logs from database with filters"""
        # Simulate database query with sample data
        sample_logs = []
        services = ["api-gateway", "user-service", "order-service", "payment-service"]
        levels = ["INFO", "WARNING", "ERROR"]
        
        for i in range(20):
            import random
            service = random.choice(services)
            level = random.choice(levels)
            
            # Apply filters
            if filters:
                if filters.service and service != filters.service:
                    continue
                if filters.level and level != filters.level:
                    continue
            
            log = LogEntryType(
                id=f"log_{i}",
                timestamp=datetime.utcnow() - timedelta(minutes=random.randint(1, 60)),
                service=service,
                level=level,
                message=f"Sample log message {i} from {service}",
                metadata=json.dumps({"request_id": f"req_{i}", "user_id": f"user_{i % 10}"}),
                trace_id=f"trace_{i % 5}",
                span_id=f"span_{i}"
            )
            sample_logs.append(log)
        
        return sample_logs[:filters.limit if filters and filters.limit else 20]
    
    @classmethod
    async def _save_log_to_db(cls, log_entry: LogEntry):
        """Save log to database (simulated)"""
        # In real implementation, this would save to PostgreSQL
        await asyncio.sleep(0.01)  # Simulate DB write
    
    @classmethod
    async def _bulk_save_logs_to_db(cls, log_entries: List[LogEntry]):
        """Bulk save logs to database (simulated)"""
        # In real implementation, this would use bulk insert
        await asyncio.sleep(0.1)  # Simulate bulk DB write
