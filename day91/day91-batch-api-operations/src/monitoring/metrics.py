import asyncio
import time
from typing import Dict, Any, List
from dataclasses import dataclass, field
from datetime import datetime, timezone
import psutil
import threading

from ..models.log_models import BatchStats

@dataclass
class OperationMetric:
    operation_type: str
    timestamp: float
    batch_size: int
    processing_time: float
    success_count: int
    
@dataclass
class SystemMetrics:
    cpu_percent: float = 0.0
    memory_percent: float = 0.0
    disk_io: Dict[str, Any] = field(default_factory=dict)
    network_io: Dict[str, Any] = field(default_factory=dict)

class MetricsCollector:
    def __init__(self):
        self.operations: List[OperationMetric] = []
        self.system_metrics: SystemMetrics = SystemMetrics()
        self.collection_active = False
        self.lock = threading.Lock()
        
    def start_collection(self):
        """Start background metrics collection"""
        self.collection_active = True
        threading.Thread(target=self._collect_system_metrics, daemon=True).start()
        
    def stop_collection(self):
        """Stop metrics collection"""
        self.collection_active = False
        
    def _collect_system_metrics(self):
        """Background thread to collect system metrics"""
        while self.collection_active:
            try:
                self.system_metrics.cpu_percent = psutil.cpu_percent()
                self.system_metrics.memory_percent = psutil.virtual_memory().percent
                self.system_metrics.disk_io = psutil.disk_io_counters()._asdict() if psutil.disk_io_counters() else {}
                self.system_metrics.network_io = psutil.net_io_counters()._asdict() if psutil.net_io_counters() else {}
            except Exception as e:
                print(f"⚠️ Metrics collection error: {e}")
            
            time.sleep(5)  # Collect every 5 seconds
    
    async def record_batch_operation(
        self,
        operation_type: str,
        batch_size: int,
        processing_time: float,
        success_count: int
    ):
        """Record a batch operation metric"""
        with self.lock:
            metric = OperationMetric(
                operation_type=operation_type,
                timestamp=time.time(),
                batch_size=batch_size,
                processing_time=processing_time,
                success_count=success_count
            )
            self.operations.append(metric)
            
            # Keep only last 1000 operations
            if len(self.operations) > 1000:
                self.operations = self.operations[-1000:]
    
    async def get_batch_stats(self) -> BatchStats:
        """Get aggregated batch statistics"""
        with self.lock:
            if not self.operations:
                return BatchStats()
            
            total_batches = len(self.operations)
            total_logs = sum(op.batch_size for op in self.operations)
            total_processing_time = sum(op.processing_time for op in self.operations)
            total_success = sum(op.success_count for op in self.operations)
            
            # Calculate recent throughput (last 60 seconds)
            recent_time = time.time() - 60
            recent_ops = [op for op in self.operations if op.timestamp > recent_time]
            recent_logs = sum(op.success_count for op in recent_ops)
            
            return BatchStats(
                total_batches_processed=total_batches,
                total_logs_processed=total_logs,
                average_batch_size=total_logs / total_batches if total_batches > 0 else 0,
                average_processing_time=total_processing_time / total_batches if total_batches > 0 else 0,
                success_rate=(total_success / total_logs * 100) if total_logs > 0 else 0,
                throughput_per_second=recent_logs / 60 if recent_logs > 0 else 0,
                current_queue_size=0  # Would be actual queue size in production
            )
    
    async def get_current_stats(self) -> Dict[str, Any]:
        """Get current system and batch statistics"""
        batch_stats = await self.get_batch_stats()
        
        return {
            "batch_stats": batch_stats.dict(),
            "system_metrics": {
                "cpu_percent": self.system_metrics.cpu_percent,
                "memory_percent": self.system_metrics.memory_percent,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            "recent_operations": [
                {
                    "type": op.operation_type,
                    "batch_size": op.batch_size,
                    "processing_time": op.processing_time,
                    "timestamp": op.timestamp
                }
                for op in self.operations[-10:]  # Last 10 operations
            ]
        }
    
    def is_healthy(self) -> bool:
        """Check if metrics collection is healthy"""
        return self.collection_active
