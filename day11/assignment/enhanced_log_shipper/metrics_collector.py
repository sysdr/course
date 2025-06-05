# assignment/enhanced_log_shipper/metrics_collector.py
import time
from typing import Dict, List, Any
import threading

class MetricsCollector:
    """Simple metrics collection for log batch operations."""
    
    def __init__(self):
        """Initialize metrics collector."""
        self._lock = threading.Lock()
        self._metrics = {
            'total_logs_sent': 0,
            'total_batches_sent': 0,
            'total_retries': 0,
            'total_failures': 0,
            'total_bytes_before_compression': 0,
            'total_bytes_after_compression': 0,
            'batch_sizes': [],
            'transmission_times': [],
            'compression_ratios': []
        }
    
    def record_batch_sent(self, batch_size: int, transmission_time: float,
                         bytes_before: int, bytes_after: int):
        """Record metrics for a successfully sent batch."""
        with self._lock:
            self._metrics['total_logs_sent'] += batch_size
            self._metrics['total_batches_sent'] += 1
            self._metrics['batch_sizes'].append(batch_size)
            self._metrics['transmission_times'].append(transmission_time)
            self._metrics['total_bytes_before_compression'] += bytes_before
            self._metrics['total_bytes_after_compression'] += bytes_after
            
            # Calculate compression ratio
            if bytes_before > 0:
                compression_ratio = bytes_after / bytes_before
                self._metrics['compression_ratios'].append(compression_ratio)
    
    def record_retry(self):
        """Record a retry attempt."""
        with self._lock:
            self._metrics['total_retries'] += 1
    
    def record_failure(self):
        """Record a failed transmission after retries."""
        with self._lock:
            self._metrics['total_failures'] += 1
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get a copy of the current metrics."""
        with self._lock:
            metrics_copy = self._metrics.copy()
            
            # Calculate averages for lists
            if metrics_copy['batch_sizes']:
                metrics_copy['avg_batch_size'] = sum(metrics_copy['batch_sizes']) / len(metrics_copy['batch_sizes'])
            else:
                metrics_copy['avg_batch_size'] = 0
                
            if metrics_copy['transmission_times']:
                metrics_copy['avg_transmission_time'] = sum(metrics_copy['transmission_times']) / len(metrics_copy['transmission_times'])
            else:
                metrics_copy['avg_transmission_time'] = 0
                
            if metrics_copy['compression_ratios']:
                metrics_copy['avg_compression_ratio'] = sum(metrics_copy['compression_ratios']) / len(metrics_copy['compression_ratios'])
                metrics_copy['avg_space_saving'] = 1 - metrics_copy['avg_compression_ratio']
            else:
                metrics_copy['avg_compression_ratio'] = 1.0
                metrics_copy['avg_space_saving'] = 0.0
                
        return metrics_copy