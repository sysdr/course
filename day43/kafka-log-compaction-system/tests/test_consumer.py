import pytest
from unittest.mock import Mock, patch
from src.consumer.state_consumer import StateConsumer
from src.models.user_profile import UserProfile
from src.config.kafka_config import KafkaConfig


class TestStateConsumer:
    """Test StateConsumer functionality"""
    
    @pytest.fixture
    def mock_kafka_config(self):
        """Mock Kafka configuration"""
        config = Mock(spec=KafkaConfig)
        config.topic_name = "test-topic"
        config.consumer_config = {'group_id': 'test-group'}
        config.create_consumer.return_value = Mock()
        return config
    
    def test_consumer_initialization(self, mock_kafka_config):
        """Test consumer initialization"""
        consumer = StateConsumer(mock_kafka_config)
        
        assert consumer.kafka_config == mock_kafka_config
        assert consumer.topic_name == "test-topic"
        assert consumer.current_state == {}
        assert not consumer.running
    
    def test_get_state_stats(self, mock_kafka_config):
        """Test state statistics"""
        consumer = StateConsumer(mock_kafka_config)
        
        # Add test profiles
        profile1 = UserProfile(
            user_id="user1",
            email="user1@test.com",
            first_name="User",
            last_name="One"
        )
        
        profile2 = UserProfile(
            user_id="user2", 
            email="user2@test.com",
            first_name="User",
            last_name="Two"
        ).mark_deleted()
        
        consumer.current_state["user1"] = profile1
        consumer.current_state["user2"] = profile2
        
        stats = consumer.get_state_stats()
        
        assert stats['total_profiles'] == 2
        assert stats['active_profiles'] == 1
        assert stats['deleted_profiles'] == 1
    
    def test_get_user_profile(self, mock_kafka_config):
        """Test getting specific user profile"""
        consumer = StateConsumer(mock_kafka_config)
        
        profile = UserProfile(
            user_id="test_user",
            email="test@email.com",
            first_name="Test",
            last_name="User"
        )
        
        consumer.current_state["test_user"] = profile
        
        retrieved = consumer.get_user_profile("test_user")
        assert retrieved == profile
        
        not_found = consumer.get_user_profile("missing_user")
        assert not_found is None
    
    def test_get_state_size(self, mock_kafka_config):
        """Test getting state size"""
        consumer = StateConsumer(mock_kafka_config)
        
        assert consumer.get_state_size() == 0
        
        profile = UserProfile(
            user_id="test_user",
            email="test@email.com",
            first_name="Test",
            last_name="User"
        )
        
        consumer.current_state["test_user"] = profile
        
        assert consumer.get_state_size() == 1
