from pydantic_settings import BaseSettings
from typing import List

class WebhookConfig(BaseSettings):
    # API Configuration
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    
    # Database Configuration
    database_url: str = "postgresql://webhook_user:webhook_pass@localhost:5432/webhook_db"
    redis_url: str = "redis://localhost:6379/0"
    
    # Webhook Delivery Settings
    max_retries: int = 3
    retry_delay_base: float = 1.0
    max_retry_delay: float = 300.0
    delivery_timeout: float = 30.0
    
    # Security Settings
    webhook_secret_key: str = "your-webhook-secret-key-change-in-production"
    signature_header: str = "X-Webhook-Signature"
    
    # Performance Settings
    max_concurrent_deliveries: int = 100
    batch_size: int = 50
    queue_max_size: int = 10000
    
    class Config:
        env_file = ".env"

config = WebhookConfig()
