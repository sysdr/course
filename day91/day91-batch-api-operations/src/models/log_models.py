from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from datetime import datetime
import uuid

class LogEntry(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    level: str = Field(..., description="Log level (INFO, WARN, ERROR, DEBUG)")
    service: str = Field(..., description="Service name that generated the log")
    message: str = Field(..., description="Log message content")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Additional metadata")

class BatchRequest(BaseModel):
    logs: List[LogEntry] = Field(..., description="List of log entries to process")
    chunk_size: Optional[int] = Field(default=1000, description="Size of processing chunks")
    transaction_mode: Optional[str] = Field(default="optimistic", description="Transaction handling mode")

class BatchResponse(BaseModel):
    success: bool = Field(..., description="Overall batch operation success")
    total_processed: int = Field(..., description="Total number of items processed")
    success_count: int = Field(..., description="Number of successful operations")
    error_count: int = Field(..., description="Number of failed operations")
    processing_time: float = Field(..., description="Total processing time in seconds")
    batch_id: str = Field(..., description="Unique batch identifier")
    errors: List[str] = Field(default_factory=list, description="List of error messages")

class BatchResult(BaseModel):
    batch_id: str
    success_count: int
    error_count: int
    total_processed: int
    processing_time: float
    errors: List[str] = Field(default_factory=list)

class QueryResult(BaseModel):
    logs: List[LogEntry]
    total_count: int
    processing_time: float
    query_stats: Dict[str, Any]

class BatchStats(BaseModel):
    total_batches_processed: int = 0
    total_logs_processed: int = 0
    average_batch_size: float = 0.0
    average_processing_time: float = 0.0
    success_rate: float = 0.0
    throughput_per_second: float = 0.0
    current_queue_size: int = 0
