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
