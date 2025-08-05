from datetime import datetime
from typing import Optional, Dict, Any
from enum import Enum
import json
import uuid

class LogLevel(str, Enum):
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"

class ServiceType(str, Enum):
    API_GATEWAY = "api-gateway"
    USER_SERVICE = "user-service"
    ORDER_SERVICE = "order-service"
    PAYMENT_SERVICE = "payment-service"
    INVENTORY_SERVICE = "inventory-service"
    NOTIFICATION_SERVICE = "notification-service"

class LogEntry:
    def __init__(self, 
                 service: str,
                 level: str,
                 message: str,
                 metadata: Optional[Dict[str, Any]] = None,
                 trace_id: Optional[str] = None,
                 span_id: Optional[str] = None):
        self.id = str(uuid.uuid4())
        self.timestamp = datetime.utcnow()
        self.service = service
        self.level = level
        self.message = message
        self.metadata = json.dumps(metadata) if metadata else None
        self.trace_id = trace_id or str(uuid.uuid4())
        self.span_id = span_id or str(uuid.uuid4())
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "timestamp": self.timestamp.isoformat(),
            "service": self.service,
            "level": self.level,
            "message": self.message,
            "metadata": self.metadata,
            "trace_id": self.trace_id,
            "span_id": self.span_id
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "LogEntry":
        entry = cls(
            service=data["service"],
            level=data["level"],
            message=data["message"],
            metadata=json.loads(data["metadata"]) if data.get("metadata") else None,
            trace_id=data.get("trace_id"),
            span_id=data.get("span_id")
        )
        entry.id = data.get("id", entry.id)
        entry.timestamp = datetime.fromisoformat(data["timestamp"]) if isinstance(data["timestamp"], str) else data["timestamp"]
        return entry
