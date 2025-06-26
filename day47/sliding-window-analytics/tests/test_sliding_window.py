import pytest
import asyncio
import time
from src.core.sliding_window import SlidingWindow, Event, SlidingWindowManager

class TestSlidingWindow:
    def test_sliding_window_creation(self):
        """Test sliding window initialization"""
        window = SlidingWindow(window_size=10.0, slide_interval=2.0)
        assert window.window_size == 10.0
        assert window.slide_interval == 2.0
        assert len(window.events) == 0
    
    def test_add_single_event(self):
        """Test adding a single event"""
        window = SlidingWindow(window_size=10.0, slide_interval=2.0)
        event = Event(timestamp=time.time(), value=100.0, metadata={}, event_id="test1")
        window.add_event(event)
        
        stats = window.get_current_stats()
        assert stats is not None
        assert stats.count == 1
        assert stats.average == 100.0
        assert stats.sum == 100.0
    
    def test_sliding_window_expiration(self):
        """Test that old events are expired"""
        window = SlidingWindow(window_size=5.0, slide_interval=1.0)
        current_time = time.time()
        
        # Add old event (should be expired)
        old_event = Event(timestamp=current_time - 10, value=50.0, metadata={}, event_id="old")
        window.add_event(old_event)
        
        # Add recent event
        recent_event = Event(timestamp=current_time, value=100.0, metadata={}, event_id="recent")
        window.add_event(recent_event)
        
        stats = window.get_current_stats()
        assert stats.count == 1  # Only recent event should remain
        assert stats.average == 100.0
    
    def test_incremental_statistics(self):
        """Test incremental statistics calculation"""
        window = SlidingWindow(window_size=10.0, slide_interval=2.0)
        current_time = time.time()
        
        # Add multiple events
        values = [10.0, 20.0, 30.0, 40.0, 50.0]
        for i, value in enumerate(values):
            event = Event(timestamp=current_time + i, value=value, metadata={}, event_id=f"test{i}")
            window.add_event(event)
        
        stats = window.get_current_stats()
        assert stats.count == 5
        assert stats.average == 30.0  # (10+20+30+40+50)/5
        assert stats.sum == 150.0
        assert stats.min_value == 10.0
        assert stats.max_value == 50.0
    
    def test_memory_bounded_operation(self):
        """Test that memory usage is bounded"""
        window = SlidingWindow(window_size=10.0, slide_interval=1.0, max_size=100)
        
        # Add more events than max_size
        for i in range(150):
            event = Event(timestamp=time.time(), value=float(i), metadata={}, event_id=f"test{i}")
            window.add_event(event)
        
        # Should not exceed max_size
        assert len(window.events) <= 100

class TestSlidingWindowManager:
    def test_manager_creation(self):
        """Test sliding window manager initialization"""
        manager = SlidingWindowManager(window_size=10.0, slide_interval=2.0)
        assert len(manager.windows) == 0
    
    def test_multiple_metric_windows(self):
        """Test managing multiple metric windows"""
        manager = SlidingWindowManager(window_size=10.0, slide_interval=2.0)
        
        # Add metrics for different types
        manager.add_metric("response_time", 100.0)
        manager.add_metric("throughput", 500.0)
        manager.add_metric("error_rate", 2.5)
        
        assert len(manager.windows) == 3
        
        stats = manager.get_all_current_stats()
        assert "response_time" in stats
        assert "throughput" in stats
        assert "error_rate" in stats
        assert stats["response_time"].average == 100.0
    
    def test_concurrent_metric_updates(self):
        """Test concurrent updates to different metrics"""
        manager = SlidingWindowManager(window_size=10.0, slide_interval=2.0)
        
        # Simulate concurrent metric updates
        metrics = [
            ("response_time", [100, 150, 120, 180, 95]),
            ("throughput", [500, 600, 550, 700, 480]),
            ("error_rate", [1.0, 2.5, 1.8, 3.2, 0.9])
        ]
        
        for metric_name, values in metrics:
            for value in values:
                manager.add_metric(metric_name, value)
        
        stats = manager.get_all_current_stats()
        assert len(stats) == 3
        
        # Verify averages
        assert abs(stats["response_time"].average - 129.0) < 1.0
        assert abs(stats["throughput"].average - 566.0) < 1.0
        assert abs(stats["error_rate"].average - 1.88) < 0.1

@pytest.mark.asyncio
async def test_performance_under_load():
    """Test performance with high event rate"""
    window = SlidingWindow(window_size=30.0, slide_interval=5.0)
    
    start_time = time.time()
    num_events = 1000
    
    # Add many events quickly
    for i in range(num_events):
        event = Event(timestamp=time.time(), value=float(i), metadata={}, event_id=f"perf{i}")
        window.add_event(event)
    
    end_time = time.time()
    processing_time = end_time - start_time
    
    # Should process 1000 events in under 1 second
    assert processing_time < 1.0
    
    stats = window.get_current_stats()
    assert stats.count <= num_events  # Some may have expired
    
    print(f"Processed {num_events} events in {processing_time:.3f} seconds")
    print(f"Rate: {num_events/processing_time:.0f} events/second")

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
