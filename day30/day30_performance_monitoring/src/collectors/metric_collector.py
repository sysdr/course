import asyncio
import psutil
import time
import json
import logging
from datetime import datetime
from typing import Dict, Any, List
from dataclasses import dataclass, asdict

@dataclass
class MetricPoint:
    """Single metric data point"""
    timestamp: float
    node_id: str
    metric_name: str
    value: float
    labels: Dict[str, str] = None

class SystemMetricsCollector:
    """Collects system-level performance metrics"""
    
    def __init__(self, node_id: str):
        self.node_id = node_id
        self.logger = logging.getLogger(__name__)
        
    async def collect_cpu_metrics(self) -> List[MetricPoint]:
        """Collect CPU usage metrics"""
        cpu_percent = psutil.cpu_percent(interval=1, percpu=True)
        timestamp = time.time()
        
        metrics = []
        for i, usage in enumerate(cpu_percent):
            metrics.append(MetricPoint(
                timestamp=timestamp,
                node_id=self.node_id,
                metric_name="cpu_usage",
                value=usage,
                labels={"core": str(i)}
            ))
            
        # Add overall CPU metric
        overall_cpu = sum(cpu_percent) / len(cpu_percent)
        metrics.append(MetricPoint(
            timestamp=timestamp,
            node_id=self.node_id,
            metric_name="cpu_usage_total",
            value=overall_cpu
        ))
        
        return metrics
    
    async def collect_memory_metrics(self) -> List[MetricPoint]:
        """Collect memory usage metrics"""
        memory = psutil.virtual_memory()
        timestamp = time.time()
        
        return [
            MetricPoint(
                timestamp=timestamp,
                node_id=self.node_id,
                metric_name="memory_usage",
                value=memory.percent
            ),
            MetricPoint(
                timestamp=timestamp,
                node_id=self.node_id,
                metric_name="memory_available",
                value=memory.available / (1024**3)  # GB
            )
        ]
    
    async def collect_disk_metrics(self) -> List[MetricPoint]:
        """Collect disk I/O metrics"""
        disk_io = psutil.disk_io_counters()
        disk_usage = psutil.disk_usage('/')
        timestamp = time.time()
        
        return [
            MetricPoint(
                timestamp=timestamp,
                node_id=self.node_id,
                metric_name="disk_read_bytes",
                value=disk_io.read_bytes
            ),
            MetricPoint(
                timestamp=timestamp,
                node_id=self.node_id,
                metric_name="disk_write_bytes",
                value=disk_io.write_bytes
            ),
            MetricPoint(
                timestamp=timestamp,
                node_id=self.node_id,
                metric_name="disk_usage_percent",
                value=(disk_usage.used / disk_usage.total) * 100
            )
        ]
    
    async def collect_network_metrics(self) -> List[MetricPoint]:
        """Collect network I/O metrics"""
        net_io = psutil.net_io_counters()
        timestamp = time.time()
        
        return [
            MetricPoint(
                timestamp=timestamp,
                node_id=self.node_id,
                metric_name="network_bytes_sent",
                value=net_io.bytes_sent
            ),
            MetricPoint(
                timestamp=timestamp,
                node_id=self.node_id,
                metric_name="network_bytes_recv",
                value=net_io.bytes_recv
            )
        ]

class ApplicationMetricsCollector:
    """Collects application-specific performance metrics"""
    
    def __init__(self, node_id: str):
        self.node_id = node_id
        self.logger = logging.getLogger(__name__)
        self.write_latencies = []
        self.read_latencies = []
        self.throughput_counter = 0
        
    def record_write_latency(self, latency_ms: float):
        """Record write operation latency"""
        self.write_latencies.append(latency_ms)
        self.throughput_counter += 1
        
    def record_read_latency(self, latency_ms: float):
        """Record read operation latency"""
        self.read_latencies.append(latency_ms)
        
    async def collect_latency_metrics(self) -> List[MetricPoint]:
        """Collect latency metrics"""
        timestamp = time.time()
        metrics = []
        
        if self.write_latencies:
            avg_write_latency = sum(self.write_latencies) / len(self.write_latencies)
            p99_write_latency = sorted(self.write_latencies)[int(0.99 * len(self.write_latencies))]
            
            metrics.extend([
                MetricPoint(
                    timestamp=timestamp,
                    node_id=self.node_id,
                    metric_name="write_latency_avg",
                    value=avg_write_latency
                ),
                MetricPoint(
                    timestamp=timestamp,
                    node_id=self.node_id,
                    metric_name="write_latency_p99",
                    value=p99_write_latency
                )
            ])
            self.write_latencies.clear()
            
        if self.read_latencies:
            avg_read_latency = sum(self.read_latencies) / len(self.read_latencies)
            metrics.append(MetricPoint(
                timestamp=timestamp,
                node_id=self.node_id,
                metric_name="read_latency_avg",
                value=avg_read_latency
            ))
            self.read_latencies.clear()
            
        return metrics
    
    async def collect_throughput_metrics(self) -> List[MetricPoint]:
        """Collect throughput metrics"""
        timestamp = time.time()
        current_throughput = self.throughput_counter
        self.throughput_counter = 0
        
        return [
            MetricPoint(
                timestamp=timestamp,
                node_id=self.node_id,
                metric_name="operations_per_second",
                value=current_throughput
            )
        ]

class MetricsCollector:
    """Main metrics collector that orchestrates all metric collection"""
    
    def __init__(self, node_id: str, config: Dict[str, Any]):
        self.node_id = node_id
        self.config = config
        self.system_collector = SystemMetricsCollector(node_id)
        self.app_collector = ApplicationMetricsCollector(node_id)
        self.running = False
        self.logger = logging.getLogger(__name__)
        
    async def collect_all_metrics(self) -> List[MetricPoint]:
        """Collect all available metrics"""
        all_metrics = []
        
        # Collect system metrics
        all_metrics.extend(await self.system_collector.collect_cpu_metrics())
        all_metrics.extend(await self.system_collector.collect_memory_metrics())
        all_metrics.extend(await self.system_collector.collect_disk_metrics())
        all_metrics.extend(await self.system_collector.collect_network_metrics())
        
        # Collect application metrics
        all_metrics.extend(await self.app_collector.collect_latency_metrics())
        all_metrics.extend(await self.app_collector.collect_throughput_metrics())
        
        return all_metrics
    
    async def start_collection(self, metric_queue: asyncio.Queue):
        """Start continuous metric collection"""
        self.running = True
        interval = self.config.get('collection_interval', 5)
        
        while self.running:
            try:
                metrics = await self.collect_all_metrics()
                for metric in metrics:
                    await metric_queue.put(metric)
                await asyncio.sleep(interval)
            except Exception as e:
                self.logger.error(f"Error collecting metrics: {e}")
                await asyncio.sleep(interval)
    
    def stop_collection(self):
        """Stop metric collection"""
        self.running = False
