import pytest
import asyncio
import time
from src.processor import LogProcessor

@pytest.mark.asyncio
async def test_end_to_end_processing():
    """Test complete message processing pipeline"""
    processor = LogProcessor(num_workers=2)
    
    try:
        await processor.start()
        
        # Inject messages of different priorities
        test_messages = [
            {'level': 'ERROR', 'message': 'Payment failed', 'service': 'payment'},  # Critical
            {'level': 'DEBUG', 'message': 'Query executed', 'service': 'database'},  # Low
            {'level': 'WARN', 'message': 'High latency', 'service': 'api'},  # High
        ]
        
        # Process messages
        for msg in test_messages:
            assert processor.process_log_message(msg) == True
        
        # Wait for processing
        await asyncio.sleep(1)
        
        # Check status
        status = processor.get_queue_status()
        assert status['metrics']['messages_received'] == 3
        
        # Check that critical message was processed first
        processed = processor.get_processed_messages()
        if len(processed) > 0:
            # First processed message should be critical priority
            first_processed = processed[0]
            assert first_processed['priority'] == 'CRITICAL'  # Check priority level
            
    finally:
        await processor.stop()

@pytest.mark.asyncio
async def test_high_load_processing():
    """Test processing under high load"""
    processor = LogProcessor(num_workers=4)
    
    try:
        await processor.start()
        
        # Generate many messages
        messages = []
        for i in range(100):
            msg = {
                'level': 'INFO' if i % 2 == 0 else 'DEBUG',
                'message': f'Test message {i}',
                'service': 'test-service'
            }
            messages.append(msg)
        
        # Process all messages
        successful = 0
        for msg in messages:
            if processor.process_log_message(msg):
                successful += 1
        
        assert successful == 100
        
        # Wait for processing to complete
        await asyncio.sleep(2)
        
        status = processor.get_queue_status()
        assert status['metrics']['messages_received'] == 100
        
    finally:
        await processor.stop()

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
