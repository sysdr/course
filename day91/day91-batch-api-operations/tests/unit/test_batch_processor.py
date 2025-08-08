import pytest
import asyncio
from unittest.mock import Mock, AsyncMock
from datetime import datetime, timezone

from src.batch.batch_processor import BatchProcessor
from src.models.log_models import LogEntry

@pytest.fixture
def sample_logs():
    return [
        LogEntry(
            id=f"test-{i}",
            timestamp=datetime.now(timezone.utc),
            level="INFO",
            service="test-service",
            message=f"Test message {i}",
            metadata={"test": True}
        )
        for i in range(100)
    ]

@pytest.fixture
def batch_processor():
    processor = BatchProcessor()
    processor.db_pool = None  # Use in-memory mode for testing
    return processor

@pytest.mark.asyncio
async def test_batch_insert_success(batch_processor, sample_logs):
    """Test successful batch insert"""
    result = await batch_processor.process_batch_insert(
        sample_logs, 
        None, 
        chunk_size=50
    )
    
    assert result.success_count == 100
    assert result.error_count == 0
    assert result.total_processed == 100
    assert result.processing_time > 0

@pytest.mark.asyncio
async def test_batch_insert_chunking(batch_processor, sample_logs):
    """Test batch chunking logic"""
    chunks = batch_processor._create_chunks(sample_logs, 30, "test-batch")
    
    assert len(chunks) == 4  # 100 logs / 30 = 3.33, rounded up to 4
    assert chunks[0].start_index == 0
    assert chunks[0].end_index == 30
    assert chunks[-1].start_index == 90
    assert chunks[-1].end_index == 100

@pytest.mark.asyncio
async def test_health_check(batch_processor):
    """Test health check functionality"""
    health = await batch_processor.health_check()
    
    assert health["status"] == "healthy"
    assert "max_chunk_size" in health
    assert "max_concurrent_chunks" in health

def test_chunk_creation_edge_cases(batch_processor):
    """Test chunk creation with edge cases"""
    # Empty logs
    chunks = batch_processor._create_chunks([], 100, "empty-batch")
    assert len(chunks) == 0
    
    # Single log
    single_log = [LogEntry(
        level="INFO",
        service="test",
        message="single"
    )]
    chunks = batch_processor._create_chunks(single_log, 100, "single-batch")
    assert len(chunks) == 1
    assert len(chunks[0].logs) == 1
