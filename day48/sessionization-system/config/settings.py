from pydantic_settings import BaseSettings
from typing import Dict, Any

class SessionizationConfig(BaseSettings):
    # Redis Configuration
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 0
    
    # Sessionization Settings
    session_timeout: int = 1800  # 30 minutes in seconds
    max_session_duration: int = 14400  # 4 hours max session
    cleanup_interval: int = 300  # 5 minutes
    
    # Processing Settings
    batch_size: int = 100
    processing_interval: float = 1.0
    
    # Web Interface
    web_host: str = "0.0.0.0"
    web_port: int = 8000
    
    class Config:
        env_file = ".env"

config = SessionizationConfig()
