from typing import List, Optional, Dict, Any
import asyncio
from collections import defaultdict
from datetime import datetime

from schemas.log_schema import LogEntryType

class LogDataLoader:
    def __init__(self):
        self._log_cache: Dict[str, LogEntryType] = {}
        self._trace_cache: Dict[str, List[LogEntryType]] = {}
        self._batch_load_queue: List[str] = []
        self._batch_load_future: Optional[asyncio.Future] = None
    
    async def load_log(self, log_id: str) -> Optional[LogEntryType]:
        """Load a single log by ID with batching"""
        if log_id in self._log_cache:
            return self._log_cache[log_id]
        
        # Add to batch queue
        self._batch_load_queue.append(log_id)
        
        # Schedule batch load if not already scheduled
        if self._batch_load_future is None:
            self._batch_load_future = asyncio.create_task(self._batch_load_logs())
        
        await self._batch_load_future
        return self._log_cache.get(log_id)
    
    async def load_logs_by_trace(self, trace_id: str) -> List[LogEntryType]:
        """Load all logs for a trace ID"""
        if trace_id in self._trace_cache:
            return self._trace_cache[trace_id]
        
        # Simulate database query
        logs = await self._query_logs_by_trace(trace_id)
        self._trace_cache[trace_id] = logs
        return logs
    
    async def _batch_load_logs(self):
        """Batch load logs to prevent N+1 queries"""
        if not self._batch_load_queue:
            return
        
        log_ids = list(self._batch_load_queue)
        self._batch_load_queue.clear()
        self._batch_load_future = None
        
        # Simulate batch database query
        logs = await self._query_logs_by_ids(log_ids)
        
        # Cache results
        for log in logs:
            self._log_cache[log.id] = log
    
    async def _query_logs_by_ids(self, log_ids: List[str]) -> List[LogEntryType]:
        """Query multiple logs by IDs"""
        # Simulate database batch query
        await asyncio.sleep(0.01)
        
        logs = []
        for log_id in log_ids:
            log = LogEntryType(
                id=log_id,
                timestamp=datetime.utcnow(),
                service="sample-service",
                level="INFO",
                message=f"Sample log for ID {log_id}",
                trace_id=f"trace_{log_id.split('_')[-1]}"
            )
            logs.append(log)
        
        return logs
    
    async def _query_logs_by_trace(self, trace_id: str) -> List[LogEntryType]:
        """Query logs by trace ID"""
        # Simulate database query
        await asyncio.sleep(0.01)
        
        logs = []
        for i in range(3):  # Simulate 3 logs per trace
            log = LogEntryType(
                id=f"log_{trace_id}_{i}",
                timestamp=datetime.utcnow(),
                service=f"service-{i}",
                level="INFO",
                message=f"Trace log {i} for {trace_id}",
                trace_id=trace_id
            )
            logs.append(log)
        
        return logs
