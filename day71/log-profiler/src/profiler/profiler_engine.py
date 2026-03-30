import time
import psutil
import threading
import asyncio
from typing import Dict, List, Any, Optional, Callable
from dataclasses import dataclass, asdict
from datetime import datetime
import json
import tracemalloc
from memory_profiler import profile
import structlog

logger = structlog.get_logger()

@dataclass
class PerformanceMetrics:
    timestamp: float
    cpu_percent: float
    memory_percent: float
    memory_mb: float
    disk_io_read_mb: float
    disk_io_write_mb: float
    network_sent_mb: float
    network_recv_mb: float
    active_threads: int
    function_name: str = ""
    execution_time_ms: float = 0.0

class ProfilerEngine:
    def __init__(self, config):
        self.config = config
        self.metrics_history: List[PerformanceMetrics] = []
        self.is_profiling = False
        self.profiling_thread = None
        self.function_timings = {}
        self.bottlenecks = []
        
        # Start memory tracing
        if config.enable_memory_profiling:
            tracemalloc.start()
    
    def start_profiling(self):
        """Start continuous system profiling"""
        self.is_profiling = True
        self.profiling_thread = threading.Thread(target=self._profiling_loop)
        self.profiling_thread.daemon = True
        self.profiling_thread.start()
        logger.info("Profiling started")
    
    def stop_profiling(self):
        """Stop profiling and return collected metrics"""
        self.is_profiling = False
        if self.profiling_thread:
            self.profiling_thread.join()
        logger.info("Profiling stopped")
        return self.get_metrics_summary()
    
    def _profiling_loop(self):
        """Continuous profiling loop"""
        process = psutil.Process()
        
        while self.is_profiling:
            try:
                # Collect system metrics (interval avoids psutil's first-call 0.0 CPU reading)
                metrics = PerformanceMetrics(
                    timestamp=time.time(),
                    cpu_percent=process.cpu_percent(interval=0.1),
                    memory_percent=process.memory_percent(),
                    memory_mb=process.memory_info().rss / 1024 / 1024,
                    disk_io_read_mb=process.io_counters().read_bytes / 1024 / 1024,
                    disk_io_write_mb=process.io_counters().write_bytes / 1024 / 1024,
                    network_sent_mb=0,  # Simplified for demo
                    network_recv_mb=0,
                    active_threads=process.num_threads()
                )
                
                self.metrics_history.append(metrics)
                
                # Keep only recent metrics
                if len(self.metrics_history) > self.config.max_memory_samples:
                    self.metrics_history = self.metrics_history[-self.config.max_memory_samples:]
                
                # Check for performance issues
                self._detect_bottlenecks(metrics)
                
                time.sleep(self.config.sampling_interval)
            except Exception as e:
                logger.error(f"Profiling error: {e}")
    
    def _detect_bottlenecks(self, metrics: PerformanceMetrics):
        """Detect performance bottlenecks"""
        if metrics.cpu_percent > self.config.cpu_threshold:
            self.bottlenecks.append({
                'type': 'cpu',
                'severity': 'high' if metrics.cpu_percent > 90 else 'medium',
                'value': metrics.cpu_percent,
                'timestamp': metrics.timestamp,
                'recommendation': 'Consider optimizing CPU-intensive operations'
            })
        
        if metrics.memory_percent > self.config.memory_threshold:
            self.bottlenecks.append({
                'type': 'memory',
                'severity': 'high' if metrics.memory_percent > 95 else 'medium',
                'value': metrics.memory_percent,
                'timestamp': metrics.timestamp,
                'recommendation': 'Consider implementing memory pooling or reducing allocations'
            })
    
    def profile_function(self, func: Callable, *args, **kwargs):
        """Profile a specific function execution"""
        start_time = time.time()
        start_memory = psutil.Process().memory_info().rss
        
        try:
            result = func(*args, **kwargs)
            success = True
        except Exception as e:
            result = None
            success = False
            logger.error(f"Function {func.__name__} failed: {e}")
        
        end_time = time.time()
        end_memory = psutil.Process().memory_info().rss
        
        execution_time = (end_time - start_time) * 1000  # Convert to ms
        memory_delta = (end_memory - start_memory) / 1024 / 1024  # Convert to MB
        
        function_profile = {
            'function_name': func.__name__,
            'execution_time_ms': execution_time,
            'memory_delta_mb': memory_delta,
            'success': success,
            'timestamp': start_time
        }
        
        # Store function timing
        if func.__name__ not in self.function_timings:
            self.function_timings[func.__name__] = []
        
        self.function_timings[func.__name__].append(function_profile)
        
        return result, function_profile
    
    def get_metrics_summary(self) -> Dict[str, Any]:
        """Get comprehensive metrics summary"""
        if not self.metrics_history:
            return {}
        
        recent_metrics = self.metrics_history[-100:]  # Last 100 samples
        
        avg_cpu = sum(m.cpu_percent for m in recent_metrics) / len(recent_metrics)
        avg_memory = sum(m.memory_percent for m in recent_metrics) / len(recent_metrics)
        max_memory = max(m.memory_mb for m in recent_metrics)
        
        return {
            'summary': {
                'avg_cpu_percent': round(avg_cpu, 2),
                'avg_memory_percent': round(avg_memory, 2),
                'max_memory_mb': round(max_memory, 2),
                'total_samples': len(self.metrics_history),
                'profiling_duration_seconds': time.time() - self.metrics_history[0].timestamp if self.metrics_history else 0
            },
            'bottlenecks': self.bottlenecks[-10:],  # Last 10 bottlenecks
            'function_timings': {
                name: {
                    'count': len(timings),
                    'avg_time_ms': sum(t['execution_time_ms'] for t in timings) / len(timings),
                    'max_time_ms': max(t['execution_time_ms'] for t in timings),
                    'total_memory_mb': sum(t['memory_delta_mb'] for t in timings)
                }
                for name, timings in self.function_timings.items()
            },
            'raw_metrics': [asdict(m) for m in recent_metrics[-50:]]  # Last 50 raw metrics
        }

# Decorator for easy function profiling
def profile_performance(profiler_engine):
    def decorator(func):
        def wrapper(*args, **kwargs):
            if profiler_engine.is_profiling:
                result, profile_data = profiler_engine.profile_function(func, *args, **kwargs)
                return result
            else:
                return func(*args, **kwargs)
        return wrapper
    return decorator
