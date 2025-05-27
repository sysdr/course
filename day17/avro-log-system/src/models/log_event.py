"""
Log Event Data Models
Represents the evolution of our log event structure across versions
"""

from dataclasses import dataclass, asdict
from typing import Optional, Dict, Any
from datetime import datetime, timezone
import uuid


@dataclass
class BaseLogEvent:
    """Base class for all log event versions"""
    timestamp: str
    level: str  
    message: str
    service_name: str
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for Avro serialization"""
        return asdict(self)
    
    @classmethod
    def create_sample(cls, **kwargs):
        """Create a sample log event for testing"""
        defaults = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": "INFO",
            "message": "Sample log message", 
            "service_name": "sample-service"
        }
        defaults.update(kwargs)
        return cls(**defaults)


@dataclass
class LogEventV1(BaseLogEvent):
    """Version 1: Basic log event structure"""
    pass


@dataclass  
class LogEventV2(BaseLogEvent):
    """Version 2: Added request tracking capabilities"""
    request_id: Optional[str] = None
    user_id: Optional[str] = None
    
    @classmethod
    def create_sample(cls, **kwargs):
        """Create sample with v2 fields"""
        defaults = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": "INFO", 
            "message": "User action logged",
            "service_name": "auth-service",
            "request_id": str(uuid.uuid4())[:8],
            "user_id": f"user_{uuid.uuid4().hex[:6]}"
        }
        defaults.update(kwargs)
        return cls(**defaults)


@dataclass
class LogEventV3(BaseLogEvent):
    """Version 3: Added performance monitoring"""
    request_id: Optional[str] = None
    user_id: Optional[str] = None
    duration_ms: Optional[float] = None
    memory_usage_mb: Optional[float] = None
    
    @classmethod
    def create_sample(cls, **kwargs):
        """Create sample with v3 fields including performance metrics"""
        import random
        
        defaults = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": "INFO",
            "message": "Operation completed with metrics",
            "service_name": "api-gateway", 
            "request_id": str(uuid.uuid4())[:8],
            "user_id": f"user_{uuid.uuid4().hex[:6]}",
            "duration_ms": round(random.uniform(10.5, 150.7), 2),
            "memory_usage_mb": round(random.uniform(15.2, 89.6), 1)
        }
        defaults.update(kwargs)
        return cls(**defaults)


# Factory function to create events of different versions
def create_log_event(version: str, **kwargs) -> BaseLogEvent:
    """Factory function to create log events of specified version"""
    event_classes = {
        "v1": LogEventV1,
        "v2": LogEventV2, 
        "v3": LogEventV3
    }
    
    if version not in event_classes:
        raise ValueError(f"Unknown version: {version}")
    
    return event_classes[version].create_sample(**kwargs)
