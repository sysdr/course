#!/bin/bash

# Day 30: Cluster Performance Monitoring Implementation Script
# Creates a complete performance monitoring system for distributed log storage

set -e

echo "🚀 Setting up Day 30: Cluster Performance Monitoring System"

# Create project structure
mkdir -p day30_performance_monitoring/{src/{collectors,aggregators,analyzers,dashboard},tests,config,logs,data,docker}

# Create web dashboard static directory (required for aiohttp static file serving)
mkdir -p day30_performance_monitoring/src/dashboard/static

# Create a placeholder file to ensure the directory is preserved in version control
touch day30_performance_monitoring/src/dashboard/static/.gitkeep
cd day30_performance_monitoring

# Create requirements.txt
cat > requirements.txt << 'EOF'
asyncio==3.4.3
aiohttp_cors==0.7.0
aiohttp==3.9.5
aiofiles==23.2.1
psutil==5.9.8
prometheus-client==0.20.0
matplotlib==3.8.4
plotly==5.19.0
pandas==2.2.2
numpy==1.26.4
pyyaml==6.0.1
jinja2==3.1.4
websockets==12.0
uvloop==0.19.0
pytest==8.1.1
pytest-asyncio==0.23.6
pytest-cov==5.0.0
flask==3.0.3
bokeh==3.4.1
EOF

# Create main configuration
cat > config/monitoring_config.yaml << 'EOF'
monitoring:
  collection_interval: 5  # seconds
  retention_period: 86400  # 24 hours in seconds
  
cluster:
  nodes:
    - id: "node-1"
      host: "localhost"
      port: 8001
      role: "primary"
    - id: "node-2"
      host: "localhost"
      port: 8002
      role: "replica"
    - id: "node-3"
      host: "localhost"
      port: 8003
      role: "replica"

metrics:
  system:
    - cpu_usage
    - memory_usage
    - disk_io
    - network_io
  application:
    - log_write_latency
    - log_read_latency
    - replication_lag
    - throughput
  thresholds:
    cpu_warning: 70
    cpu_critical: 90
    memory_warning: 80
    memory_critical: 95
    latency_warning: 100  # ms
    latency_critical: 500  # ms

dashboard:
  host: "0.0.0.0"
  port: 8080
  refresh_interval: 10
EOF

# Create metric collector
cat > src/collectors/metric_collector.py << 'EOF'
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
EOF

# Create metrics aggregator
cat > src/aggregators/metrics_aggregator.py << 'EOF'
import asyncio
import json
import time
import statistics
from typing import Dict, List, Any
from collections import defaultdict, deque
from datetime import datetime, timedelta
from src.collectors.metric_collector import MetricPoint

class MetricsAggregator:
    """Aggregates metrics from multiple nodes and time periods"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.retention_period = config.get('retention_period', 86400)  # 24 hours
        self.metrics_buffer = defaultdict(lambda: deque(maxlen=1000))
        self.aggregated_metrics = {}
        self.running = False
        
    async def process_metrics(self, metric_queue: asyncio.Queue):
        """Process incoming metrics from collectors"""
        self.running = True
        
        while self.running:
            try:
                # Get metric from queue with timeout
                metric = await asyncio.wait_for(metric_queue.get(), timeout=1.0)
                await self._store_metric(metric)
                metric_queue.task_done()
            except asyncio.TimeoutError:
                continue
            except Exception as e:
                print(f"Error processing metric: {e}")
    
    async def _store_metric(self, metric: MetricPoint):
        """Store individual metric point"""
        key = f"{metric.node_id}:{metric.metric_name}"
        self.metrics_buffer[key].append(metric)
        
        # Clean old metrics
        await self._cleanup_old_metrics()
    
    async def _cleanup_old_metrics(self):
        """Remove metrics older than retention period"""
        cutoff_time = time.time() - self.retention_period
        
        for key, metrics in self.metrics_buffer.items():
            while metrics and metrics[0].timestamp < cutoff_time:
                metrics.popleft()
    
    async def aggregate_cluster_metrics(self, time_window: int = 300) -> Dict[str, Any]:
        """Aggregate metrics across the cluster for a time window"""
        end_time = time.time()
        start_time = end_time - time_window
        
        cluster_metrics = {
            'timestamp': end_time,
            'time_window': time_window,
            'nodes': {},
            'cluster_totals': {}
        }
        
        # Group metrics by node and metric type
        node_metrics = defaultdict(lambda: defaultdict(list))
        
        for key, metrics in self.metrics_buffer.items():
            node_id, metric_name = key.split(':', 1)
            
            # Filter metrics within time window
            window_metrics = [
                m for m in metrics 
                if start_time <= m.timestamp <= end_time
            ]
            
            if window_metrics:
                values = [m.value for m in window_metrics]
                node_metrics[node_id][metric_name] = values
        
        # Calculate aggregations for each node
        for node_id, metrics in node_metrics.items():
            node_aggregations = {}
            
            for metric_name, values in metrics.items():
                if values:
                    node_aggregations[metric_name] = {
                        'min': min(values),
                        'max': max(values),
                        'avg': sum(values) / len(values),
                        'median': statistics.median(values),
                        'count': len(values)
                    }
                    
                    if len(values) > 1:
                        node_aggregations[metric_name]['std'] = statistics.stdev(values)
                        
                    # Calculate percentiles for latency metrics
                    if 'latency' in metric_name:
                        sorted_values = sorted(values)
                        p95_idx = int(0.95 * len(sorted_values))
                        p99_idx = int(0.99 * len(sorted_values))
                        node_aggregations[metric_name]['p95'] = sorted_values[p95_idx]
                        node_aggregations[metric_name]['p99'] = sorted_values[p99_idx]
            
            cluster_metrics['nodes'][node_id] = node_aggregations
        
        # Calculate cluster-wide totals
        await self._calculate_cluster_totals(cluster_metrics)
        
        return cluster_metrics
    
    async def _calculate_cluster_totals(self, cluster_metrics: Dict[str, Any]):
        """Calculate cluster-wide aggregate metrics"""
        cluster_totals = {}
        all_nodes = cluster_metrics['nodes']
        
        if not all_nodes:
            return
        
        # Aggregate CPU usage across all nodes
        cpu_values = []
        memory_values = []
        throughput_values = []
        
        for node_metrics in all_nodes.values():
            if 'cpu_usage_total' in node_metrics:
                cpu_values.append(node_metrics['cpu_usage_total']['avg'])
            if 'memory_usage' in node_metrics:
                memory_values.append(node_metrics['memory_usage']['avg'])
            if 'operations_per_second' in node_metrics:
                throughput_values.append(node_metrics['operations_per_second']['avg'])
        
        if cpu_values:
            cluster_totals['avg_cpu_usage'] = sum(cpu_values) / len(cpu_values)
            cluster_totals['max_cpu_usage'] = max(cpu_values)
            
        if memory_values:
            cluster_totals['avg_memory_usage'] = sum(memory_values) / len(memory_values)
            cluster_totals['max_memory_usage'] = max(memory_values)
            
        if throughput_values:
            cluster_totals['total_throughput'] = sum(throughput_values)
            cluster_totals['avg_node_throughput'] = sum(throughput_values) / len(throughput_values)
        
        cluster_metrics['cluster_totals'] = cluster_totals
    
    async def get_metric_history(self, node_id: str, metric_name: str, 
                                hours: int = 1) -> List[Dict[str, Any]]:
        """Get historical data for a specific metric"""
        key = f"{node_id}:{metric_name}"
        cutoff_time = time.time() - (hours * 3600)
        
        if key not in self.metrics_buffer:
            return []
        
        return [
            {
                'timestamp': metric.timestamp,
                'value': metric.value,
                'labels': metric.labels or {}
            }
            for metric in self.metrics_buffer[key]
            if metric.timestamp >= cutoff_time
        ]
    
    def stop(self):
        """Stop metrics aggregation"""
        self.running = False
EOF

# Create performance analyzer
cat > src/analyzers/performance_analyzer.py << 'EOF'
import asyncio
import json
import time
import statistics
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass
from enum import Enum

class AlertLevel(Enum):
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"

@dataclass
class PerformanceAlert:
    timestamp: float
    node_id: str
    metric_name: str
    current_value: float
    threshold_value: float
    level: AlertLevel
    message: str

class PerformanceAnalyzer:
    """Analyzes performance metrics and generates alerts and reports"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.thresholds = config.get('metrics', {}).get('thresholds', {})
        self.alerts = []
        self.running = False
        
    async def analyze_cluster_performance(self, aggregated_metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze cluster performance and generate insights"""
        analysis = {
            'timestamp': time.time(),
            'overall_health': 'healthy',
            'alerts': [],
            'performance_summary': {},
            'recommendations': []
        }
        
        # Analyze each node's performance
        node_alerts = []
        for node_id, node_metrics in aggregated_metrics.get('nodes', {}).items():
            alerts = await self._analyze_node_performance(node_id, node_metrics)
            node_alerts.extend(alerts)
        
        # Analyze cluster-wide metrics
        cluster_alerts = await self._analyze_cluster_metrics(aggregated_metrics.get('cluster_totals', {}))
        node_alerts.extend(cluster_alerts)
        
        # Determine overall health
        critical_alerts = [a for a in node_alerts if a.level == AlertLevel.CRITICAL]
        warning_alerts = [a for a in node_alerts if a.level == AlertLevel.WARNING]
        
        if critical_alerts:
            analysis['overall_health'] = 'critical'
        elif warning_alerts:
            analysis['overall_health'] = 'warning'
        
        analysis['alerts'] = [
            {
                'timestamp': alert.timestamp,
                'node_id': alert.node_id,
                'metric': alert.metric_name,
                'level': alert.level.value,
                'message': alert.message,
                'current_value': alert.current_value,
                'threshold': alert.threshold_value
            }
            for alert in node_alerts
        ]
        
        # Generate performance summary
        analysis['performance_summary'] = await self._generate_performance_summary(aggregated_metrics)
        
        # Generate recommendations
        analysis['recommendations'] = await self._generate_recommendations(node_alerts, aggregated_metrics)
        
        return analysis
    
    async def _analyze_node_performance(self, node_id: str, node_metrics: Dict[str, Any]) -> List[PerformanceAlert]:
        """Analyze individual node performance"""
        alerts = []
        timestamp = time.time()
        
        # Check CPU usage
        if 'cpu_usage_total' in node_metrics:
            cpu_avg = node_metrics['cpu_usage_total']['avg']
            if cpu_avg >= self.thresholds.get('cpu_critical', 90):
                alerts.append(PerformanceAlert(
                    timestamp=timestamp,
                    node_id=node_id,
                    metric_name='cpu_usage',
                    current_value=cpu_avg,
                    threshold_value=self.thresholds.get('cpu_critical', 90),
                    level=AlertLevel.CRITICAL,
                    message=f"Critical CPU usage: {cpu_avg:.1f}%"
                ))
            elif cpu_avg >= self.thresholds.get('cpu_warning', 70):
                alerts.append(PerformanceAlert(
                    timestamp=timestamp,
                    node_id=node_id,
                    metric_name='cpu_usage',
                    current_value=cpu_avg,
                    threshold_value=self.thresholds.get('cpu_warning', 70),
                    level=AlertLevel.WARNING,
                    message=f"High CPU usage: {cpu_avg:.1f}%"
                ))
        
        # Check Memory usage
        if 'memory_usage' in node_metrics:
            memory_avg = node_metrics['memory_usage']['avg']
            if memory_avg >= self.thresholds.get('memory_critical', 95):
                alerts.append(PerformanceAlert(
                    timestamp=timestamp,
                    node_id=node_id,
                    metric_name='memory_usage',
                    current_value=memory_avg,
                    threshold_value=self.thresholds.get('memory_critical', 95),
                    level=AlertLevel.CRITICAL,
                    message=f"Critical memory usage: {memory_avg:.1f}%"
                ))
            elif memory_avg >= self.thresholds.get('memory_warning', 80):
                alerts.append(PerformanceAlert(
                    timestamp=timestamp,
                    node_id=node_id,
                    metric_name='memory_usage',
                    current_value=memory_avg,
                    threshold_value=self.thresholds.get('memory_warning', 80),
                    level=AlertLevel.WARNING,
                    message=f"High memory usage: {memory_avg:.1f}%"
                ))
        
        # Check Write latency
        if 'write_latency_avg' in node_metrics:
            latency_avg = node_metrics['write_latency_avg']['avg']
            if latency_avg >= self.thresholds.get('latency_critical', 500):
                alerts.append(PerformanceAlert(
                    timestamp=timestamp,
                    node_id=node_id,
                    metric_name='write_latency',
                    current_value=latency_avg,
                    threshold_value=self.thresholds.get('latency_critical', 500),
                    level=AlertLevel.CRITICAL,
                    message=f"Critical write latency: {latency_avg:.1f}ms"
                ))
            elif latency_avg >= self.thresholds.get('latency_warning', 100):
                alerts.append(PerformanceAlert(
                    timestamp=timestamp,
                    node_id=node_id,
                    metric_name='write_latency',
                    current_value=latency_avg,
                    threshold_value=self.thresholds.get('latency_warning', 100),
                    level=AlertLevel.WARNING,
                    message=f"High write latency: {latency_avg:.1f}ms"
                ))
        
        return alerts
    
    async def _analyze_cluster_metrics(self, cluster_totals: Dict[str, Any]) -> List[PerformanceAlert]:
        """Analyze cluster-wide metrics"""
        alerts = []
        timestamp = time.time()
        
        # Check cluster average CPU
        if 'avg_cpu_usage' in cluster_totals:
            avg_cpu = cluster_totals['avg_cpu_usage']
            if avg_cpu >= 80:
                alerts.append(PerformanceAlert(
                    timestamp=timestamp,
                    node_id='cluster',
                    metric_name='cluster_cpu_usage',
                    current_value=avg_cpu,
                    threshold_value=80,
                    level=AlertLevel.WARNING,
                    message=f"Cluster average CPU usage high: {avg_cpu:.1f}%"
                ))
        
        # Check total throughput trends
        if 'total_throughput' in cluster_totals:
            throughput = cluster_totals['total_throughput']
            if throughput < 10:  # Very low throughput
                alerts.append(PerformanceAlert(
                    timestamp=timestamp,
                    node_id='cluster',
                    metric_name='cluster_throughput',
                    current_value=throughput,
                    threshold_value=10,
                    level=AlertLevel.WARNING,
                    message=f"Low cluster throughput: {throughput:.1f} ops/sec"
                ))
        
        return alerts
    
    async def _generate_performance_summary(self, metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Generate high-level performance summary"""
        cluster_totals = metrics.get('cluster_totals', {})
        nodes = metrics.get('nodes', {})
        
        summary = {
            'active_nodes': len(nodes),
            'cluster_cpu_avg': cluster_totals.get('avg_cpu_usage', 0),
            'cluster_memory_avg': cluster_totals.get('avg_memory_usage', 0),
            'total_throughput': cluster_totals.get('total_throughput', 0),
            'performance_score': 100  # Start with perfect score
        }
        
        # Calculate performance score (0-100)
        score = 100
        
        # Deduct points for high resource usage
        if summary['cluster_cpu_avg'] > 70:
            score -= (summary['cluster_cpu_avg'] - 70) * 2
        if summary['cluster_memory_avg'] > 80:
            score -= (summary['cluster_memory_avg'] - 80) * 3
        
        # Deduct points for low throughput
        if summary['total_throughput'] < 50:
            score -= (50 - summary['total_throughput']) * 0.5
        
        summary['performance_score'] = max(0, min(100, score))
        
        return summary
    
    async def _generate_recommendations(self, alerts: List[PerformanceAlert], 
                                      metrics: Dict[str, Any]) -> List[str]:
        """Generate performance optimization recommendations"""
        recommendations = []
        
        # Analyze alert patterns
        critical_alerts = [a for a in alerts if a.level == AlertLevel.CRITICAL]
        warning_alerts = [a for a in alerts if a.level == AlertLevel.WARNING]
        
        # CPU-related recommendations
        cpu_alerts = [a for a in alerts if 'cpu' in a.metric_name]
        if cpu_alerts:
            recommendations.append("Consider scaling horizontally by adding more nodes to distribute CPU load")
            recommendations.append("Review application code for CPU-intensive operations that can be optimized")
        
        # Memory-related recommendations
        memory_alerts = [a for a in alerts if 'memory' in a.metric_name]
        if memory_alerts:
            recommendations.append("Implement memory pooling to reduce garbage collection overhead")
            recommendations.append("Consider increasing node memory or optimizing data structures")
        
        # Latency-related recommendations
        latency_alerts = [a for a in alerts if 'latency' in a.metric_name]
        if latency_alerts:
            recommendations.append("Optimize disk I/O patterns by implementing write batching")
            recommendations.append("Consider using faster storage (SSD) for better I/O performance")
            recommendations.append("Review network configuration for potential bottlenecks")
        
        # General recommendations
        cluster_totals = metrics.get('cluster_totals', {})
        if cluster_totals.get('total_throughput', 0) < 100:
            recommendations.append("Monitor application bottlenecks that may be limiting throughput")
        
        return recommendations[:5]  # Limit to top 5 recommendations

    async def generate_performance_report(self, aggregated_metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Generate comprehensive performance report"""
        analysis = await self.analyze_cluster_performance(aggregated_metrics)
        
        report = {
            'report_timestamp': time.time(),
            'report_id': f"perf_report_{int(time.time())}",
            'cluster_health': analysis['overall_health'],
            'performance_summary': analysis['performance_summary'],
            'alerts_summary': {
                'critical': len([a for a in analysis['alerts'] if a['level'] == 'critical']),
                'warning': len([a for a in analysis['alerts'] if a['level'] == 'warning']),
                'total': len(analysis['alerts'])
            },
            'detailed_metrics': aggregated_metrics,
            'alerts': analysis['alerts'],
            'recommendations': analysis['recommendations'],
            'trends': await self._analyze_trends(aggregated_metrics)
        }
        
        return report
    
    async def _analyze_trends(self, metrics: Dict[str, Any]) -> Dict[str, str]:
        """Analyze performance trends"""
        trends = {}
        
        cluster_totals = metrics.get('cluster_totals', {})
        
        # Simple trend analysis (in production, this would use historical data)
        if 'avg_cpu_usage' in cluster_totals:
            cpu_usage = cluster_totals['avg_cpu_usage']
            if cpu_usage > 70:
                trends['cpu'] = 'increasing'
            elif cpu_usage < 30:
                trends['cpu'] = 'stable_low'
            else:
                trends['cpu'] = 'stable'
        
        if 'total_throughput' in cluster_totals:
            throughput = cluster_totals['total_throughput']
            if throughput > 100:
                trends['throughput'] = 'healthy'
            else:
                trends['throughput'] = 'concerning'
        
        return trends
EOF

# Create dashboard
cat > src/dashboard/web_dashboard.py << 'EOF'
import asyncio
import json
from aiohttp import web, WSMsgType
import aiohttp_cors
from datetime import datetime
import logging

class PerformanceDashboard:
    """Web-based performance monitoring dashboard"""
    
    def __init__(self, aggregator, analyzer, config):
        self.aggregator = aggregator
        self.analyzer = analyzer
        self.config = config
        self.websockets = set()
        self.app = web.Application()
        self.setup_routes()
        
    def setup_routes(self):
        """Setup web routes"""
        self.app.router.add_get('/', self.index)
        self.app.router.add_get('/api/metrics', self.get_metrics)
        self.app.router.add_get('/api/report', self.get_report)
        self.app.router.add_get('/ws', self.websocket_handler)
        self.app.router.add_static('/static/', path='src/dashboard/static', name='static')
        
        # Setup CORS
        cors = aiohttp_cors.setup(self.app, defaults={
            "*": aiohttp_cors.ResourceOptions(
                allow_credentials=True,
                expose_headers="*",
                allow_headers="*",
                allow_methods="*"
            )
        })
        
        for route in list(self.app.router.routes()):
            cors.add(route)
    
    async def index(self, request):
        """Serve dashboard HTML"""
        html = """
<!DOCTYPE html>
<html>
<head>
    <title>Cluster Performance Dashboard</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .metric-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .alert { padding: 10px; margin: 10px 0; border-radius: 4px; }
        .alert-critical { background: #f8d7da; border-left: 4px solid #dc3545; }
        .alert-warning { background: #fff3cd; border-left: 4px solid #ffc107; }
        .status-healthy { color: #28a745; }
        .status-warning { color: #ffc107; }
        .status-critical { color: #dc3545; }
        .refresh-button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }
        .recommendations { background: #e7f3ff; padding: 15px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Cluster Performance Dashboard</h1>
        <p>Real-time monitoring for distributed log storage cluster</p>
        <button class="refresh-button" onclick="refreshData()">Refresh Data</button>
        <span id="last-updated" style="float: right;"></span>
    </div>
    
    <div id="cluster-status" class="metric-card">
        <h2>Cluster Status</h2>
        <div id="status-content">Loading...</div>
    </div>
    
    <div class="metric-grid">
        <div class="metric-card">
            <h3>CPU Usage</h3>
            <div id="cpu-chart"></div>
        </div>
        
        <div class="metric-card">
            <h3>Memory Usage</h3>
            <div id="memory-chart"></div>
        </div>
        
        <div class="metric-card">
            <h3>Throughput</h3>
            <div id="throughput-chart"></div>
        </div>
        
        <div class="metric-card">
            <h3>Latency</h3>
            <div id="latency-chart"></div>
        </div>
    </div>
    
    <div id="alerts-section" class="metric-card">
        <h2>Active Alerts</h2>
        <div id="alerts-content">No alerts</div>
    </div>
    
    <div id="recommendations-section" class="recommendations">
        <h2>Performance Recommendations</h2>
        <div id="recommendations-content">No recommendations</div>
    </div>

    <script>
        let ws = null;
        
        function connectWebSocket() {
            ws = new WebSocket('ws://localhost:8080/ws');
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                updateDashboard(data);
            };
            ws.onclose = function() {
                setTimeout(connectWebSocket, 5000);
            };
        }
        
        function updateDashboard(data) {
            updateClusterStatus(data);
            updateCharts(data);
            updateAlerts(data);
            updateRecommendations(data);
            document.getElementById('last-updated').textContent = 
                'Last updated: ' + new Date().toLocaleTimeString();
        }
        
        function updateClusterStatus(data) {
            const status = data.cluster_health || 'unknown';
            const summary = data.performance_summary || {};
            
            let statusClass = 'status-healthy';
            if (status === 'warning') statusClass = 'status-warning';
            if (status === 'critical') statusClass = 'status-critical';
            
            document.getElementById('status-content').innerHTML = `
                <h3 class="${statusClass}">Status: ${status.toUpperCase()}</h3>
                <p>Active Nodes: ${summary.active_nodes || 0}</p>
                <p>Performance Score: ${(summary.performance_score || 0).toFixed(1)}/100</p>
                <p>Total Throughput: ${(summary.total_throughput || 0).toFixed(1)} ops/sec</p>
            `;
        }
        
        function updateCharts(data) {
            const nodes = data.detailed_metrics?.nodes || {};
            
            // CPU Chart
            const cpuData = Object.entries(nodes).map(([nodeId, metrics]) => ({
                x: [nodeId],
                y: [metrics.cpu_usage_total?.avg || 0],
                type: 'bar',
                name: nodeId
            }));
            
            Plotly.newPlot('cpu-chart', cpuData, {
                title: 'CPU Usage by Node (%)',
                yaxis: { range: [0, 100] }
            });
            
            // Memory Chart
            const memoryData = Object.entries(nodes).map(([nodeId, metrics]) => ({
                x: [nodeId],
                y: [metrics.memory_usage?.avg || 0],
                type: 'bar',
                name: nodeId
            }));
            
            Plotly.newPlot('memory-chart', memoryData, {
                title: 'Memory Usage by Node (%)',
                yaxis: { range: [0, 100] }
            });
            
            // Throughput Chart
            const throughputData = Object.entries(nodes).map(([nodeId, metrics]) => ({
                x: [nodeId],
                y: [metrics.operations_per_second?.avg || 0],
                type: 'bar',
                name: nodeId
            }));
            
            Plotly.newPlot('throughput-chart', throughputData, {
                title: 'Throughput by Node (ops/sec)'
            });
            
            // Latency Chart
            const latencyData = Object.entries(nodes).map(([nodeId, metrics]) => ({
                x: [nodeId],
                y: [metrics.write_latency_avg?.avg || 0],
                type: 'bar',
                name: nodeId
            }));
            
            Plotly.newPlot('latency-chart', latencyData, {
                title: 'Write Latency by Node (ms)'
            });
        }
        
        function updateAlerts(data) {
            const alerts = data.alerts || [];
            let alertsHtml = '';
            
            if (alerts.length === 0) {
                alertsHtml = '<p>No active alerts</p>';
            } else {
                alerts.forEach(alert => {
                    const alertClass = alert.level === 'critical' ? 'alert-critical' : 'alert-warning';
                    alertsHtml += `
                        <div class="alert ${alertClass}">
                            <strong>${alert.node_id}</strong>: ${alert.message}
                            <small>(${alert.current_value.toFixed(1)} vs threshold ${alert.threshold.toFixed(1)})</small>
                        </div>
                    `;
                });
            }
            
            document.getElementById('alerts-content').innerHTML = alertsHtml;
        }
        
        function updateRecommendations(data) {
            const recommendations = data.recommendations || [];
            let recHtml = '';
            
            if (recommendations.length === 0) {
                recHtml = '<p>No recommendations at this time</p>';
            } else {
                recHtml = '<ul>';
                recommendations.forEach(rec => {
                    recHtml += `<li>${rec}</li>`;
                });
                recHtml += '</ul>';
            }
            
            document.getElementById('recommendations-content').innerHTML = recHtml;
        }
        
        function refreshData() {
            fetch('/api/report')
                .then(response => response.json())
                .then(data => updateDashboard(data))
                .catch(error => console.error('Error fetching data:', error));
        }
        
        // Initialize
        connectWebSocket();
        refreshData();
        
        // Auto-refresh every 30 seconds
        setInterval(refreshData, 30000);
    </script>
</body>
</html>
        """
        return web.Response(text=html, content_type='text/html')
    
    async def get_metrics(self, request):
        """API endpoint for metrics"""
        try:
            metrics = await self.aggregator.aggregate_cluster_metrics()
            return web.json_response(metrics)
        except Exception as e:
            return web.json_response({'error': str(e)}, status=500)
    
    async def get_report(self, request):
        """API endpoint for performance report"""
        try:
            metrics = await self.aggregator.aggregate_cluster_metrics()
            report = await self.analyzer.generate_performance_report(metrics)
            return web.json_response(report)
        except Exception as e:
            return web.json_response({'error': str(e)}, status=500)
    
    async def websocket_handler(self, request):
        """WebSocket handler for real-time updates"""
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        
        self.websockets.add(ws)
        
        try:
            async for msg in ws:
                if msg.type == WSMsgType.ERROR:
                    print(f'WebSocket error: {ws.exception()}')
        finally:
            self.websockets.discard(ws)
        
        return ws
    
    async def broadcast_update(self, data):
        """Broadcast updates to all connected WebSocket clients"""
        if not self.websockets:
            return
        
        message = json.dumps(data)
        disconnected = set()
        
        for ws in self.websockets:
            try:
                await ws.send_str(message)
            except ConnectionResetError:
                disconnected.add(ws)
        
        # Clean up disconnected WebSockets
        self.websockets -= disconnected
    
    async def start_server(self):
        """Start the dashboard web server"""
        runner = web.AppRunner(self.app)
        await runner.setup()
        
        host = self.config.get('dashboard', {}).get('host', '0.0.0.0')
        port = self.config.get('dashboard', {}).get('port', 8080)
        
        site = web.TCPSite(runner, host, port)
        await site.start()
        
        print(f"Dashboard started at http://{host}:{port}")
        
        # Start periodic updates
        asyncio.create_task(self._periodic_updates())
    
    async def _periodic_updates(self):
        """Send periodic updates to WebSocket clients"""
        while True:
            try:
                metrics = await self.aggregator.aggregate_cluster_metrics()
                report = await self.analyzer.generate_performance_report(metrics)
                await self.broadcast_update(report)
            except Exception as e:
                logging.error(f"Error in periodic updates: {e}")
            
            await asyncio.sleep(self.config.get('dashboard', {}).get('refresh_interval', 10))
EOF

# Create main monitoring service
cat > src/monitoring_service.py << 'EOF'
import asyncio
import yaml
import logging
import signal
import sys
from pathlib import Path

from collectors.metric_collector import MetricsCollector
from aggregators.metrics_aggregator import MetricsAggregator
from analyzers.performance_analyzer import PerformanceAnalyzer
from dashboard.web_dashboard import PerformanceDashboard

class MonitoringService:
    """Main monitoring service that orchestrates all components"""
    
    def __init__(self, config_path: str):
        self.config = self.load_config(config_path)
        self.metric_queue = asyncio.Queue(maxsize=10000)
        self.collectors = {}
        self.aggregator = MetricsAggregator(self.config)
        self.analyzer = PerformanceAnalyzer(self.config)
        self.dashboard = PerformanceDashboard(self.aggregator, self.analyzer, self.config)
        self.running = False
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
    
    def load_config(self, config_path: str) -> dict:
        """Load configuration from YAML file"""
        with open(config_path, 'r') as file:
            return yaml.safe_load(file)
    
    async def initialize_collectors(self):
        """Initialize metric collectors for each node"""
        nodes = self.config.get('cluster', {}).get('nodes', [])
        
        for node in nodes:
            node_id = node['id']
            collector = MetricsCollector(node_id, self.config.get('monitoring', {}))
            self.collectors[node_id] = collector
            
            # Start collection task
            asyncio.create_task(collector.start_collection(self.metric_queue))
            self.logger.info(f"Started collector for node {node_id}")
    
    async def start(self):
        """Start the monitoring service"""
        self.running = True
        self.logger.info("Starting performance monitoring service...")
        
        try:
            # Initialize collectors
            await self.initialize_collectors()
            
            # Start aggregator
            asyncio.create_task(self.aggregator.process_metrics(self.metric_queue))
            self.logger.info("Started metrics aggregator")
            
            # Start dashboard
            await self.dashboard.start_server()
            self.logger.info("Started web dashboard")
            
            # Start periodic reporting
            asyncio.create_task(self.periodic_reporting())
            
            self.logger.info("Monitoring service started successfully")
            
            # Keep running
            while self.running:
                await asyncio.sleep(1)
                
        except Exception as e:
            self.logger.error(f"Error starting monitoring service: {e}")
            await self.stop()
    
    async def periodic_reporting(self):
        """Generate periodic performance reports"""
        while self.running:
            try:
                # Generate report every 5 minutes
                await asyncio.sleep(300)
                
                metrics = await self.aggregator.aggregate_cluster_metrics()
                report = await self.analyzer.generate_performance_report(metrics)
                
                # Log summary
                summary = report.get('performance_summary', {})
                self.logger.info(
                    f"Performance Report - Score: {summary.get('performance_score', 0):.1f}, "
                    f"CPU: {summary.get('cluster_cpu_avg', 0):.1f}%, "
                    f"Throughput: {summary.get('total_throughput', 0):.1f} ops/sec"
                )
                
                # Save report to file
                report_file = Path(f"data/performance_report_{int(report['report_timestamp'])}.json")
                report_file.parent.mkdir(exist_ok=True)
                
                import json
                with open(report_file, 'w') as f:
                    json.dump(report, f, indent=2)
                
            except Exception as e:
                self.logger.error(f"Error in periodic reporting: {e}")
    
    async def stop(self):
        """Stop the monitoring service"""
        self.logger.info("Stopping monitoring service...")
        self.running = False
        
        # Stop collectors
        for collector in self.collectors.values():
            collector.stop_collection()
        
        # Stop aggregator
        self.aggregator.stop()
        
        self.logger.info("Monitoring service stopped")
    
    def setup_signal_handlers(self):
        """Setup signal handlers for graceful shutdown"""
        def signal_handler(signum, frame):
            self.logger.info(f"Received signal {signum}, shutting down...")
            asyncio.create_task(self.stop())
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

async def main():
    """Main entry point"""
    service = MonitoringService('config/monitoring_config.yaml')
    service.setup_signal_handlers()
    await service.start()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nMonitoring service stopped by user")
EOF

# Create test files
cat > tests/test_collectors.py << 'EOF'
import pytest
import asyncio
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from collectors.metric_collector import MetricsCollector, SystemMetricsCollector, ApplicationMetricsCollector

@pytest.mark.asyncio
async def test_system_metrics_collector():
    """Test system metrics collection"""
    collector = SystemMetricsCollector("test-node")
    
    # Test CPU metrics
    cpu_metrics = await collector.collect_cpu_metrics()
    assert len(cpu_metrics) > 0
    assert all(m.node_id == "test-node" for m in cpu_metrics)
    assert any(m.metric_name == "cpu_usage_total" for m in cpu_metrics)
    
    # Test memory metrics
    memory_metrics = await collector.collect_memory_metrics()
    assert len(memory_metrics) >= 2
    assert any(m.metric_name == "memory_usage" for m in memory_metrics)
    assert any(m.metric_name == "memory_available" for m in memory_metrics)
    
    # Test disk metrics
    disk_metrics = await collector.collect_disk_metrics()
    assert len(disk_metrics) >= 3
    assert any(m.metric_name == "disk_usage_percent" for m in disk_metrics)

@pytest.mark.asyncio
async def test_application_metrics_collector():
    """Test application metrics collection"""
    collector = ApplicationMetricsCollector("test-node")
    
    # Record some latencies
    collector.record_write_latency(10.5)
    collector.record_write_latency(15.2)
    collector.record_read_latency(5.1)
    
    # Collect latency metrics
    latency_metrics = await collector.collect_latency_metrics()
    assert len(latency_metrics) >= 2
    
    # Collect throughput metrics
    throughput_metrics = await collector.collect_throughput_metrics()
    assert len(throughput_metrics) == 1
    assert throughput_metrics[0].metric_name == "operations_per_second"
    assert throughput_metrics[0].value == 2  # 2 write operations recorded

@pytest.mark.asyncio
async def test_metrics_collector_integration():
    """Test complete metrics collector"""
    config = {'collection_interval': 1}
    collector = MetricsCollector("test-node", config)
    
    # Test metric collection
    metrics = await collector.collect_all_metrics()
    assert len(metrics) > 0
    
    # Test with queue
    queue = asyncio.Queue()
    
    # Start collection (run for short time)
    collection_task = asyncio.create_task(collector.start_collection(queue))
    await asyncio.sleep(2)
    collector.stop_collection()
    collection_task.cancel()
    
    # Check that metrics were queued
    collected_metrics = []
    while not queue.empty():
        collected_metrics.append(await queue.get())
    
    assert len(collected_metrics) > 0

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

cat > tests/test_aggregators.py << 'EOF'
import pytest
import asyncio
import time
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from aggregators.metrics_aggregator import MetricsAggregator
from collectors.metric_collector import MetricPoint

@pytest.mark.asyncio
async def test_metrics_aggregator():
    """Test metrics aggregation"""
    config = {'retention_period': 3600}
    aggregator = MetricsAggregator(config)
    
    # Create test metrics
    test_metrics = [
        MetricPoint(time.time(), "node-1", "cpu_usage", 75.5),
        MetricPoint(time.time(), "node-1", "memory_usage", 60.0),
        MetricPoint(time.time(), "node-2", "cpu_usage", 80.2),
        MetricPoint(time.time(), "node-2", "memory_usage", 55.5),
    ]
    
    # Store metrics
    for metric in test_metrics:
        await aggregator._store_metric(metric)
    
    # Test aggregation
    cluster_metrics = await aggregator.aggregate_cluster_metrics(time_window=300)
    
    assert 'nodes' in cluster_metrics
    assert 'cluster_totals' in cluster_metrics
    assert len(cluster_metrics['nodes']) == 2
    
    # Check node metrics
    node1_metrics = cluster_metrics['nodes']['node-1']
    assert 'cpu_usage' in node1_metrics
    assert 'memory_usage' in node1_metrics
    assert node1_metrics['cpu_usage']['avg'] == 75.5

@pytest.mark.asyncio
async def test_metric_history():
    """Test metric history retrieval"""
    config = {'retention_period': 3600}
    aggregator = MetricsAggregator(config)
    
    # Add historical metrics
    base_time = time.time() - 1800  # 30 minutes ago
    for i in range(10):
        metric = MetricPoint(
            base_time + (i * 60),  # Every minute
            "node-1",
            "cpu_usage",
            70.0 + i
        )
        await aggregator._store_metric(metric)
    
    # Get 1-hour history
    history = await aggregator.get_metric_history("node-1", "cpu_usage", hours=1)
    
    assert len(history) == 10
    assert all(h['value'] >= 70.0 for h in history)

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

cat > tests/test_analyzers.py << 'EOF'
import pytest
import time
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from analyzers.performance_analyzer import PerformanceAnalyzer, AlertLevel

@pytest.mark.asyncio
async def test_performance_analyzer():
    """Test performance analysis"""
    config = {
        'metrics': {
            'thresholds': {
                'cpu_warning': 70,
                'cpu_critical': 90,
                'memory_warning': 80,
                'memory_critical': 95,
                'latency_warning': 100,
                'latency_critical': 500
            }
        }
    }
    
    analyzer = PerformanceAnalyzer(config)
    
    # Test with healthy metrics
    healthy_metrics = {
        'nodes': {
            'node-1': {
                'cpu_usage_total': {'avg': 50.0},
                'memory_usage': {'avg': 60.0},
                'write_latency_avg': {'avg': 50.0}
            }
        },
        'cluster_totals': {
            'avg_cpu_usage': 50.0,
            'total_throughput': 100.0
        }
    }
    
    analysis = await analyzer.analyze_cluster_performance(healthy_metrics)
    assert analysis['overall_health'] == 'healthy'
    assert len(analysis['alerts']) == 0

@pytest.mark.asyncio
async def test_performance_alerts():
    """Test alert generation"""
    config = {
        'metrics': {
            'thresholds': {
                'cpu_warning': 70,
                'cpu_critical': 90,
                'memory_warning': 80,
                'memory_critical': 95
            }
        }
    }
    
    analyzer = PerformanceAnalyzer(config)
    
    # Test with critical metrics
    critical_metrics = {
        'nodes': {
            'node-1': {
                'cpu_usage_total': {'avg': 95.0},
                'memory_usage': {'avg': 98.0}
            }
        },
        'cluster_totals': {}
    }
    
    analysis = await analyzer.analyze_cluster_performance(critical_metrics)
    assert analysis['overall_health'] == 'critical'
    assert len(analysis['alerts']) >= 2
    
    # Check alert levels
    critical_alerts = [a for a in analysis['alerts'] if a['level'] == 'critical']
    assert len(critical_alerts) >= 2

@pytest.mark.asyncio
async def test_performance_report():
    """Test performance report generation"""
    config = {'metrics': {'thresholds': {}}}
    analyzer = PerformanceAnalyzer(config)
    
    metrics = {
        'nodes': {
            'node-1': {
                'cpu_usage_total': {'avg': 60.0},
                'memory_usage': {'avg': 70.0},
                'operations_per_second': {'avg': 50.0}
            }
        },
        'cluster_totals': {
            'avg_cpu_usage': 60.0,
            'total_throughput': 50.0
        }
    }
    
    report = await analyzer.generate_performance_report(metrics)
    
    assert 'report_timestamp' in report
    assert 'cluster_health' in report
    assert 'performance_summary' in report
    assert 'recommendations' in report
    assert 'trends' in report
    
    # Check performance summary
    summary = report['performance_summary']
    assert 'performance_score' in summary
    assert 0 <= summary['performance_score'] <= 100

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create integration test
cat > tests/test_integration.py << 'EOF'
import pytest
import asyncio
import tempfile
import yaml
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from monitoring_service import MonitoringService

@pytest.mark.asyncio
async def test_monitoring_service_integration():
    """Test complete monitoring service integration"""
    # Create temporary config
    config = {
        'monitoring': {
            'collection_interval': 1,
            'retention_period': 3600
        },
        'cluster': {
            'nodes': [
                {'id': 'node-1', 'host': 'localhost', 'port': 8001, 'role': 'primary'},
                {'id': 'node-2', 'host': 'localhost', 'port': 8002, 'role': 'replica'}
            ]
        },
        'metrics': {
            'thresholds': {
                'cpu_warning': 70,
                'cpu_critical': 90
            }
        },
        'dashboard': {
            'host': '127.0.0.1',
            'port': 8081
        }
    }
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        yaml.dump(config, f)
        config_path = f.name
    
    try:
        service = MonitoringService(config_path)
        
        # Test initialization
        await service.initialize_collectors()
        assert len(service.collectors) == 2
        
        # Test metric collection for short time
        service.running = True
        collection_tasks = []
        
        # Start aggregator
        aggregator_task = asyncio.create_task(
            service.aggregator.process_metrics(service.metric_queue)
        )
        collection_tasks.append(aggregator_task)
        
        # Run for a short time
        await asyncio.sleep(3)
        
        # Stop service
        await service.stop()
        
        # Cancel tasks
        for task in collection_tasks:
            task.cancel()
        
        # Test metrics were collected
        metrics = await service.aggregator.aggregate_cluster_metrics()
        assert 'nodes' in metrics
        
    finally:
        Path(config_path).unlink()

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create Docker configuration
cat > docker/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ ./src/
COPY config/ ./config/
COPY tests/ ./tests/

# Create data and logs directories
RUN mkdir -p data logs

# Expose dashboard port
EXPOSE 8080

# Run monitoring service
CMD ["python", "-m", "src.monitoring_service"]
EOF

cat > docker/docker-compose.yml << 'EOF'
version: '3.8'

services:
  monitoring:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    ports:
      - "8080:8080"
    volumes:
      - ../data:/app/data
      - ../logs:/app/logs
      - ../config:/app/config
    environment:
      - PYTHONPATH=/app
    restart: unless-stopped
    
  # Simulate additional nodes for testing
  node-simulator-1:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    environment:
      - NODE_ID=sim-node-1
      - PYTHONPATH=/app
    command: python -c "
      import asyncio
      import random
      import time
      from src.collectors.metric_collector import ApplicationMetricsCollector
      
      async def simulate_load():
          collector = ApplicationMetricsCollector('sim-node-1')
          while True:
              # Simulate varying load
              latency = random.uniform(10, 200)
              collector.record_write_latency(latency)
              await asyncio.sleep(random.uniform(0.1, 1.0))
      
      asyncio.run(simulate_load())
    "
    depends_on:
      - monitoring

  node-simulator-2:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    environment:
      - NODE_ID=sim-node-2
      - PYTHONPATH=/app
    command: python -c "
      import asyncio
      import random
      import time
      from src.collectors.metric_collector import ApplicationMetricsCollector
      
      async def simulate_load():
          collector = ApplicationMetricsCollector('sim-node-2')
          while True:
              # Simulate varying load
              latency = random.uniform(5, 150)
              collector.record_write_latency(latency)
              await asyncio.sleep(random.uniform(0.1, 0.8))
      
      asyncio.run(simulate_load())
    "
    depends_on:
      - monitoring
EOF

# Create demonstration script
cat > demo.py << 'EOF'
import asyncio
import random
import time
import json
from src.collectors.metric_collector import MetricsCollector, ApplicationMetricsCollector
from src.aggregators.metrics_aggregator import MetricsAggregator
from src.analyzers.performance_analyzer import PerformanceAnalyzer

async def demonstrate_performance_monitoring():
    """Demonstrate the performance monitoring system"""
    print("🚀 Performance Monitoring System Demonstration")
    print("=" * 60)
    
    # Configuration
    config = {
        'monitoring': {'collection_interval': 2},
        'metrics': {
            'thresholds': {
                'cpu_warning': 70,
                'cpu_critical': 90,
                'memory_warning': 80,
                'memory_critical': 95,
                'latency_warning': 100,
                'latency_critical': 500
            }
        }
    }
    
    # Initialize components
    aggregator = MetricsAggregator(config)
    analyzer = PerformanceAnalyzer(config)
    metric_queue = asyncio.Queue()
    
    # Create collectors for simulated nodes
    collectors = {
        'node-1': MetricsCollector('node-1', config['monitoring']),
        'node-2': MetricsCollector('node-2', config['monitoring']),
        'node-3': MetricsCollector('node-3', config['monitoring'])
    }
    
    print("\n1. Starting metric collection from 3 nodes...")
    
    # Start collection tasks
    collection_tasks = []
    for collector in collectors.values():
        task = asyncio.create_task(collector.start_collection(metric_queue))
        collection_tasks.append(task)
    
    # Start aggregator
    aggregator_task = asyncio.create_task(aggregator.process_metrics(metric_queue))
    
    # Simulate workload on application collectors
    async def simulate_workload():
        """Simulate varying workload patterns"""
        while True:
            for node_id, collector in collectors.items():
                # Simulate different load patterns per node
                if node_id == 'node-1':
                    # Primary node - higher load
                    latency = random.uniform(20, 300)
                    for _ in range(random.randint(5, 15)):
                        collector.app_collector.record_write_latency(latency)
                elif node_id == 'node-2':
                    # Secondary node - moderate load
                    latency = random.uniform(10, 150)
                    for _ in range(random.randint(2, 8)):
                        collector.app_collector.record_write_latency(latency)
                else:
                    # Tertiary node - light load
                    latency = random.uniform(5, 100)
                    for _ in range(random.randint(1, 5)):
                        collector.app_collector.record_write_latency(latency)
            
            await asyncio.sleep(1)
    
    workload_task = asyncio.create_task(simulate_workload())
    
    print("2. Collecting metrics for 15 seconds...")
    await asyncio.sleep(15)
    
    print("\n3. Generating aggregated metrics...")
    cluster_metrics = await aggregator.aggregate_cluster_metrics(time_window=300)
    
    print(f"   - Active nodes: {len(cluster_metrics['nodes'])}")
    print(f"   - Metrics collected: {sum(len(metrics) for metrics in aggregator.metrics_buffer.values())}")
    
    # Display cluster totals
    cluster_totals = cluster_metrics.get('cluster_totals', {})
    if cluster_totals:
        print(f"   - Cluster avg CPU: {cluster_totals.get('avg_cpu_usage', 0):.1f}%")
        print(f"   - Cluster avg Memory: {cluster_totals.get('avg_memory_usage', 0):.1f}%")
        print(f"   - Total throughput: {cluster_totals.get('total_throughput', 0):.1f} ops/sec")
    
    print("\n4. Analyzing performance and generating alerts...")
    analysis = await analyzer.analyze_cluster_performance(cluster_metrics)
    
    print(f"   - Overall health: {analysis['overall_health'].upper()}")
    print(f"   - Active alerts: {len(analysis['alerts'])}")
    
    # Display alerts
    if analysis['alerts']:
        print("\n   Active Alerts:")
        for alert in analysis['alerts'][:5]:  # Show first 5 alerts
            print(f"     • {alert['level'].upper()}: {alert['message']} (Node: {alert['node_id']})")
    
    print("\n5. Generating comprehensive performance report...")
    report = await analyzer.generate_performance_report(cluster_metrics)
    
    # Display performance summary
    summary = report['performance_summary']
    print(f"   - Performance Score: {summary['performance_score']:.1f}/100")
    print(f"   - Active Nodes: {summary['active_nodes']}")
    
    # Display recommendations
    if report['recommendations']:
        print("\n   Top Recommendations:")
        for i, rec in enumerate(report['recommendations'][:3], 1):
            print(f"     {i}. {rec}")
    
    print("\n6. Simulating performance issues...")
    
    # Simulate high load on node-1
    for _ in range(50):
        collectors['node-1'].app_collector.record_write_latency(random.uniform(400, 800))
    
    await asyncio.sleep(3)
    
    # Re-analyze
    updated_metrics = await aggregator.aggregate_cluster_metrics(time_window=300)
    updated_analysis = await analyzer.analyze_cluster_performance(updated_metrics)
    
    print(f"   - Updated health status: {updated_analysis['overall_health'].upper()}")
    print(f"   - New alerts: {len(updated_analysis['alerts'])}")
    
    if updated_analysis['alerts']:
        print("\n   Critical Issues Detected:")
        critical_alerts = [a for a in updated_analysis['alerts'] if a['level'] == 'critical']
        for alert in critical_alerts[:3]:
            print(f"     🚨 {alert['message']} (Value: {alert['current_value']:.1f})")
    
    print("\n7. Saving performance report...")
    report_file = f"data/demo_performance_report_{int(time.time())}.json"
    with open(report_file, 'w') as f:
        json.dump(report, f, indent=2)
    print(f"   - Report saved to: {report_file}")
    
    # Cleanup
    print("\n8. Cleaning up...")
    for collector in collectors.values():
        collector.stop_collection()
    
    aggregator.stop()
    
    for task in collection_tasks + [aggregator_task, workload_task]:
        task.cancel()
    
    print("\n✅ Performance monitoring demonstration completed!")
    print("\nKey Capabilities Demonstrated:")
    print("• Real-time metric collection from multiple nodes")
    print("• Automatic aggregation and trend analysis")
    print("• Intelligent alerting based on configurable thresholds")
    print("• Performance scoring and health assessment")
    print("• Actionable recommendations for optimization")
    print("\n🎯 The system is now ready for production deployment!")

if __name__ == "__main__":
    asyncio.run(demonstrate_performance_monitoring())
EOF

# Install dependencies
echo "📦 Installing Python dependencies..."
python3 -m pip install --upgrade pip
pip install -r requirements.txt

# Create directory structure
mkdir -p {data,logs}

# Run tests
echo "🧪 Running tests..."
python3 -m pytest tests/ -v --tb=short

# Run demonstration
echo "🎬 Running system demonstration..."
python3 demo.py

# Build and test Docker setup
echo "🐳 Testing Docker setup..."
cd docker
docker-compose build --no-cache
echo "Docker images built successfully!"

echo "
🎉 Day 30 Performance Monitoring System Implementation Complete!

📊 What was built:
✅ Comprehensive metric collection system (CPU, memory, disk, network, application metrics)
✅ Real-time metrics aggregation across cluster nodes
✅ Intelligent performance analysis with configurable thresholds
✅ Web-based dashboard with live updates and visualizations
✅ Automated alerting system for performance issues
✅ Performance scoring and optimization recommendations
✅ Complete test suite with unit and integration tests
✅ Docker containerization for production deployment

🚀 To start the monitoring system:

Without Docker:
python3 -m src.monitoring_service

With Docker:
cd docker && docker-compose up

📈 Access dashboard at: http://localhost:8080

🔧 Key Features:
• Tracks 10+ performance metrics per node
• Generates real-time alerts for threshold violations
• Provides actionable optimization recommendations
• Scales horizontally with cluster growth
• Maintains 24-hour metric history
• Offers both REST API and WebSocket interfaces

📝 Performance Report Format:
• Cluster health status (healthy/warning/critical)
• Performance score (0-100)
• Node-level metric breakdowns
• Trend analysis and predictions
• Optimization recommendations

Next Steps:
• Integrate with log storage system from previous days
• Add custom business metrics for log processing rates
• Implement metric-based auto-scaling policies
• Set up alerting integrations (email, Slack, PagerDuty)
"

echo "✨ Ready for Day 31: Setting up RabbitMQ for log message distribution!"
EOF

chmod +x day30_performance_monitoring/setup.sh