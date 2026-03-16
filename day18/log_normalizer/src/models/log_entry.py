from datetime import datetime
from typing import Dict, Any, Optional
from pydantic import BaseModel

class LogEntry(BaseModel):
    """Standardized log entry format"""
    timestamp: datetime
    level: str
    message: str
    source: str
    metadata: Dict[str, Any] = {}
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
