import pytest
import asyncio
import json
import time
from datetime import datetime

from src.main import WindowedAnalyticsSystem

@pytest.mark.asyncio
class TestWindowedSystem:
    async def test_end_to_end_processing(self):
        """Test complete system integration"""
        system = WindowedAnalyticsSystem()
        await system.start()
        
        # Generate test events
        test_events = []
        current_time = int(time.time())
        
        for i in range(10):
            event = {
                'timestamp': current_time,
                'service': 'test-service',
                'level': 'INFO',
                'response_time': 100 + i * 10,
                'message': f'Test event {i}'
            }
            test_events.append(event)
            
        # Process events
        for event in test_events:
            normalized = system.time_extractor.normalize_log_entry(
                json.dumps(event)
            )
            await system.aggregation_coordinator.process_log_event(normalized)
            
        # Wait for processing
        await asyncio.sleep(2)
        
        # Verify metrics
        metrics = await system.aggregation_coordinator.get_windowed_metrics('5min', 1)
        assert len(metrics) > 0
        
        latest_window = metrics[0]
        assert latest_window['metrics']['count'] >= len(test_events)
        
    async def test_window_completion_cycle(self):
        """Test complete window lifecycle"""
        system = WindowedAnalyticsSystem()
        await system.start()
        
        # Create window in the past that should complete
        past_time = int(time.time()) - 400  # 6+ minutes ago
        
        event = {
            'timestamp': past_time,
            'service': 'test-service', 
            'level': 'INFO',
            'response_time': 150
        }
        
        normalized = system.time_extractor.normalize_log_entry(json.dumps(event))
        await system.aggregation_coordinator.process_log_event(normalized)
        
        # Trigger window management cycle
        await asyncio.sleep(1)
        
        # Window should be finalized
        metrics = await system.aggregation_coordinator.get_windowed_metrics('5min', 10)
        completed_windows = [m for m in metrics if m['metrics'].get('count', 0) > 0]
        
        assert len(completed_windows) > 0
