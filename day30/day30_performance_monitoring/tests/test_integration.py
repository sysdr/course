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
