"""
Integration tests for RabbitMQ message queue setup.
"""
import pytest
import time
import json
from message_queue.rabbitmq_setup import RabbitMQSetup
from message_queue.queue_manager import QueueManager
from message_queue.health_checker import HealthChecker

class TestRabbitMQSetup:
    def test_connection(self):
        """Test RabbitMQ connection."""
        setup = RabbitMQSetup()
        assert setup.connect(), "Should connect to RabbitMQ"
        setup.close_connection()
        
    def test_queue_creation(self):
        """Test queue and exchange creation."""
        setup = RabbitMQSetup()
        assert setup.connect(), "Should connect to RabbitMQ"
        
        try:
            setup.setup_exchanges()
            setup.setup_queues()
            
            # Verify queues exist
            queues = ['log_messages', 'error_messages', 'debug_messages']
            for queue_name in queues:
                method = setup.channel.queue_declare(queue=queue_name, passive=True)
                assert method.method.message_count >= 0
                
        finally:
            setup.close_connection()
            
class TestQueueManager:
    def test_message_publishing(self):
        """Test message publishing and retrieval."""
        manager = QueueManager()
        assert manager.connect(), "Should connect to RabbitMQ"
        
        try:
            # Publish test message
            test_message = {'test': 'data', 'timestamp': time.time()}
            assert manager.publish_message('logs.info.test', test_message)
            
            # Check queue info
            info = manager.get_queue_info('log_messages')
            assert info is not None
            assert info['message_count'] >= 0
            
        finally:
            manager.close()
            
class TestHealthChecker:
    def test_health_check(self):
        """Test health monitoring."""
        checker = HealthChecker()
        
        # Test connection check
        connection_status = checker.check_connection()
        assert connection_status['status'] in ['healthy', 'unhealthy']
        
        # Test health report generation
        report = checker.generate_health_report()
        assert 'overall_status' in report
        assert 'connection' in report
        assert 'queues' in report
        
if __name__ == "__main__":
    pytest.main([__file__, "-v"])
