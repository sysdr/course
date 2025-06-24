import pytest
import json
from unittest.mock import Mock, patch
from src.reliable_consumer import ReliableConsumer

class TestReliableConsumer:
    def test_consumer_initialization(self):
        callback = Mock()
        consumer = ReliableConsumer(callback)
        
        assert consumer.processing_callback == callback
        assert consumer.connection is None
        assert consumer.channel is None
        assert not consumer.is_consuming
    
    @patch('pika.BlockingConnection')
    def test_connection_setup(self, mock_connection):
        mock_channel = Mock()
        mock_connection.return_value.channel.return_value = mock_channel
        
        callback = Mock()
        consumer = ReliableConsumer(callback)
        consumer.connect()
        
        assert consumer.connection is not None
        assert consumer.channel is not None
        mock_channel.basic_qos.assert_called_once()
        mock_channel.exchange_declare.assert_called()
        mock_channel.queue_declare.assert_called()
    
    def test_message_processing_success(self):
        processed_data = None
        
        def test_callback(data):
            nonlocal processed_data
            processed_data = data
        
        consumer = ReliableConsumer(test_callback)
        
        # Mock the channel and method objects
        mock_channel = Mock()
        mock_method = Mock()
        mock_method.delivery_tag = 123
        mock_method.routing_key = 'test.route'
        
        test_message = {"test": "data", "id": "test123"}
        body = json.dumps(test_message).encode('utf-8')
        
        # Simulate successful processing
        consumer.channel = mock_channel
        consumer._on_message(mock_channel, mock_method, None, body)
        
        # Verify message was processed
        assert processed_data is not None
        assert processed_data['test'] == 'data'
        assert processed_data['_delivery_tag'] == 123
        
        # Verify acknowledgment was called
        mock_channel.basic_ack.assert_called_once_with(delivery_tag=123)
    
    def test_invalid_json_handling(self):
        callback = Mock()
        consumer = ReliableConsumer(callback)
        
        mock_channel = Mock()
        mock_method = Mock()
        mock_method.delivery_tag = 456
        
        # Invalid JSON
        body = b'{"invalid": json}'
        
        consumer.channel = mock_channel
        consumer._on_message(mock_channel, mock_method, None, body)
        
        # Should reject message without requeue (fatal error)
        mock_channel.basic_nack.assert_called_once_with(delivery_tag=456, requeue=False)
        
        # Processing callback should not be called
        callback.assert_not_called()
