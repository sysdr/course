from pydantic_settings import BaseSettings
from typing import Dict, Any
import os

class Settings(BaseSettings):
    # Redis Configuration
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 0
    
    # Sliding Window Configuration
    window_size_seconds: int = 30
    slide_interval_seconds: int = 5
    max_events_per_window: int = 1000
    
    # API Configuration
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    
    # Performance Settings
    batch_size: int = 100
    memory_limit_mb: int = 512
    
    class Config:
        env_file = ".env"

settings = Settings()
