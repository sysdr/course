import os
from dataclasses import dataclass

@dataclass
class Config:
    # Queue configuration
    MAX_QUEUE_SIZE: int = int(os.getenv('MAX_QUEUE_SIZE', '10000'))
    NUM_WORKERS: int = int(os.getenv('NUM_WORKERS', '4'))
    
    # Web dashboard configuration
    WEB_HOST: str = os.getenv('WEB_HOST', '0.0.0.0')
    WEB_PORT: int = int(os.getenv('WEB_PORT', '8080'))
    
    # Monitoring configuration
    METRICS_ENABLED: bool = os.getenv('METRICS_ENABLED', 'true').lower() == 'true'
    
    # Demo configuration
    DEMO_MESSAGE_RATE: int = int(os.getenv('DEMO_MESSAGE_RATE', '100'))  # messages per second
