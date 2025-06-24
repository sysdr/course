import pytest
import json
from datetime import datetime, timedelta
from src.main.kafka_dashboard import StreamProcessor

class TestStreamProcessor:
    def setup_method(self):
        self.processor = StreamProcessor()
        
    def test_process_message(self):
        """Test message processing"""
        test_data = {
            'timestamp': datetime.now().isoformat(),
            'status_code': 200,
            'response_time': 150
        }
        
        self.processor.process_message(test_data, 'log-events')
        
        assert len(self.processor.metrics['log-events_count']) == 1
        assert len(self.processor.metrics['response_time']) == 1
        
    def test_error_event_processing(self):
        """Test error event processing"""
        error_data = {
            'error_type': 'DatabaseError',
            'severity': 'high',
            'timestamp': datetime.now().isoformat()
        }
        
        self.processor.process_error_event(error_data, datetime.now())
        
        assert len(self.processor.metrics['error_rate']) == 1
        
    def test_windowed_metrics(self):
        """Test windowed metrics calculation"""
        # Add test data
        now = datetime.now()
        for i in range(10):
            self.processor.metrics['log-events_count'].append({
                'timestamp': now - timedelta(seconds=i),
                'value': 1
            })
            
        metrics = self.processor.get_windowed_metrics()
        
        assert 'log-events_count_rate' in metrics
        assert metrics['log-events_count_rate'] > 0
        
    def test_historical_data(self):
        """Test historical data retrieval"""
        # Add test data
        now = datetime.now()
        for i in range(5):
            self.processor.metrics['error_rate'].append({
                'timestamp': now - timedelta(minutes=i),
                'error_type': 'TestError'
            })
            
        historical = self.processor.get_historical_data(minutes=10)
        
        assert 'timestamps' in historical
        assert 'error_rates' in historical
        assert len(historical['timestamps']) == 10
