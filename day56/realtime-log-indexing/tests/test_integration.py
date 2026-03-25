import pytest
import asyncio
import json
import time
from datetime import datetime
from unittest.mock import patch, AsyncMock

from src.stream.processor import StreamProcessor
from src.index.manager import IndexManager
from src.search.interface import SearchInterface

@pytest.mark.asyncio
async def test_end_to_end_integration():
    """Test complete end-to-end flow"""
    
    # Mock Redis for testing
    mock_redis = AsyncMock()
    mock_redis.ping = AsyncMock(return_value=True)
    mock_redis.xgroup_create = AsyncMock()
    mock_redis.xreadgroup = AsyncMock()
    mock_redis.xack = AsyncMock()
    mock_redis.xadd = AsyncMock()
    mock_redis.close = AsyncMock()
    
    # Setup test data
    test_messages = [
        {
            'timestamp': datetime.now().isoformat(),
            'level': 'INFO',
            'service': 'web-api',
            'message': 'User login successful',
            'metadata': {'user_id': 'user_123', 'ip': '192.168.1.1'}
        },
        {
            'timestamp': datetime.now().isoformat(),
            'level': 'ERROR',
            'service': 'payment-service',
            'message': 'Payment processing failed',
            'metadata': {'order_id': 'order_456', 'amount': 99.99}
        }
    ]
    
    # Mock Redis stream messages
    mock_redis.xreadgroup.return_value = [
        (b'log_stream', [
            (b'1234567890-0', {b'data': json.dumps(test_messages[0]).encode()}),
            (b'1234567891-0', {b'data': json.dumps(test_messages[1]).encode()})
        ])
    ]
    
    with patch('redis.asyncio.from_url', return_value=mock_redis):
        # Initialize components
        stream_processor = StreamProcessor()
        await stream_processor.connect()
        
        index_manager = IndexManager()
        await index_manager.initialize()
        
        search_interface = SearchInterface(index_manager)
        
        # Simulate processing messages
        processed_count = 0
        async for log_entry in stream_processor.consume_log_stream():
            await index_manager.add_document(log_entry)
            processed_count += 1
            
            if processed_count >= 2:  # Process both test messages
                break
        
        # Test search functionality
        results = await search_interface.search_logs("user login", {}, 10)
        assert results['total_count'] >= 1
        
        results = await search_interface.search_logs("payment", {"service": "payment-service"}, 10)
        assert results['total_count'] >= 1
        
        # Verify stats
        stats = index_manager.get_stats()
        assert stats['total_documents'] >= 2
        
        search_stats = search_interface.get_stats()
        assert search_stats['searches_performed'] >= 2
        
        await stream_processor.disconnect()

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
