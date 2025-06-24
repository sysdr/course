import os
from dataclasses import dataclass
from typing import List

@dataclass
class Settings:
    # Redis configuration
    redis_url: str = os.getenv("REDIS_URL", "redis://localhost:6379")
    
    # Queue configuration
    primary_queue: str = "log_processing"
    dlq_queue: str = "dead_letter_queue"
    retry_queue: str = "retry_queue"
    
    # Retry configuration
    max_retries: int = 3
    retry_delays: List[int] = (1, 2, 4, 8)  # Exponential backoff
    
    # Processing configuration
    batch_size: int = 100
    failure_rate: float = 0.1  # Simulated failure rate
    
    # Monitoring
    metrics_port: int = 9090
    dashboard_port: int = 8000
    
    # Logging
    log_level: str = "INFO"
    log_format: str = "json"

settings = Settings()
