import pytest
import time
import threading
from src.ack_tracker import AckTracker, MessageStatus

class TestAckTracker:
    def test_track_and_acknowledge_message(self):
        tracker = AckTracker(timeout_seconds=1)
        
        # Track a message
        tracker.track_message(123)
        state = tracker.get_message_state(123)
        assert state.status == MessageStatus.PENDING
        
        # Mark as processing
        assert tracker.mark_processing(123)
        state = tracker.get_message_state(123)
        assert state.status == MessageStatus.PROCESSING
        
        # Acknowledge
        assert tracker.acknowledge(123)
        # Message should be removed after acknowledgment
        state = tracker.get_message_state(123)
        assert state is None
    
    def test_mark_failed_message(self):
        tracker = AckTracker()
        
        tracker.track_message(456)
        tracker.mark_processing(456)
        
        # Mark as failed
        assert tracker.mark_failed(456, "Test error")
        state = tracker.get_message_state(456)
        assert state.status == MessageStatus.FAILED
        assert state.last_error == "Test error"
        assert state.retry_count == 1
    
    def test_timeout_detection(self):
        timeout_called = threading.Event()
        timed_out_tag = None
        
        def timeout_callback(delivery_tag):
            nonlocal timed_out_tag
            timed_out_tag = delivery_tag
            timeout_called.set()
        
        tracker = AckTracker(timeout_seconds=0.1)  # Very short timeout
        tracker.set_timeout_callback(timeout_callback)
        
        # Track message but don't acknowledge
        tracker.track_message(789)
        tracker.mark_processing(789)
        
        # Wait for timeout
        assert timeout_called.wait(timeout=2.0)
        assert timed_out_tag == 789
        
        tracker.stop()
    
    def test_stats_collection(self):
        tracker = AckTracker()
        
        # Track multiple messages in different states
        tracker.track_message(1)  # Will stay pending
        
        tracker.track_message(2)
        tracker.mark_processing(2)
        
        tracker.track_message(3)
        tracker.mark_processing(3)
        tracker.mark_failed(3, "error")
        
        stats = tracker.get_stats()
        assert stats[MessageStatus.PENDING.value] == 1
        assert stats[MessageStatus.PROCESSING.value] == 1
        assert stats[MessageStatus.FAILED.value] == 1
        
        tracker.stop()
