import asyncio
from typing import AsyncGenerator, Optional, Set
import json
from datetime import datetime

from models.log_models import LogEntry

class SubscriptionManager:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if not self._initialized:
            self._log_subscribers: Set[asyncio.Queue] = set()
            self._error_subscribers: Set[asyncio.Queue] = set()
            self._initialized = True
    
    async def log_stream(self, service: Optional[str] = None, 
                        level: Optional[str] = None) -> AsyncGenerator[dict, None]:
        """Subscribe to log stream with optional filtering"""
        queue = asyncio.Queue()
        self._log_subscribers.add(queue)
        
        try:
            while True:
                log_entry = await queue.get()
                
                # Apply filters
                if service and log_entry.service != service:
                    continue
                if level and log_entry.level != level:
                    continue
                
                yield log_entry
        finally:
            self._log_subscribers.discard(queue)
    
    async def error_stream(self) -> AsyncGenerator[dict, None]:
        """Subscribe to error-level logs only"""
        queue = asyncio.Queue()
        self._error_subscribers.add(queue)
        
        try:
            while True:
                error_log = await queue.get()
                yield error_log
        finally:
            self._error_subscribers.discard(queue)
    
    async def publish_log(self, log_entry: LogEntry):
        """Publish log to all subscribers"""
        # Create a simple dict representation to avoid circular import
        log_type = {
            "id": log_entry.id,
            "timestamp": log_entry.timestamp,
            "service": log_entry.service,
            "level": log_entry.level,
            "message": log_entry.message,
            "metadata": log_entry.metadata,
            "trace_id": log_entry.trace_id,
            "span_id": log_entry.span_id
        }
        
        # Send to general log subscribers
        for queue in self._log_subscribers.copy():
            try:
                queue.put_nowait(log_type)
            except asyncio.QueueFull:
                # Remove slow consumers
                self._log_subscribers.discard(queue)
        
        # Send to error subscribers if it's an error
        if log_entry.level in ["ERROR", "CRITICAL"]:
            for queue in self._error_subscribers.copy():
                try:
                    queue.put_nowait(log_type)
                except asyncio.QueueFull:
                    self._error_subscribers.discard(queue)
