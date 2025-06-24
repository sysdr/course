import time
import threading
from typing import Dict, List
from collections import defaultdict, deque
from dataclasses import dataclass, asdict
import structlog

logger = structlog.get_logger()

@dataclass
class BatchMetrics:
    timestamp: float
    batch_size: int
    success_count: int
    processing_time: float
    throughput: float

class MetricsCollector:
    """Collect and expose consumer metrics"""
    
    def __init__(self):
        self.start_time = time.time()
        self.batch_metrics = deque(maxlen=1000)  # Keep last 1000 batches
        self.error_counts = defaultdict(int)
        self.lock = threading.Lock()
        
        # Aggregated metrics
        self.total_batches = 0
        self.total_messages = 0
        self.total_processing_time = 0
        self.total_errors = 0
        
    def record_batch_processed(self, batch_size: int, success_count: int, processing_time: float):
        """Record metrics for a processed batch"""
        with self.lock:
            throughput = success_count / processing_time if processing_time > 0 else 0
            
            metrics = BatchMetrics(
                timestamp=time.time(),
                batch_size=batch_size,
                success_count=success_count,
                processing_time=processing_time,
                throughput=throughput
            )
            
            self.batch_metrics.append(metrics)
            
            # Update aggregated metrics
            self.total_batches += 1
            self.total_messages += batch_size
            self.total_processing_time += processing_time
            self.total_errors += (batch_size - success_count)
            
    def record_error(self, error_type: str):
        """Record an error occurrence"""
        with self.lock:
            self.error_counts[error_type] += 1
            self.total_errors += 1
            
    def get_current_metrics(self) -> Dict:
        """Get current performance metrics"""
        with self.lock:
            current_time = time.time()
            uptime = current_time - self.start_time
            
            # Calculate averages
            avg_batch_size = self.total_messages / self.total_batches if self.total_batches > 0 else 0
            avg_processing_time = self.total_processing_time / self.total_batches if self.total_batches > 0 else 0
            overall_throughput = self.total_messages / uptime if uptime > 0 else 0
            
            # Recent performance (last 5 minutes)
            recent_cutoff = current_time - 300
            recent_batches = [m for m in self.batch_metrics if m.timestamp > recent_cutoff]
            
            if recent_batches:
                recent_throughput = sum(m.throughput for m in recent_batches) / len(recent_batches)
                recent_avg_time = sum(m.processing_time for m in recent_batches) / len(recent_batches)
            else:
                recent_throughput = 0
                recent_avg_time = 0
                
            # Error rate
            error_rate = (self.total_errors / self.total_messages) * 100 if self.total_messages > 0 else 0
            
            return {
                'uptime_seconds': uptime,
                'total_batches': self.total_batches,
                'total_messages': self.total_messages,
                'total_errors': self.total_errors,
                'error_rate_percent': error_rate,
                'avg_batch_size': avg_batch_size,
                'avg_processing_time_seconds': avg_processing_time,
                'overall_throughput_msg_per_sec': overall_throughput,
                'recent_throughput_msg_per_sec': recent_throughput,
                'recent_avg_processing_time': recent_avg_time,
                'error_breakdown': dict(self.error_counts)
            }
            
    def get_recent_batches(self, limit: int = 100) -> List[Dict]:
        """Get recent batch metrics"""
        with self.lock:
            recent = list(self.batch_metrics)[-limit:]
            return [asdict(batch) for batch in recent]
