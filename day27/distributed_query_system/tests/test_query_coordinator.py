import pytest
import asyncio
from datetime import datetime, timedelta
from src.coordinator.query_coordinator import QueryCoordinator
from src.coordinator.partition_map import PartitionMap
from src.common.query_types import Query, TimeRange, QueryFilter

@pytest.mark.asyncio
async def test_query_coordinator_initialization():
    """Test that query coordinator initializes properly"""
    partition_map = PartitionMap("test_partitions.json")
    coordinator = QueryCoordinator(partition_map)
    
    await coordinator.start()
    assert coordinator.network_client is not None
    
    await coordinator.stop()

@pytest.mark.asyncio 
async def test_empty_query():
    """Test query with no partitions available"""
    partition_map = PartitionMap("nonexistent.json")
    coordinator = QueryCoordinator(partition_map)
    
    await coordinator.start()
    
    query = Query()
    result = await coordinator.execute_query(query)
    
    assert result.total_results == 0
    assert result.partitions_queried == 0
    assert len(result.errors) > 0
    
    await coordinator.stop()

@pytest.mark.asyncio
async def test_cache_functionality():
    """Test query result caching"""
    partition_map = PartitionMap("test_partitions.json")
    coordinator = QueryCoordinator(partition_map)
    
    await coordinator.start()
    
    # Create a simple query
    query = Query(
        sort_field="timestamp",
        sort_order="desc",
        limit=10
    )
    
    # Generate cache key
    cache_key = coordinator._generate_cache_key(query)
    assert isinstance(cache_key, str)
    assert len(cache_key) > 0
    
    await coordinator.stop()

if __name__ == "__main__":
    pytest.main([__file__])
