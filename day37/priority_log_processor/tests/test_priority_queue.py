import pytest
import time
from src.priority_queue import PriorityQueue, Message, Priority

class TestPriorityQueue:
    def test_basic_operations(self):
        """Test basic queue operations"""
        queue = PriorityQueue(max_size=10)
        
        # Test put and size
        msg = Message(Priority.HIGH, time.time(), {"test": "data"}, "msg-1")
        assert queue.put(msg) == True
        assert queue.size() == 1
        
        # Test get
        retrieved = queue.get()
        assert retrieved is not None
        assert retrieved.message_id == "msg-1"
        assert queue.size() == 0
    
    def test_priority_ordering(self):
        """Test that messages are retrieved in priority order"""
        queue = PriorityQueue()
        
        # Add messages in random priority order
        messages = [
            Message(Priority.LOW, time.time(), {}, "low-1"),
            Message(Priority.CRITICAL, time.time(), {}, "critical-1"),
            Message(Priority.MEDIUM, time.time(), {}, "medium-1"),
            Message(Priority.HIGH, time.time(), {}, "high-1")
        ]
        
        for msg in messages:
            queue.put(msg)
        
        # Retrieve messages - should come out in priority order
        retrieved_priorities = []
        while queue.size() > 0:
            msg = queue.get()
            retrieved_priorities.append(msg.priority)
        
        expected = [Priority.CRITICAL, Priority.HIGH, Priority.MEDIUM, Priority.LOW]
        assert retrieved_priorities == expected
    
    def test_max_size_limit(self):
        """Test queue size limit"""
        queue = PriorityQueue(max_size=2)
        
        msg1 = Message(Priority.HIGH, time.time(), {}, "msg-1")
        msg2 = Message(Priority.HIGH, time.time(), {}, "msg-2")
        msg3 = Message(Priority.HIGH, time.time(), {}, "msg-3")
        
        assert queue.put(msg1) == True
        assert queue.put(msg2) == True
        assert queue.put(msg3) == False  # Should fail - queue full
        assert queue.size() == 2
    
    def test_metrics_tracking(self):
        """Test metrics are properly tracked"""
        queue = PriorityQueue()
        
        critical_msg = Message(Priority.CRITICAL, time.time(), {}, "critical-1")
        high_msg = Message(Priority.HIGH, time.time(), {}, "high-1")
        
        queue.put(critical_msg)
        queue.put(high_msg)
        
        metrics = queue.get_metrics()
        assert metrics['total_messages'] == 2
        assert metrics['queue_critical'] == 1
        assert metrics['queue_high'] == 1
        
        # Process one message
        queue.get()
        metrics = queue.get_metrics()
        assert metrics['processed_critical'] == 1

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
