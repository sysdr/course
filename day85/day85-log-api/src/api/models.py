from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional, Dict, Any, Union

class LogEntry(BaseModel):
    id: Optional[str] = None
    timestamp: datetime
    level: str = Field(..., pattern="^(DEBUG|INFO|WARNING|ERROR|CRITICAL)$")
    service: str
    message: str
    metadata: Optional[Dict[str, Any]] = {}
    trace_id: Optional[str] = None

class LogQuery(BaseModel):
    query: str = Field(..., min_length=1)
    filters: Optional[Dict[str, Any]] = {}
    time_from: Optional[datetime] = None
    time_to: Optional[datetime] = None
    page: int = Field(1, ge=1)
    size: int = Field(100, ge=1, le=1000)
    aggregations: Optional[Dict[str, bool]] = {}

class LogStats(BaseModel):
    total_logs: int
    logs_by_level: Dict[str, int]
    logs_by_service: Dict[str, int]
    error_rate: float
    avg_logs_per_hour: float
    top_errors: List[Dict[str, Any]]

class APIResponse(BaseModel):
    success: bool
    data: Union[List[Dict], Dict, Any]
    metadata: Optional[Dict[str, Any]] = {}
    error: Optional[str] = None

class User(BaseModel):
    username: str
    role: str = Field(..., pattern="^(developer|operations|security|business)$")
    permissions: List[str] = []
    rate_limit: int = 1000  # requests per hour
