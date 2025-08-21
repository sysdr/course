from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime

class WidgetConfig(BaseModel):
    x: int
    y: int
    w: int
    h: int
    minW: int = 2
    minH: int = 2

class Widget(BaseModel):
    id: str
    type: str  # 'log_stream', 'metrics', 'chart', 'alert'
    title: str
    config: WidgetConfig
    filters: Dict[str, Any] = {}
    settings: Dict[str, Any] = {}

class Dashboard(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    widgets: List[Widget]
    layout_settings: Dict[str, Any] = {}
    created_at: datetime
    updated_at: datetime
    owner: str = "user"
    shared: bool = False

class DashboardTemplate(BaseModel):
    id: str
    name: str
    description: str
    category: str  # 'devops', 'security', 'product'
    widgets: List[Widget]
