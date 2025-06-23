import pytest
from datetime import datetime
from src.models.user_profile import UserProfile, StateUpdate, UpdateType


class TestUserProfile:
    """Test UserProfile model"""
    
    def test_profile_creation(self):
        """Test basic profile creation"""
        profile = UserProfile(
            user_id="test_user",
            email="test@email.com",
            first_name="John",
            last_name="Doe",
            age=25,
            preferences="theme:dark"
        )
        
        assert profile.user_id == "test_user"
        assert profile.email == "test@email.com"
        assert profile.version == 1
        assert not profile.deleted
        assert profile.last_updated is not None
    
    def test_version_increment(self):
        """Test version incrementation"""
        profile = UserProfile(
            user_id="test_user",
            email="test@email.com", 
            first_name="John",
            last_name="Doe"
        )
        
        initial_version = profile.version
        profile.increment_version()
        
        assert profile.version == initial_version + 1
        assert profile.last_updated > datetime.now().replace(microsecond=0)
    
    def test_profile_deletion(self):
        """Test profile deletion marking"""
        profile = UserProfile(
            user_id="test_user",
            email="test@email.com",
            first_name="John", 
            last_name="Doe"
        )
        
        assert not profile.deleted
        
        profile.mark_deleted()
        
        assert profile.deleted
        assert profile.version == 2  # Version incremented
    
    def test_profile_serialization(self):
        """Test profile to dict conversion"""
        profile = UserProfile(
            user_id="test_user",
            email="test@email.com",
            first_name="John",
            last_name="Doe",
            age=25
        )
        
        profile_dict = profile.to_dict()
        
        assert isinstance(profile_dict, dict)
        assert profile_dict['user_id'] == "test_user"
        assert profile_dict['email'] == "test@email.com"
        assert 'last_updated' in profile_dict


class TestStateUpdate:
    """Test StateUpdate model"""
    
    def test_state_update_creation(self):
        """Test state update creation"""
        profile = UserProfile(
            user_id="test_user",
            email="test@email.com",
            first_name="John",
            last_name="Doe"
        )
        
        update = StateUpdate(
            event_id="event_123",
            user_id="test_user",
            update_type=UpdateType.UPDATE,
            profile=profile
        )
        
        assert update.event_id == "event_123"
        assert update.user_id == "test_user"
        assert update.update_type == UpdateType.UPDATE
        assert update.profile == profile
        assert update.timestamp is not None
    
    def test_state_update_serialization(self):
        """Test state update serialization"""
        profile = UserProfile(
            user_id="test_user",
            email="test@email.com",
            first_name="John",
            last_name="Doe"
        )
        
        update = StateUpdate(
            event_id="event_123",
            user_id="test_user",
            update_type=UpdateType.CREATE,
            profile=profile
        )
        
        update_dict = update.to_dict()
        
        assert isinstance(update_dict, dict)
        assert update_dict['event_id'] == "event_123"
        assert update_dict['update_type'] == UpdateType.CREATE
        assert 'timestamp' in update_dict
