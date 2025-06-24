import asyncio
import time
from typing import List, Optional

try:
    from ..models.log_entry import LogEntry
except ImportError:
    from models.log_entry import LogEntry

class BatchManager:
    def __init__(self, max_size: int = 50, max_wait_ms: int = 100):
        self.max_size = max_size
        self.max_wait_ms = max_wait_ms
        self.current_batch = []
        self.last_flush_time = time.time()
        self.lock = asyncio.Lock()
        self.batch_queue = asyncio.Queue()
        
    async def add_log(self, log_entry):
        """Add a log entry to the current batch"""
        async with self.lock:
            self.current_batch.append(log_entry)
            
            # Check if we should flush
            should_flush = (
                len(self.current_batch) >= self.max_size or
                (time.time() - self.last_flush_time) * 1000 >= self.max_wait_ms
            )
            
            if should_flush:
                await self._flush_current_batch()
    
    async def get_batch(self) -> Optional[List]:
        """Get the next batch to process"""
        try:
            # Check time-based flush
            async with self.lock:
                if (self.current_batch and 
                    (time.time() - self.last_flush_time) * 1000 >= self.max_wait_ms):
                    await self._flush_current_batch()
            
            # Get batch from queue (with timeout)
            return await asyncio.wait_for(self.batch_queue.get(), timeout=0.1)
        except asyncio.TimeoutError:
            return None
    
    async def _flush_current_batch(self):
        """Flush the current batch to the queue"""
        if self.current_batch:
            batch_copy = self.current_batch.copy()
            self.current_batch.clear()
            self.last_flush_time = time.time()
            await self.batch_queue.put(batch_copy)
    
    async def flush_all(self):
        """Flush all remaining logs"""
        async with self.lock:
            if self.current_batch:
                await self._flush_current_batch()
