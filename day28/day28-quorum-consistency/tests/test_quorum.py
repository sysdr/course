import pytest
import asyncio
from src.quorum_coordinator import QuorumCoordinator, QuorumConfig, ConsistencyLevel
from src.consistency_manager import ConsistencyManager

@pytest.mark.asyncio
async def test_quorum_write_success():
    """Test successful quorum write"""
    nodes = ['node1', 'node2', 'node3']
    config = QuorumConfig(3, 2, 2, ConsistencyLevel.BALANCED)
    coordinator = QuorumCoordinator('node1', nodes, config)
    
    await coordinator.start()
    success, result = await coordinator.write('test_key', 'test_value')
    await coordinator.stop()
    
    assert success == True
    assert result['successful_writes'] >= 2

@pytest.mark.asyncio
async def test_quorum_read_success():
    """Test successful quorum read"""
    nodes = ['node1', 'node2', 'node3']
    config = QuorumConfig(3, 2, 2, ConsistencyLevel.BALANCED)
    coordinator = QuorumCoordinator('node1', nodes, config)
    
    await coordinator.start()
    
    # Write first
    await coordinator.write('test_key', 'test_value')
    
    # Then read
    entry, result = await coordinator.read('test_key')
    await coordinator.stop()
    
    assert entry is not None
    assert entry.value == 'test_value'

@pytest.mark.asyncio
async def test_consistency_levels():
    """Test different consistency levels"""
    manager = ConsistencyManager()
    nodes = ['node1', 'node2', 'node3', 'node4', 'node5']
    
    await manager.setup_cluster(nodes, ConsistencyLevel.STRONG)
    
    # Test strong consistency
    result = await manager.write_with_quorum('key1', 'value1')
    assert result['required_writes'] == 5  # All nodes
    
    # Change to eventual consistency
    await manager.change_consistency_level(ConsistencyLevel.EVENTUAL)
    result = await manager.write_with_quorum('key2', 'value2')
    assert result['required_writes'] == 1  # Just one node
    
    await manager.shutdown()

@pytest.mark.asyncio
async def test_conflict_resolution():
    """Test conflict resolution with concurrent writes"""
    nodes = ['node1', 'node2', 'node3']
    config = QuorumConfig(3, 2, 2, ConsistencyLevel.BALANCED)
    coordinator = QuorumCoordinator('node1', nodes, config)
    
    await coordinator.start()
    
    # Simulate concurrent writes
    tasks = [
        coordinator.write('conflict_key', 'value1'),
        coordinator.write('conflict_key', 'value2'),
        coordinator.write('conflict_key', 'value3')
    ]
    
    results = await asyncio.gather(*tasks)
    
    # Read the final value
    entry, _ = await coordinator.read('conflict_key')
    
    await coordinator.stop()
    
    assert entry is not None
    assert entry.value in ['value1', 'value2', 'value3']

if __name__ == "__main__":
    pytest.main([__file__])
