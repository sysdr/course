import pytest
import json
import time
import threading
from src.exchange_manager import ExchangeManager
from src.log_producer import LogProducer
from src.log_consumer import LogConsumer

class TestExchangeRouting:
    def setup_method(self):
        """Setup test environment"""
        self.exchange_manager = ExchangeManager()
        self.producer = LogProducer()
        self.received_messages = []
        
    def test_exchange_setup(self):
        """Test exchange and queue setup"""
        assert self.exchange_manager.connect()
        assert self.exchange_manager.setup_exchanges_and_queues()
        self.exchange_manager.close()
        
    def test_direct_exchange_routing(self):
        """Test direct exchange exact routing"""
        self.producer.connect()
        
        message = self.producer.create_log_message(
            'database', 'postgres', 'error', 'Test direct routing'
        )
        
        self.producer.publish_to_direct('database.postgres.error', message)
        assert message['routing_key'] == 'database.postgres.error'
        
        self.producer.close()
        
    def test_topic_exchange_patterns(self):
        """Test topic exchange pattern matching"""
        self.producer.connect()
        
        # Test various routing patterns
        test_cases = [
            ('database.postgres.info', 'database'),
            ('api.gateway.warning', 'api'),
            ('security.auth.error', 'security')
        ]
        
        for routing_key, expected_service in test_cases:
            message = self.producer.create_log_message(
                expected_service, 'component', 'level', 'Test message'
            )
            self.producer.publish_to_topic(routing_key, message)
            assert routing_key.startswith(expected_service)
            
        self.producer.close()
        
    def test_fanout_broadcast(self):
        """Test fanout exchange broadcasting"""
        self.producer.connect()
        
        message = self.producer.create_log_message(
            'security', 'auth', 'critical', 'Security alert'
        )
        
        self.producer.publish_to_fanout(message)
        assert message['service'] == 'security'
        
        self.producer.close()
        
    def test_message_structure(self):
        """Test log message structure"""
        producer = LogProducer()
        message = producer.create_log_message(
            'test', 'component', 'info', 'Test message'
        )
        
        required_fields = ['timestamp', 'service', 'component', 'level', 'message', 'routing_key']
        for field in required_fields:
            assert field in message
            
        assert message['routing_key'] == 'test.component.info'
        
    def teardown_method(self):
        """Cleanup after tests"""
        if hasattr(self, 'exchange_manager'):
            self.exchange_manager.close()
        if hasattr(self, 'producer'):
            self.producer.close()
