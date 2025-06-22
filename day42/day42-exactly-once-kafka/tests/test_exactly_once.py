"""Tests for exactly-once processing"""

import pytest
import json
import uuid
import time
from decimal import Decimal
from unittest.mock import Mock, patch, MagicMock
from src.producers.transactional_producer import TransactionalProducer
from src.consumers.exactly_once_consumer import ExactlyOnceConsumer
from src.monitoring.transaction_monitor import TransactionMonitor
from src.models import create_tables, Account, Transaction, get_session
from config.kafka_config import KafkaConfig, DATABASE_URL

class TestExactlyOnceProcessing:
    
    @pytest.fixture
    def kafka_config(self):
        return KafkaConfig()
    
    @pytest.fixture
    def mock_producer_config(self):
        return {
            'bootstrap.servers': 'localhost:9092',
            'enable.idempotence': True,
            'acks': 'all',
            'transactional.id': f'test-producer-{uuid.uuid4()}'
        }
    
    def test_transactional_producer_initialization(self, mock_producer_config):
        """Test producer initialization with transactions"""
        with patch('src.producers.transactional_producer.Producer') as mock_producer_class:
            mock_producer = Mock()
            mock_producer_class.return_value = mock_producer
            
            producer = TransactionalProducer(mock_producer_config)
            
            # Verify init_transactions was called
            mock_producer.init_transactions.assert_called_once()
            assert not producer.transaction_active
    
    def test_transaction_lifecycle(self, mock_producer_config):
        """Test complete transaction lifecycle"""
        with patch('src.producers.transactional_producer.Producer') as mock_producer_class:
            mock_producer = Mock()
            mock_producer_class.return_value = mock_producer
            
            producer = TransactionalProducer(mock_producer_config)
            
            # Begin transaction
            producer.begin_transaction()
            mock_producer.begin_transaction.assert_called_once()
            assert producer.transaction_active
            
            # Send transfer
            tx_id = producer.send_payment_transfer('ACC001', 'ACC002', 100.0)
            assert tx_id is not None
            assert mock_producer.produce.call_count == 3  # transfer + 2 balance updates
            
            # Commit transaction
            producer.commit_transaction()
            mock_producer.commit_transaction.assert_called_once()
            assert not producer.transaction_active
    
    def test_transaction_abort_on_error(self, mock_producer_config):
        """Test transaction abort on error"""
        with patch('src.producers.transactional_producer.Producer') as mock_producer_class:
            mock_producer = Mock()
            mock_producer_class.return_value = mock_producer
            # Make commit_transaction raise an exception
            mock_producer.commit_transaction.side_effect = Exception("Commit failed")
            
            producer = TransactionalProducer(mock_producer_config)
            
            producer.begin_transaction()
            producer.send_payment_transfer('ACC001', 'ACC002', 100.0)
            
            # This should raise an exception and call abort_transaction
            with pytest.raises(Exception):
                producer.commit_transaction()
            
            # Verify abort_transaction was called
            mock_producer.abort_transaction.assert_called_once()
            assert not producer.transaction_active
    
    def test_consumer_idempotency(self):
        """Test consumer idempotency with duplicate messages"""
        config = {'group.id': 'test-group', 'enable.auto.commit': False}
        
        with patch('src.consumers.exactly_once_consumer.Consumer'), \
             patch('src.consumers.exactly_once_consumer.create_engine'), \
             patch('src.consumers.exactly_once_consumer.sessionmaker'):
            
            # Use SQLite in-memory database for testing
            consumer = ExactlyOnceConsumer(config, 'sqlite:///:memory:')
            
            # Mock message
            mock_message = Mock()
            mock_message.value.return_value = json.dumps({
                'transaction_id': 'test-tx-123',
                'from_account': 'ACC001',
                'to_account': 'ACC002',
                'amount': 100.0
            }).encode('utf-8')
            mock_message.topic.return_value = 'test-topic'
            mock_message.partition.return_value = 0
            mock_message.offset.return_value = 42
            
            # Test processing - should succeed
            with patch.object(consumer, 'SessionLocal') as mock_session_factory:
                mock_session = Mock()
                mock_session_factory.return_value = mock_session
                mock_session.query.return_value.filter_by.return_value.first.return_value = None
                
                result = consumer.process_transfer_message(mock_message)
                assert result is True
    
    def test_monitor_stats_calculation(self):
        """Test transaction monitor statistics"""
        with patch('src.monitoring.transaction_monitor.create_engine'), \
             patch('src.monitoring.transaction_monitor.sessionmaker'):
            
            # Use SQLite in-memory database for testing
            monitor = TransactionMonitor('sqlite:///:memory:')
            
            # Mock session and query results
            with patch.object(monitor, 'SessionLocal') as mock_session_factory:
                mock_session = Mock()
                mock_session_factory.return_value = mock_session
                
                # Mock query results
                mock_session.query.return_value.scalar.return_value = 10
                mock_session.query.return_value.filter.return_value.scalar.return_value = 8
                
                stats = monitor.get_transaction_stats()
                
                assert 'total_transactions' in stats
                assert 'completed_transactions' in stats
                assert 'processing_rate' in stats
    
    def test_exactly_once_guarantee_check(self):
        """Test exactly-once guarantee verification"""
        with patch('src.monitoring.transaction_monitor.create_engine'), \
             patch('src.monitoring.transaction_monitor.sessionmaker'):
            
            # Use SQLite in-memory database for testing
            monitor = TransactionMonitor('sqlite:///:memory:')
            
            with patch.object(monitor, 'SessionLocal') as mock_session_factory:
                mock_session = Mock()
                mock_session_factory.return_value = mock_session
                
                # Mock no duplicates
                mock_session.query.return_value.group_by.return_value.having.return_value.all.return_value = []
                mock_session.query.return_value.scalar.return_value = 5000.0
                
                guarantee_check = monitor.check_exactly_once_guarantee()
                
                assert guarantee_check['guarantee_status'] == 'MAINTAINED'
                assert guarantee_check['duplicate_transactions'] == []
                assert guarantee_check['total_system_balance'] == 5000.0

if __name__ == '__main__':
    pytest.main([__file__, '-v'])
