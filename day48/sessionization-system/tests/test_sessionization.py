import pytest
import asyncio
import time
from unittest.mock import Mock, patch
import json

from src.engine.sessionizer import DistributedSessionizer, UserEvent, Session
from src.analytics.analyzer import SessionAnalyzer
from config.settings import SessionizationConfig

@pytest.fixture
def config():
    return SessionizationConfig(
        redis_host="localhost",
        redis_port=6379,
        session_timeout=1800,
        max_session_duration=14400
    )

@pytest.fixture
def mock_redis():
    with patch('redis.asyncio.Redis') as mock:
        redis_instance = Mock()
        redis_instance.ping = Mock(return_value=asyncio.coroutine(lambda: True)())
        redis_instance.setex = Mock(return_value=asyncio.coroutine(lambda: True)())
        redis_instance.get = Mock(return_value=asyncio.coroutine(lambda: None)())
        redis_instance.keys = Mock(return_value=asyncio.coroutine(lambda: [])())
        redis_instance.close = Mock(return_value=asyncio.coroutine(lambda: None)())
        mock.return_value = redis_instance
        return redis_instance

class TestUserEvent:
    def test_user_event_creation(self):
        """Test UserEvent creation with required fields"""
        event = UserEvent(
            user_id="user123",
            event_type="page_view",
            timestamp=time.time(),
            page_url="/home"
        )
        
        assert event.user_id == "user123"
        assert event.event_type == "page_view"
        assert event.page_url == "/home"
        assert event.metadata == {}

    def test_user_event_with_metadata(self):
        """Test UserEvent with custom metadata"""
        metadata = {"source": "mobile_app", "version": "1.2.3"}
        event = UserEvent(
            user_id="user123",
            event_type="click",
            timestamp=time.time(),
            metadata=metadata
        )
        
        assert event.metadata == metadata

class TestSession:
    def test_session_creation(self):
        """Test Session creation and basic properties"""
        session = Session(
            session_id="sess123",
            user_id="user123",
            start_time=time.time(),
            last_activity=time.time(),
            events=[],
            device_type="web"
        )
        
        assert session.session_id == "sess123"
        assert session.user_id == "user123"
        assert session.total_events == 0
        assert session.pages_visited == 0

    def test_add_event_to_session(self):
        """Test adding events to session updates metrics"""
        session = Session(
            session_id="sess123",
            user_id="user123",
            start_time=time.time(),
            last_activity=time.time(),
            events=[],
            device_type="web"
        )
        
        event1 = UserEvent("user123", "page_view", time.time(), "/page1")
        event2 = UserEvent("user123", "page_view", time.time(), "/page2")
        
        session.add_event(event1)
        session.add_event(event2)
        
        assert session.total_events == 2
        assert session.pages_visited == 2  # Two unique pages
        assert len(session.events) == 2

    def test_session_expiration(self):
        """Test session expiration logic"""
        old_time = time.time() - 3600  # 1 hour ago
        session = Session(
            session_id="sess123",
            user_id="user123",
            start_time=old_time,
            last_activity=old_time,
            events=[],
            device_type="web"
        )
        
        # Should be expired with 30-minute timeout
        assert session.is_expired(1800)  # 30 minutes
        
        # Should not be expired with 2-hour timeout
        assert not session.is_expired(7200)  # 2 hours

class TestDistributedSessionizer:
    @pytest.mark.asyncio
    async def test_sessionizer_initialization(self, config, mock_redis):
        """Test sessionizer initializes correctly"""
        sessionizer = DistributedSessionizer(config)
        await sessionizer.initialize()
        
        assert sessionizer.redis_client is not None
        assert sessionizer.active_sessions == {}
        assert sessionizer.session_stats['total_sessions'] == 0

    @pytest.mark.asyncio
    async def test_process_first_event(self, config, mock_redis):
        """Test processing first event creates new session"""
        sessionizer = DistributedSessionizer(config)
        await sessionizer.initialize()
        
        event = UserEvent(
            user_id="user123",
            event_type="page_view",
            timestamp=time.time(),
            page_url="/home"
        )
        
        session = await sessionizer.process_event(event)
        
        assert session is not None
        assert session.user_id == "user123"
        assert session.total_events == 1
        assert sessionizer.session_stats['total_sessions'] == 1

    @pytest.mark.asyncio
    async def test_process_multiple_events_same_session(self, config, mock_redis):
        """Test multiple events from same user join same session"""
        sessionizer = DistributedSessionizer(config)
        await sessionizer.initialize()
        
        user_id = "user123"
        base_time = time.time()
        
        event1 = UserEvent(user_id, "page_view", base_time, "/home")
        event2 = UserEvent(user_id, "click", base_time + 10, "/home")
        event3 = UserEvent(user_id, "page_view", base_time + 20, "/about")
        
        session1 = await sessionizer.process_event(event1)
        session2 = await sessionizer.process_event(event2)
        session3 = await sessionizer.process_event(event3)
        
        # Should all be same session
        assert session1.session_id == session2.session_id == session3.session_id
        assert session3.total_events == 3
        assert session3.pages_visited == 2  # /home and /about

class TestSessionAnalyzer:
    @pytest.fixture
    def analyzer(self):
        return SessionAnalyzer()

    def test_session_quality_calculation(self, analyzer):
        """Test session quality scoring"""
        # High quality session
        high_quality_session = {
            'duration': 600,  # 10 minutes
            'pages_visited': 5,
            'total_events': 20
        }
        
        quality = analyzer._calculate_session_quality(high_quality_session)
        assert quality >= 90  # Should be high quality
        
        # Low quality session (bounce)
        low_quality_session = {
            'duration': 5,  # 5 seconds
            'pages_visited': 1,
            'total_events': 1
        }
        
        quality = analyzer._calculate_session_quality(low_quality_session)
        assert quality <= 20  # Should be low quality

    def test_engagement_classification(self, analyzer):
        """Test user engagement classification"""
        high_engagement_session = {
            'duration': 600,
            'pages_visited': 8,
            'total_events': 25
        }
        
        engagement = analyzer._calculate_engagement_score(high_engagement_session)
        assert engagement == "highly_engaged"
        
        bounce_session = {
            'duration': 10,
            'pages_visited': 1,
            'total_events': 2
        }
        
        engagement = analyzer._calculate_engagement_score(bounce_session)
        assert engagement == "bounce"

    def test_session_type_classification(self, analyzer):
        """Test session type classification"""
        # Bounce session
        bounce_session = {
            'duration': 20,
            'pages_visited': 1,
            'events': []
        }
        
        session_type = analyzer._classify_session_type(bounce_session)
        assert session_type == "bounce"
        
        # Exploration session
        exploration_session = {
            'duration': 400,  # 6+ minutes
            'pages_visited': 6,
            'events': []
        }
        
        session_type = analyzer._classify_session_type(exploration_session)
        assert session_type == "exploration"
        
        # Shopping session
        shopping_session = {
            'duration': 200,
            'pages_visited': 3,
            'events': [
                {'page_url': '/product/123'},
                {'page_url': '/cart'},
                {'page_url': '/checkout'}
            ]
        }
        
        session_type = analyzer._classify_session_type(shopping_session)
        assert session_type == "shopping"

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
