from datetime import datetime
from typing import Dict, Any, Optional
from pydantic import BaseModel, Field
import json
import uuid

class LogLevel:
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARN = "WARN"
    ERROR = "ERROR"
    FATAL = "FATAL"

class LogEntry(BaseModel):
    """Structured log entry model"""
    
    timestamp: datetime = Field(default_factory=datetime.now)
    level: str = Field(..., description="Log level")
    message: str = Field(..., description="Log message")
    service: str = Field(..., description="Service name")
    component: str = Field(default="unknown", description="Component name")
    trace_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
    
    def to_kafka_message(self) -> bytes:
        """Convert to Kafka message format"""
        data = self.dict()
        return json.dumps(data, default=str).encode('utf-8')
    
    def get_partition_key(self) -> Optional[str]:
        """Get key for consistent partitioning"""
        if self.user_id:
            return self.user_id
        elif self.session_id:
            return self.session_id
        return self.service
    
    def get_topic(self) -> str:
        """Determine appropriate Kafka topic"""
        if self.level in [LogLevel.ERROR, LogLevel.FATAL]:
            return "logs-errors"
        elif self.service == "database":
            return "logs-database"
        elif self.service == "security":
            return "logs-security"
        else:
            return "logs-application"
