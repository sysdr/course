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
