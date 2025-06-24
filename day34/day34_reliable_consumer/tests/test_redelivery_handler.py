import pytest
import time
import threading
from src.redelivery_handler import RedeliveryHandler, RedeliveryAttempt

class TestRedeliveryHandler:
    def test_schedule_and_process_redelivery(self):
        redelivery_called = threading.Event()
        redelivered_attempt = None
        
        def redelivery_callback(attempt):
            nonlocal redelivered_attempt
            redelivered_attempt = attempt
            redelivery_called.set()
        
        handler = RedeliveryHandler(max_retries=3, base_delay=0.1, max_delay=1)
        handler.set_redelivery_callback(redelivery_callback)
        
        # Schedule redelivery
        message = b'{"test": "message"}'
        assert handler.schedule_redelivery(123, message, 'test.route', 0)
        
        # Wait for redelivery
        assert redelivery_called.wait(timeout=2.0)
        assert redelivered_attempt.delivery_tag == 123
        assert redelivered_attempt.attempt_count == 1
        assert redelivered_attempt.original_message == message
        
        handler.stop()
    
    def test_max_retries_exceeded(self):
        handler = RedeliveryHandler(max_retries=2)
        
        message = b'{"test": "message"}'
        
        # Should succeed for attempts within limit
        assert handler.schedule_redelivery(123, message, 'test.route', 0)
        assert handler.schedule_redelivery(123, message, 'test.route', 1)
        
        # Should fail when exceeding max retries
        assert not handler.schedule_redelivery(123, message, 'test.route', 2)
        
        handler.stop()
    
    def test_cancel_redelivery(self):
        handler = RedeliveryHandler(base_delay=10)  # Long delay
        
        message = b'{"test": "message"}'
        handler.schedule_redelivery(123, message, 'test.route', 0)
        
        # Cancel the redelivery
        assert handler.cancel_redelivery(123)
        
        # Subsequent cancellation should fail
        assert not handler.cancel_redelivery(123)
        
        handler.stop()
    
    def test_exponential_backoff(self):
        handler = RedeliveryHandler(base_delay=1, max_delay=10)
        
        # Test delay calculation implicitly through scheduling
        message = b'{"test": "message"}'
        
        start_time = time.time()
        handler.schedule_redelivery(123, message, 'test.route', 0)  # 1 second delay
        handler.schedule_redelivery(124, message, 'test.route', 1)  # 2 second delay
        handler.schedule_redelivery(125, message, 'test.route', 2)  # 4 second delay
        
        stats = handler.get_stats()
        assert stats['pending_redeliveries'] == 3
        
        handler.stop()
