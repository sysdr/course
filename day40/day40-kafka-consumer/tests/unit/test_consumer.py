import pytest
import json
from unittest.mock import Mock, patch
from src.config.kafka_config import KafkaConsumerConfig
from src.consumer.kafka_consumer import KafkaLogConsumer
from src.processor.message_processor import MessageProcessor

class TestKafkaLogConsumer:
    def test_consumer_initialization(self):
        """Test consumer initializes correctly"""
        config = KafkaConsumerConfig()
        consumer = KafkaLogConsumer(config)
        
        assert consumer.config == config
        assert consumer.processed_count == 0
        assert consumer.error_count == 0
        assert not consumer.running
        
    def test_consumer_stats(self):
        """Test consumer statistics calculation"""
        config = KafkaConsumerConfig()
        consumer = KafkaLogConsumer(config)
        
        # Simulate some processing
        consumer.processed_count = 100
        consumer.error_count = 5
        
        stats = consumer.get_stats()
        
        assert stats['processed_count'] == 100
        assert stats['error_count'] == 5
        assert abs(stats['success_rate'] - 95.24) < 0.01
        assert stats['group_id'] == config.group_id

class TestMessageProcessor:
    def test_web_access_log_processing(self):
        """Test web access log processing"""
        processor = MessageProcessor()
        
        log_data = {
            'type': 'web_access',
            'endpoint': '/api/test',
            'status_code': 200,
            'response_time': 50,
            'client_ip': '192.168.1.100'
        }
        
        result = processor.process_log_entry(log_data)
        assert result is True
        assert processor.processed_count == 1
        
        # Check endpoint stats
        stats = processor.endpoint_stats['/api/test']
        assert stats['count'] == 1
        assert stats['total_time'] == 50
        
    def test_error_log_processing(self):
        """Test error log processing"""
        processor = MessageProcessor()
        
        log_data = {
            'type': 'error',
            'error_type': 'TestError',
            'severity': 'high',
            'service': 'test-service'
        }
        
        result = processor.process_log_entry(log_data)
        assert result is True
        assert processor.processed_count == 1
        
    def test_analytics_calculation(self):
        """Test analytics calculation"""
        processor = MessageProcessor()
        
        # Process some test logs
        for i in range(10):
            log_data = {
                'type': 'web_access',
                'endpoint': f'/api/test{i}',
                'status_code': 200,
                'response_time': 50 + i,
                'client_ip': '192.168.1.100'
            }
            processor.process_log_entry(log_data)
            
        analytics = processor.get_analytics()
        
        assert analytics['processed_count'] == 10
        assert len(analytics['endpoint_stats']) == 10
        assert analytics['response_time_percentiles']['p50'] > 0
