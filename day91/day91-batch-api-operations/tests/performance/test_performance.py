import pytest
import asyncio
import time
import statistics
from src.batch.batch_processor import BatchProcessor
from src.models.log_models import LogEntry
from datetime import datetime, timezone

@pytest.mark.asyncio
async def test_throughput_performance():
    """Test batch processing throughput"""
    processor = BatchProcessor()
    processor.db_pool = None  # Use in-memory mode
    
    # Generate test data
    log_counts = [100, 500, 1000, 2000]
    throughput_results = []
    
    for count in log_counts:
        logs = [
            LogEntry(
                timestamp=datetime.now(timezone.utc),
                level="INFO",
                service=f"service-{i % 5}",
                message=f"Performance test message {i}"
            )
            for i in range(count)
        ]
        
        start_time = time.time()
        result = await processor.process_batch_insert(logs, None, chunk_size=500)
        end_time = time.time()
        
        processing_time = end_time - start_time
        throughput = count / processing_time
        throughput_results.append(throughput)
        
        print(f"📊 {count} logs: {throughput:.0f} logs/sec")
        
        # Assert minimum throughput expectations
        assert throughput > 100  # At least 100 logs/sec
        assert result.success_count == count

    # Test throughput consistency
    assert max(throughput_results) / min(throughput_results) < 3  # Within 3x variance

@pytest.mark.asyncio 
async def test_chunk_size_optimization():
    """Test optimal chunk size for performance"""
    processor = BatchProcessor()
    processor.db_pool = None
    
    logs = [
        LogEntry(
            level="INFO",
            service="perf-test",
            message=f"Chunk optimization test {i}"
        )
        for i in range(1000)
    ]
    
    chunk_sizes = [100, 250, 500, 1000]
    performance_data = []
    
    for chunk_size in chunk_sizes:
        start_time = time.time()
        result = await processor.process_batch_insert(logs, None, chunk_size=chunk_size)
        processing_time = time.time() - start_time
        
        performance_data.append({
            'chunk_size': chunk_size,
            'processing_time': processing_time,
            'throughput': 1000 / processing_time
        })
        
        print(f"📈 Chunk size {chunk_size}: {processing_time:.3f}s ({1000/processing_time:.0f} logs/sec)")
    
    # Verify all chunk sizes complete successfully
    for data in performance_data:
        assert data['throughput'] > 50  # Minimum acceptable throughput

@pytest.mark.asyncio
async def test_concurrent_batch_processing():
    """Test concurrent batch processing performance"""
    processor = BatchProcessor()
    processor.db_pool = None
    
    # Create multiple batches for concurrent processing
    batches = []
    for batch_num in range(5):
        batch = [
            LogEntry(
                level="INFO",
                service=f"concurrent-service-{batch_num}",
                message=f"Concurrent test batch {batch_num} message {i}"
            )
            for i in range(200)
        ]
        batches.append(batch)
    
    # Process batches concurrently
    start_time = time.time()
    tasks = [
        processor.process_batch_insert(batch, None, chunk_size=100)
        for batch in batches
    ]
    results = await asyncio.gather(*tasks)
    end_time = time.time()
    
    total_processing_time = end_time - start_time
    total_logs = sum(len(batch) for batch in batches)
    concurrent_throughput = total_logs / total_processing_time
    
    print(f"🔄 Concurrent processing: {concurrent_throughput:.0f} logs/sec across {len(batches)} batches")
    
    # Verify all batches completed successfully
    for result in results:
        assert result.success_count == 200
        assert result.error_count == 0
    
    # Concurrent processing should be faster than sequential
    assert concurrent_throughput > 200  # Should achieve good concurrent throughput
