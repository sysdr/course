from datetime import datetime
from enum import Enum
from typing import Dict, Any, Optional
from pydantic import BaseModel, HttpUrl
import json

class EventType(str, Enum):
    LOG_CRITICAL = "log.critical"
    LOG_ERROR = "log.error"
    LOG_WARNING = "log.warning"
    LOG_INFO = "log.info"
    SYSTEM_HEALTH = "system.health"
    PERFORMANCE_ALERT = "performance.alert"

class DeliveryStatus(str, Enum):
    PENDING = "pending"
    DELIVERING = "delivering"
    DELIVERED = "delivered"
    FAILED = "failed"
    DEAD_LETTER = "dead_letter"

class WebhookSubscription(BaseModel):
    id: Optional[str] = None
    name: str
    url: HttpUrl
    events: list[EventType]
    filters: Dict[str, Any] = {}
    secret_key: str
    active: bool = True
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

class LogEvent(BaseModel):
    id: str
    timestamp: datetime
    level: str
    source: str
    message: str
    metadata: Dict[str, Any] = {}
    event_type: EventType

class WebhookDelivery(BaseModel):
    id: Optional[str] = None
    subscription_id: str
    event_id: str
    url: str
    payload: Dict[str, Any]
    status: DeliveryStatus = DeliveryStatus.PENDING
    attempt_count: int = 0
    last_attempt: Optional[datetime] = None
    response_code: Optional[int] = None
    response_body: Optional[str] = None
    error_message: Optional[str] = None
    created_at: Optional[datetime] = None

class WebhookStats(BaseModel):
    total_subscriptions: int
    active_subscriptions: int
    total_deliveries: int
    successful_deliveries: int
    failed_deliveries: int
    success_rate: float
    avg_delivery_time: float
