import asyncio
import time
import json
import hashlib
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
import redis.asyncio as redis
import structlog

logger = structlog.get_logger()

@dataclass
class UserEvent:
    """Individual user event structure"""
    user_id: str
    event_type: str
    timestamp: float
    page_url: str = ""
    referrer: str = ""
    device_type: str = "web"
    session_id: str = ""
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}

@dataclass
class Session:
    """User session structure"""
    session_id: str
    user_id: str
    start_time: float
    last_activity: float
    events: List[UserEvent]
    device_type: str
    total_events: int = 0
    pages_visited: int = 0
    duration: float = 0.0
    
    def add_event(self, event: UserEvent):
        """Add event to session and update metrics"""
        self.events.append(event)
        self.last_activity = event.timestamp
        self.total_events += 1
        self.duration = self.last_activity - self.start_time
        
        # Count unique pages
        unique_pages = set(e.page_url for e in self.events if e.page_url)
        self.pages_visited = len(unique_pages)
    
    def is_expired(self, timeout: int) -> bool:
        """Check if session has expired based on timeout"""
        return time.time() - self.last_activity > timeout
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert session to dictionary for serialization"""
        return {
            'session_id': self.session_id,
            'user_id': self.user_id,
            'start_time': self.start_time,
            'last_activity': self.last_activity,
            'duration': self.duration,
            'total_events': self.total_events,
            'pages_visited': self.pages_visited,
            'device_type': self.device_type,
            'events': [asdict(event) for event in self.events[-10:]]  # Keep last 10 events
        }

class DistributedSessionizer:
    """Distributed sessionization engine with Redis backend"""
    
    def __init__(self, config):
        self.config = config
        self.redis_client = None
        self.active_sessions: Dict[str, Session] = {}
        self.session_stats = {
            'total_sessions': 0,
            'active_sessions': 0,
            'expired_sessions': 0,
            'events_processed': 0,
            'avg_session_duration': 0.0,
            'sessions_per_minute': 0
        }
        
    async def initialize(self):
        """Initialize Redis connection and background tasks"""
        self.redis_client = redis.Redis(
            host=self.config.redis_host,
            port=self.config.redis_port,
            db=self.config.redis_db,
            decode_responses=True
        )
        
        # Test connection
        await self.redis_client.ping()
        logger.info("Connected to Redis successfully")
        
        # Start background cleanup task
        asyncio.create_task(self._cleanup_expired_sessions())
        
    async def process_event(self, event: UserEvent) -> Optional[Session]:
        """Process a single user event and update/create sessions"""
        try:
            # Generate session key
            session_key = self._get_session_key(event.user_id)
            
            # Check for existing session
            session = await self._get_or_create_session(event)
            
            # Add event to session
            session.add_event(event)
            
            # Update session in memory and Redis
            self.active_sessions[session.session_id] = session
            await self._persist_session(session)
            
            # Update statistics
            self.session_stats['events_processed'] += 1
            self.session_stats['active_sessions'] = len(self.active_sessions)
            
            logger.info("Event processed", 
                       user_id=event.user_id, 
                       session_id=session.session_id,
                       event_type=event.event_type)
            
            return session
            
        except Exception as e:
            logger.error("Error processing event", error=str(e), event=asdict(event))
            return None
    
    async def _get_or_create_session(self, event: UserEvent) -> Session:
        """Get existing session or create new one based on timeout logic"""
        # Check memory first
        user_sessions = [s for s in self.active_sessions.values() 
                        if s.user_id == event.user_id and not s.is_expired(self.config.session_timeout)]
        
        if user_sessions:
            # Use most recent session
            return max(user_sessions, key=lambda s: s.last_activity)
        
        # Check Redis for persisted sessions
        session_data = await self._load_session_from_redis(event.user_id)
        if session_data and not self._is_session_expired(session_data, self.config.session_timeout):
            return self._deserialize_session(session_data)
        
        # Create new session
        session_id = self._generate_session_id(event.user_id, event.timestamp)
        session = Session(
            session_id=session_id,
            user_id=event.user_id,
            start_time=event.timestamp,
            last_activity=event.timestamp,
            events=[],
            device_type=event.device_type
        )
        
        self.session_stats['total_sessions'] += 1
        logger.info("New session created", user_id=event.user_id, session_id=session_id)
        
        return session
    
    def _generate_session_id(self, user_id: str, timestamp: float) -> str:
        """Generate unique session ID"""
        data = f"{user_id}_{timestamp}_{time.time()}"
        return hashlib.md5(data.encode()).hexdigest()[:16]
    
    def _get_session_key(self, user_id: str) -> str:
        """Generate Redis key for user sessions"""
        return f"session:{user_id}"
    
    async def _persist_session(self, session: Session):
        """Persist session to Redis with expiration"""
        try:
            key = f"session:{session.user_id}:{session.session_id}"
            session_data = json.dumps(session.to_dict())
            await self.redis_client.setex(key, self.config.session_timeout, session_data)
        except Exception as e:
            logger.error("Failed to persist session", error=str(e), session_id=session.session_id)
    
    async def _load_session_from_redis(self, user_id: str) -> Optional[Dict]:
        """Load session data from Redis"""
        try:
            # Get all session keys for user
            pattern = f"session:{user_id}:*"
            keys = await self.redis_client.keys(pattern)
            
            if not keys:
                return None
            
            # Get most recent session
            latest_key = max(keys)
            session_data = await self.redis_client.get(latest_key)
            
            if session_data:
                return json.loads(session_data)
            
        except Exception as e:
            logger.error("Failed to load session from Redis", error=str(e), user_id=user_id)
        
        return None
    
    def _deserialize_session(self, session_data: Dict) -> Session:
        """Convert session data back to Session object"""
        events = [UserEvent(**event_data) for event_data in session_data.get('events', [])]
        
        return Session(
            session_id=session_data['session_id'],
            user_id=session_data['user_id'],
            start_time=session_data['start_time'],
            last_activity=session_data['last_activity'],
            events=events,
            device_type=session_data['device_type'],
            total_events=session_data['total_events'],
            pages_visited=session_data['pages_visited'],
            duration=session_data['duration']
        )
    
    def _is_session_expired(self, session_data: Dict, timeout: int) -> bool:
        """Check if persisted session is expired"""
        return time.time() - session_data['last_activity'] > timeout
    
    async def _cleanup_expired_sessions(self):
        """Background task to clean up expired sessions"""
        while True:
            try:
                expired_count = 0
                current_time = time.time()
                
                # Clean up memory sessions
                expired_sessions = [
                    session_id for session_id, session in self.active_sessions.items()
                    if session.is_expired(self.config.session_timeout)
                ]
                
                for session_id in expired_sessions:
                    del self.active_sessions[session_id]
                    expired_count += 1
                
                if expired_count > 0:
                    self.session_stats['expired_sessions'] += expired_count
                    logger.info("Cleaned up expired sessions", count=expired_count)
                
                # Update statistics
                self._update_session_stats()
                
            except Exception as e:
                logger.error("Error in cleanup task", error=str(e))
            
            await asyncio.sleep(self.config.cleanup_interval)
    
    def _update_session_stats(self):
        """Update session statistics"""
        active_sessions = list(self.active_sessions.values())
        
        if active_sessions:
            total_duration = sum(s.duration for s in active_sessions)
            self.session_stats['avg_session_duration'] = total_duration / len(active_sessions)
        
        # Calculate sessions per minute (simplified)
        self.session_stats['sessions_per_minute'] = len(active_sessions) / 5  # Rough estimate
    
    async def get_session_analytics(self) -> Dict[str, Any]:
        """Get current session analytics"""
        active_sessions = list(self.active_sessions.values())
        
        analytics = {
            'session_stats': self.session_stats,
            'active_sessions_detail': [s.to_dict() for s in active_sessions[:10]],  # Top 10
            'device_breakdown': {},
            'duration_distribution': {
                'short_sessions': 0,    # < 1 minute
                'medium_sessions': 0,   # 1-10 minutes
                'long_sessions': 0      # > 10 minutes
            }
        }
        
        # Calculate device breakdown
        for session in active_sessions:
            device = session.device_type
            analytics['device_breakdown'][device] = analytics['device_breakdown'].get(device, 0) + 1
        
        # Calculate duration distribution
        for session in active_sessions:
            duration_minutes = session.duration / 60
            if duration_minutes < 1:
                analytics['duration_distribution']['short_sessions'] += 1
            elif duration_minutes < 10:
                analytics['duration_distribution']['medium_sessions'] += 1
            else:
                analytics['duration_distribution']['long_sessions'] += 1
        
        return analytics

    async def close(self):
        """Clean shutdown"""
        if self.redis_client:
            await self.redis_client.close()
