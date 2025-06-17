import asyncio
import heapq
import time
from dataclasses import dataclass, field
from enum import IntEnum
from typing import Any, Dict, List, Optional
import threading
from collections import defaultdict

class Priority(IntEnum):
    CRITICAL = 0  # Highest priority (lowest number)
    HIGH = 1
    MEDIUM = 2
    LOW = 3      # Lowest priority (highest number)

@dataclass
class Message:
    priority: Priority
    timestamp: float
    content: Dict[str, Any]
    message_id: str
    processing_attempts: int = 0
    
    def __lt__(self, other):
        # Primary sort by priority, secondary by timestamp
        if self.priority != other.priority:
            return self.priority < other.priority
        return self.timestamp < other.timestamp

class PriorityQueue:
    def __init__(self, max_size: int = 10000):
        self._queue = []
        self._lock = threading.RLock()
        self._max_size = max_size
        self._metrics = defaultdict(int)
        
    def put(self, message: Message) -> bool:
        """Thread-safe message insertion"""
        with self._lock:
            if len(self._queue) >= self._max_size:
                return False
            
            heapq.heappush(self._queue, message)
            self._metrics[f'queue_{message.priority.name.lower()}'] += 1
            self._metrics['total_messages'] += 1
            return True
    
    def get(self) -> Optional[Message]:
        """Thread-safe message retrieval"""
        with self._lock:
            if not self._queue:
                return None
            
            message = heapq.heappop(self._queue)
            self._metrics[f'processed_{message.priority.name.lower()}'] += 1
            return message
    
    def peek(self) -> Optional[Message]:
        """Look at highest priority message without removing it"""
        with self._lock:
            return self._queue[0] if self._queue else None
    
    def size(self) -> int:
        """Get current queue size"""
        with self._lock:
            return len(self._queue)
    
    def size_by_priority(self) -> Dict[Priority, int]:
        """Get queue size breakdown by priority"""
        with self._lock:
            counts = defaultdict(int)
            for message in self._queue:
                counts[message.priority] += 1
            return dict(counts)
    
    def get_metrics(self) -> Dict[str, int]:
        """Get processing metrics"""
        with self._lock:
            return dict(self._metrics)

class PriorityQueueManager:
    def __init__(self, num_workers: int = 4):
        self.queue = PriorityQueue()
        self.num_workers = num_workers
        self.workers = []
        self.running = False
        self.processed_messages = []
        
    async def start(self):
        """Start worker threads"""
        self.running = True
        self.workers = [
            asyncio.create_task(self._worker(f"worker-{i}"))
            for i in range(self.num_workers)
        ]
        
    async def stop(self):
        """Stop all workers"""
        self.running = False
        if self.workers:
            await asyncio.gather(*self.workers, return_exceptions=True)
        
    async def _worker(self, worker_id: str):
        """Worker coroutine for processing messages"""
        while self.running:
            message = self.queue.get()
            if message:
                # Simulate processing time based on priority
                processing_time = {
                    Priority.CRITICAL: 0.01,  # 10ms for critical
                    Priority.HIGH: 0.05,      # 50ms for high
                    Priority.MEDIUM: 0.1,     # 100ms for medium
                    Priority.LOW: 0.2         # 200ms for low
                }
                
                await asyncio.sleep(processing_time[message.priority])
                
                # Log processing
                self.processed_messages.append({
                    'worker_id': worker_id,
                    'message_id': message.message_id,
                    'priority': message.priority.name,
                    'processed_at': time.time(),
                    'processing_time': processing_time[message.priority]
                })
                
                print(f"[{worker_id}] Processed {message.priority.name} message: {message.message_id}")
            else:
                await asyncio.sleep(0.01)  # Prevent tight loop
