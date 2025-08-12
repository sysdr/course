from datetime import datetime
from enum import Enum
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field

class LogLevel(str, Enum):
    """Log level enumeration"""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARN = "WARN"
    ERROR = "ERROR"
    FATAL = "FATAL"

class LogEntry(BaseModel):
    """Log entry model for streaming"""
    id: str = Field(..., description="Unique log entry identifier")
    timestamp: datetime = Field(..., description="Log entry timestamp")
    level: LogLevel = Field(..., description="Log severity level")
    message: str = Field(..., description="Log message content")
    source: str = Field(..., description="Log source identifier")
    stream_id: str = Field(..., description="Log stream identifier")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Additional metadata")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
        
    def dict(self, **kwargs):
        """Override dict to ensure proper datetime serialization"""
        data = super().dict(**kwargs)
        if isinstance(data.get('timestamp'), datetime):
            data['timestamp'] = data['timestamp'].isoformat()
        return data
