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
