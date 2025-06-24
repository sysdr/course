import time
from typing import Dict, Any
from collections import deque
import asyncio

class HealthMonitor:
    def __init__(self):
        self.logs_received = 0
        self.logs_published = 0
        self.logs_failed = 0
        self.batch_count = 0
        self.start_time = time.time()
        
        # Sliding window for metrics (last 60 seconds)
        self.recent_logs = deque(maxlen=60)
        self.recent_batches = deque(maxlen=60)
        
    def record_log_received(self):
        """Record a log received"""
        self.logs_received += 1
        current_time = int(time.time())
        self.recent_logs.append(current_time)
    
    def record_batch_published(self, log_count: int, duration: float):
        """Record a successful batch publication"""
        self.logs_published += log_count
        self.batch_count += 1
        current_time = int(time.time())
        self.recent_batches.append({
            'timestamp': current_time,
            'log_count': log_count,
            'duration': duration
        })
    
    def record_batch_failed(self, log_count: int):
        """Record a failed batch"""
        self.logs_failed += log_count
    
    async def get_health_status(self) -> Dict[str, Any]:
        """Get current health status"""
        uptime = time.time() - self.start_time
        
        # Calculate recent throughput
        current_time = int(time.time())
        recent_log_count = sum(1 for t in self.recent_logs if current_time - t <= 60)
        recent_batch_count = sum(1 for b in self.recent_batches if current_time - b['timestamp'] <= 60)
        
        # Health determination
        healthy = (
            self.logs_failed / max(self.logs_received, 1) < 0.05 and  # Less than 5% failure rate
            recent_log_count > 0 if uptime > 60 else True  # Has recent activity if running > 1 min
        )
        
        return {
            'healthy': healthy,
            'uptime_seconds': uptime,
            'logs_received': self.logs_received,
            'logs_published': self.logs_published,
            'logs_failed': self.logs_failed,
            'recent_logs_per_minute': recent_log_count,
            'recent_batches_per_minute': recent_batch_count,
            'failure_rate': self.logs_failed / max(self.logs_received, 1)
        }
    
    async def get_metrics(self) -> Dict[str, Any]:
        """Get detailed metrics"""
        health_status = await self.get_health_status()
        
        # Calculate average batch metrics
        recent_batches = [b for b in self.recent_batches if time.time() - b['timestamp'] <= 60]
        avg_batch_size = sum(b['log_count'] for b in recent_batches) / max(len(recent_batches), 1)
        avg_batch_duration = sum(b['duration'] for b in recent_batches) / max(len(recent_batches), 1)
        
        return {
            **health_status,
            'average_batch_size': avg_batch_size,
            'average_batch_duration_ms': avg_batch_duration * 1000,
            'total_batches': self.batch_count
        }
