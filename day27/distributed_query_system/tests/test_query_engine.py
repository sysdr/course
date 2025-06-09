import pytest
import asyncio
import tempfile
import os
from src.executor.query_engine import QueryEngine
from src.common.query_types import Query, QueryFilter, TimeRange
from datetime import datetime

@pytest.mark.asyncio
async def test_query_engine_initialization():
    """Test query engine initialization"""
    with tempfile.TemporaryDirectory() as temp_dir:
        engine = QueryEngine(temp_dir)
        await engine.initialize()
        
        stats = await engine.get_stats()
        assert stats["total_records"] > 0
        assert stats["files_loaded"] > 0
        
        await engine.cleanup()

@pytest.mark.asyncio
async def test_basic_search():
    """Test basic search functionality"""
    with tempfile.TemporaryDirectory() as temp_dir:
        engine = QueryEngine(temp_dir)
        await engine.initialize()
        
        # Create a simple query
        query = Query()
        results = await engine.search(query)
        
        assert isinstance(results, list)
        assert len(results) > 0
        
        await engine.cleanup()

@pytest.mark.asyncio
async def test_filtered_search():
    """Test search with filters"""
    with tempfile.TemporaryDirectory() as temp_dir:
        engine = QueryEngine(temp_dir)
        await engine.initialize()
        
        # Create query with filter
        query = Query()
        query.filters.append(QueryFilter(
            field="level",
            operator="eq",
            value="ERROR"
        ))
        
        results = await engine.search(query)
        
        # All results should match the filter
        for result in results:
            assert result.get("level") == "ERROR"
        
        await engine.cleanup()

@pytest.mark.asyncio
async def test_time_range_search():
    """Test search with time range"""
    with tempfile.TemporaryDirectory() as temp_dir:
        engine = QueryEngine(temp_dir)
        await engine.initialize()
        
        # Get time ranges from data
        time_ranges = await engine.get_time_ranges()
        if time_ranges:
            start_time = datetime.fromisoformat(time_ranges[0]["start"])
            end_time = datetime.fromisoformat(time_ranges[0]["end"])
            
            query = Query()
            query.time_range = TimeRange(start=start_time, end=end_time)
            
            results = await engine.search(query)
            assert isinstance(results, list)
        
        await engine.cleanup()

if __name__ == "__main__":
    pytest.main([__file__])
