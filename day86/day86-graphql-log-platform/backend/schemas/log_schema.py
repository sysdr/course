import strawberry
from typing import List, Optional, AsyncGenerator
from datetime import datetime, timedelta
import asyncio
from enum import Enum

from models.log_models import LogEntry, LogLevel, ServiceType
from utils.subscription_manager import SubscriptionManager

@strawberry.type
class LogEntryType:
    id: str
    timestamp: datetime
    service: str
    level: str
    message: str
    metadata: Optional[str] = None
    trace_id: Optional[str] = None
    span_id: Optional[str] = None
    
    @strawberry.field
    async def related_logs(self) -> List["LogEntryType"]:
        """Get related logs by trace_id"""
        if not self.trace_id:
            return []
        # Import here to avoid circular import
        from resolvers.log_resolvers import LogResolver
        return await LogResolver.get_logs_by_trace(self.trace_id)

@strawberry.input
class LogFilterInput:
    service: Optional[str] = None
    level: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    search_text: Optional[str] = None
    trace_id: Optional[str] = None
    limit: Optional[int] = 100

@strawberry.input
class LogCreateInput:
    service: str
    level: str
    message: str
    metadata: Optional[str] = None
    trace_id: Optional[str] = None

@strawberry.type
class LogStats:
    total_logs: int
    error_count: int
    warning_count: int
    info_count: int
    services: List[str]
    time_range: str

@strawberry.type
class Query:
    @strawberry.field
    async def logs(self, filters: Optional[LogFilterInput] = None) -> List[LogEntryType]:
        """Query logs with flexible filtering"""
        from resolvers.log_resolvers import LogResolver
        return await LogResolver.get_logs(filters)
    
    @strawberry.field
    async def log_by_id(self, log_id: str) -> Optional[LogEntryType]:
        """Get a specific log entry by ID"""
        from resolvers.log_resolvers import LogResolver
        return await LogResolver.get_log_by_id(log_id)
    
    @strawberry.field
    async def log_stats(self, 
                       start_time: Optional[datetime] = None,
                       end_time: Optional[datetime] = None) -> LogStats:
        """Get aggregated log statistics"""
        from resolvers.log_resolvers import LogResolver
        return await LogResolver.get_log_stats(start_time, end_time)
    
    @strawberry.field
    async def services(self) -> List[str]:
        """Get list of all services that have logged"""
        from resolvers.log_resolvers import LogResolver
        return await LogResolver.get_services()

@strawberry.type
class Mutation:
    @strawberry.mutation
    async def create_log(self, log_data: LogCreateInput) -> LogEntryType:
        """Create a new log entry"""
        from resolvers.log_resolvers import LogResolver
        return await LogResolver.create_log(log_data)
    
    @strawberry.mutation
    async def bulk_create_logs(self, logs: List[LogCreateInput]) -> List[LogEntryType]:
        """Create multiple log entries at once"""
        from resolvers.log_resolvers import LogResolver
        return await LogResolver.bulk_create_logs(logs)

@strawberry.type
class Subscription:
    @strawberry.subscription
    async def log_stream(self, 
                        service: Optional[str] = None,
                        level: Optional[str] = None) -> AsyncGenerator[LogEntryType, None]:
        """Real-time log stream with optional filtering"""
        subscription_manager = SubscriptionManager()
        async for log_data in subscription_manager.log_stream(service, level):
            # Convert dict to LogEntryType
            yield LogEntryType(**log_data)
    
    @strawberry.subscription
    async def error_alerts(self) -> AsyncGenerator[LogEntryType, None]:
        """Real-time stream of error-level logs"""
        subscription_manager = SubscriptionManager()
        async for error_data in subscription_manager.error_stream():
            # Convert dict to LogEntryType
            yield LogEntryType(**error_data)
