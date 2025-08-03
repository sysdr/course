"""
Data models for log events and incident reports
"""

from datetime import datetime
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
import uuid

class LogEvent(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4())[:8])
    timestamp: datetime
    service: str
    level: str  # INFO, WARNING, ERROR, CRITICAL
    message: str
    metadata: Dict[str, Any] = Field(default_factory=dict)

class RootCause(BaseModel):
    event_id: str
    service: str
    description: str
    timestamp: datetime
    confidence: float = Field(ge=0.0, le=1.0)
    affected_services: List[str] = Field(default_factory=list)
    evidence: List[str] = Field(default_factory=list)

class IncidentReport(BaseModel):
    incident_id: str
    timestamp: datetime
    events: List[LogEvent]
    timeline: List[Dict[str, Any]]
    root_causes: List[RootCause]
    impact_analysis: Dict[str, Any]
    causal_graph_summary: Dict[str, Any]
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
