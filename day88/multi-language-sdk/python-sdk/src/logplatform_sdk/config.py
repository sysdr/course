import os
from typing import Optional
from pydantic import BaseModel, Field

class Config(BaseModel):
    """Configuration for LogPlatform SDK."""
    
    api_key: str = Field(default_factory=lambda: os.getenv("LOGPLATFORM_API_KEY", ""))
    base_url: str = Field(default_factory=lambda: os.getenv("LOGPLATFORM_BASE_URL", "http://localhost:8000"))
    websocket_url: str = Field(default_factory=lambda: os.getenv("LOGPLATFORM_WS_URL", "ws://localhost:8000"))
    timeout: int = Field(default=30)
    max_retries: int = Field(default=3)
    retry_delay: float = Field(default=1.0)
    
    class Config:
        env_prefix = "LOGPLATFORM_"
