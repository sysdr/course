from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, Any, Optional
from enum import Enum

class LogLevel(Enum):
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"

class FailureType(Enum):
    PARSING_ERROR = "parsing_error"
    NETWORK_ERROR = "network_error"
    RESOURCE_ERROR = "resource_error"
    UNKNOWN_ERROR = "unknown_error"

@dataclass
class LogMessage:
    id: str
    timestamp: datetime
    level: LogLevel
    source: str
    message: str
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "timestamp": self.timestamp.isoformat(),
            "level": self.level.value,
            "source": self.source,
            "message": self.message,
            "metadata": self.metadata
        }

@dataclass
class FailedMessage:
    original_message: LogMessage
    failure_type: FailureType
    error_details: str
    retry_count: int = 0
    first_failure: datetime = field(default_factory=datetime.now)
    last_failure: datetime = field(default_factory=datetime.now)
    
    def to_dict(self) -> Dict[str, Any]:
        # Handle case where original_message might be a dict already
        if isinstance(self.original_message, dict):
            original_msg_dict = self.original_message
        else:
            original_msg_dict = self.original_message.to_dict()
            
        return {
            "original_message": original_msg_dict,
            "failure_type": self.failure_type.value,
            "error_details": self.error_details,
            "retry_count": self.retry_count,
            "first_failure": self.first_failure.isoformat(),
            "last_failure": self.last_failure.isoformat()
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'FailedMessage':
        """Create FailedMessage from dictionary"""
        original_msg_data = data['original_message']
        
        # Convert dict back to LogMessage if needed
        if isinstance(original_msg_data, dict):
            original_message = LogMessage(
                id=original_msg_data['id'],
                timestamp=datetime.fromisoformat(original_msg_data['timestamp']),
                level=LogLevel(original_msg_data['level']),
                source=original_msg_data['source'],
                message=original_msg_data['message'],
                metadata=original_msg_data.get('metadata', {})
            )
        else:
            original_message = original_msg_data
            
        return cls(
            original_message=original_message,
            failure_type=FailureType(data['failure_type']),
            error_details=data['error_details'],
            retry_count=data['retry_count'],
            first_failure=datetime.fromisoformat(data['first_failure']),
            last_failure=datetime.fromisoformat(data['last_failure'])
        )
