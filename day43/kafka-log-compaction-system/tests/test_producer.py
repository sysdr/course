import pytest
import asyncio
from unittest.mock import Mock, patch, AsyncMock
from src.producer.state_producer import StateProducer, AsyncStateProducer
from src.models.user_profile import UserProfile
from src.config.kafka_config import KafkaConfig


class TestStateProducer:
    """Test StateProducer functionality"""
    
    @pytest.fixture
    def mock_kafka_config(self):
        """Mock Kafka configuration"""
        config = Mock(spec=KafkaConfig)
        config.topic_name = "test-topic"
        config.create_producer.return_value = Mock()
        return config
    
    @pytest.fixture
    def test_profile(self):
        """Test user profile"""
        return UserProfile(
            user_id="test_user",
            email="test@email.com",
            first_name="John",
            last_name="Doe",
            age=25
        )
    
    def test_producer_initialization(self, mock_kafka_config):
        """Test producer initialization"""
        producer = StateProducer(mock_kafka_config)
        
        assert producer.kafka_config == mock_kafka_config
        assert producer.topic_name == "test-topic"
        assert producer.producer is not None
    
    @patch('uuid.uuid4')
    def test_send_profile_update(self, mock_uuid, mock_kafka_config, test_profile):
        """Test sending profile update"""
        mock_uuid.return_value.hex = "test-event-id"
        mock_producer = Mock()
        mock_kafka_config.create_producer.return_value = mock_producer
        
        producer = StateProducer(mock_kafka_config)
        result = producer.send_profile_update(test_profile)
        
        # Verify producer.produce was called
        mock_producer.produce.assert_called_once()
        mock_producer.flush.assert_called_once()
        
        assert result is True
    
    def test_send_profile_deletion(self, mock_kafka_config):
        """Test sending profile deletion"""
        mock_producer = Mock()
        mock_kafka_config.create_producer.return_value = mock_producer
        
        producer = StateProducer(mock_kafka_config)
        result = producer.send_profile_deletion("test_user")
        
        mock_producer.produce.assert_called_once()
        mock_producer.flush.assert_called_once()
        
        assert result is True
    
    def test_send_tombstone(self, mock_kafka_config):
        """Test sending tombstone record"""
        mock_producer = Mock()
        mock_kafka_config.create_producer.return_value = mock_producer
        
        producer = StateProducer(mock_kafka_config)
        result = producer.send_tombstone("test_user")
        
        # Verify tombstone (null value) was sent
        args, kwargs = mock_producer.produce.call_args
        assert kwargs['value'] is None
        assert "profile:test_user" in kwargs['key']
        
        assert result is True


class TestAsyncStateProducer:
    """Test AsyncStateProducer functionality"""
    
    @pytest.fixture
    def mock_kafka_config(self):
        """Mock Kafka configuration"""
        config = Mock(spec=KafkaConfig)
        config.topic_name = "test-topic"
        config.create_producer.return_value = Mock()
        return config
    
    @pytest.fixture
    def test_profile(self):
        """Test user profile"""
        return UserProfile(
            user_id="test_user",
            email="test@email.com",
            first_name="John",
            last_name="Doe",
            age=25
        )
    
    @pytest.mark.asyncio
    async def test_async_profile_update(self, mock_kafka_config, test_profile):
        """Test async profile update"""
        async_producer = AsyncStateProducer(mock_kafka_config)
        
        with patch.object(async_producer.producer, 'send_profile_update', return_value=True):
            result = await async_producer.send_profile_update(test_profile)
            assert result is True
    
    @pytest.mark.asyncio
    async def test_async_profile_deletion(self, mock_kafka_config):
        """Test async profile deletion"""
        async_producer = AsyncStateProducer(mock_kafka_config)
        
        with patch.object(async_producer.producer, 'send_profile_deletion', return_value=True):
            result = await async_producer.send_profile_deletion("test_user")
            assert result is True
