"""
Performance metrics collector for log enrichment pipeline.
Gathers real-time system performance data.
"""

import psutil
import time
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)


class PerformanceCollector:
    """
    Collects real-time performance metrics.
    
    Unlike system information, performance data changes frequently,
    so we use minimal caching and focus on efficient collection.
    """
    
    def __init__(self, cache_duration: float = 1.0):
        """
        Initialize performance collector.
        
        Args:
            cache_duration: How long to cache metrics in seconds
        """
        self._cache_duration = cache_duration
        self._last_collection: float = 0
        self._cached_metrics: Dict[str, Any] = {}
        
    def collect(self) -> Dict[str, Any]:
        """
        Collect current performance metrics.
        
        Returns:
            Dictionary containing performance data
        """
        current_time = time.time()
        
        # Use short-term caching to avoid overwhelming the system
        if current_time - self._last_collection > self._cache_duration:
            self._cached_metrics = self._collect_fresh_metrics()
            self._last_collection = current_time
            
        return self._cached_metrics.copy()
    
    def _collect_fresh_metrics(self) -> Dict[str, Any]:
        """Collect fresh performance metrics."""
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=None)
            cpu_count = psutil.cpu_count()
            
            # Memory metrics
            memory = psutil.virtual_memory()
            
            # Disk metrics for root partition
            disk = psutil.disk_usage('/')
            
            # Network metrics (basic)
            network = psutil.net_io_counters()
            
            return {
                'cpu_percent': round(cpu_percent, 1),
                'cpu_count': cpu_count,
                'memory_total_gb': round(memory.total / (1024**3), 2),
                'memory_used_gb': round(memory.used / (1024**3), 2),
                'memory_percent': round(memory.percent, 1),
                'disk_total_gb': round(disk.total / (1024**3), 2),
                'disk_used_gb': round(disk.used / (1024**3), 2),
                'disk_percent': round((disk.used / disk.total) * 100, 1),
                'network_bytes_sent': network.bytes_sent,
                'network_bytes_recv': network.bytes_recv,
                'load_average': self._get_load_average(),
                'uptime_seconds': time.time() - psutil.boot_time(),
            }
        except Exception as e:
            logger.warning(f"Failed to collect performance metrics: {e}")
            return {
                'cpu_percent': 0.0,
                'memory_percent': 0.0,
                'disk_percent': 0.0,
                'error': 'metrics_collection_failed'
            }
    
    def _get_load_average(self) -> Dict[str, float]:
        """Get system load average if available."""
        try:
            if hasattr(psutil, 'getloadavg'):
                load1, load5, load15 = psutil.getloadavg()
                return {
                    'load_1m': round(load1, 2),
                    'load_5m': round(load5, 2),
                    'load_15m': round(load15, 2)
                }
        except (AttributeError, OSError):
            pass
        return {'load_1m': 0.0, 'load_5m': 0.0, 'load_15m': 0.0}
