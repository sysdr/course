import pytest
from src.models.user_profile import UserProfile
from datetime import datetime, timedelta


class TestCompactionLogic:
    """Test log compaction logic simulation"""
    
    def test_state_compaction_simulation(self):
        """Test simulated compaction logic"""
        # Simulate multiple updates for same user
        state = {}
        
        # Version 1
        profile_v1 = UserProfile(
            user_id="user_001",
            email="old@email.com",
            first_name="John",
            last_name="Doe",
            age=25,
            preferences="theme:dark"
        )
        profile_v1.last_updated = datetime.now() - timedelta(hours=2)
        
        # Version 2  
        profile_v2 = UserProfile(
            user_id="user_001",
            email="new@email.com",
            first_name="John",
            last_name="Doe",
            age=26,
            preferences="theme:light"
        )
        profile_v2.version = 2
        profile_v2.last_updated = datetime.now() - timedelta(hours=1)
        
        # Version 3
        profile_v3 = UserProfile(
            user_id="user_001",
            email="newest@email.com",
            first_name="John",
            last_name="Doe",
            age=27,
            preferences="theme:auto"
        )
        profile_v3.version = 3
        profile_v3.last_updated = datetime.now()
        
        # Simulate compaction logic - keep only latest version
        state[profile_v1.user_id] = profile_v1
        
        # Update with v2 (newer)
        if profile_v2.version > state[profile_v2.user_id].version:
            state[profile_v2.user_id] = profile_v2
        
        # Update with v3 (newest)
        if profile_v3.version > state[profile_v3.user_id].version:
            state[profile_v3.user_id] = profile_v3
        
        # Verify only latest version is kept
        final_profile = state["user_001"]
        assert final_profile.version == 3
        assert final_profile.email == "newest@email.com"
        assert final_profile.age == 27
    
    def test_tombstone_handling(self):
        """Test tombstone record handling"""
        state = {}
        
        # Add a profile
        profile = UserProfile(
            user_id="user_001",
            email="test@email.com",
            first_name="John",
            last_name="Doe",
            age=25
        )
        state[profile.user_id] = profile
        
        assert "user_001" in state
        
        # Simulate tombstone (null value) - profile should be removed
        del state["user_001"]
        
        assert "user_001" not in state
        assert len(state) == 0
    
    def test_compaction_effectiveness(self):
        """Test compaction effectiveness calculation"""
        # Simulate message counts
        total_messages = 100
        unique_keys = 25
        
        compaction_ratio = unique_keys / total_messages
        storage_saved_percent = (1 - compaction_ratio) * 100
        
        assert compaction_ratio == 0.25
        assert storage_saved_percent == 75.0
        
        # Test with different scenarios
        scenarios = [
            (50, 10, 80.0),   # High compaction
            (100, 50, 50.0),  # Medium compaction  
            (100, 90, 10.0),  # Low compaction
        ]
        
        for total, unique, expected_savings in scenarios:
            ratio = unique / total
            savings = (1 - ratio) * 100
            assert abs(savings - expected_savings) < 0.0001  # Tolerance for floating point
