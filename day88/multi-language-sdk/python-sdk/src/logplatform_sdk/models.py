from datetime import datetime
from typing import Dict, List, Optional, Any
from pydantic import BaseModel, Field

class LogEntry(BaseModel):
    """Represents a log entry."""
    
    timestamp: datetime = Field(default_factory=datetime.now)
    level: str = Field(...)
    message: str = Field(...)
    service: str = Field(...)
    metadata: Dict[str, Any] = Field(default_factory=dict)
    
class QueryResult(BaseModel):
    """Result of a log query operation."""
    
    logs: List[LogEntry] = Field(default_factory=list)
    total_count: int = Field(default=0)
    query_time_ms: int = Field(default=0)

class StreamConfig(BaseModel):
    """Configuration for log streaming."""
    
    filters: Dict[str, Any] = Field(default_factory=dict)
    buffer_size: int = Field(default=100)
    real_time: bool = Field(default=True)
