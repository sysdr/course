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
