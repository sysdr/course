from dataclasses import dataclass
from typing import Dict, List, Optional
import os

@dataclass
class KafkaConsumerConfig:
    """Kafka consumer configuration"""
    bootstrap_servers: str = "localhost:9092"
    group_id: str = "log-processing-group"
    auto_offset_reset: str = "earliest"
    enable_auto_commit: bool = False
    max_poll_records: int = 500
    session_timeout_ms: int = 30000
    heartbeat_interval_ms: int = 3000
    max_poll_interval_ms: int = 300000
    consumer_timeout_ms: int = 1000
    
    # Topics to consume
    topics: List[str] = None
    
    # Processing configuration
    batch_size: int = 100
    processing_timeout: int = 30
    max_retries: int = 3
    
    # Monitoring
    enable_metrics: bool = True
    metrics_port: int = 8080
    
    def __post_init__(self):
        if self.topics is None:
            self.topics = ["web-logs", "app-logs", "error-logs"]
        
        # Override from environment variables
        self.bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", self.bootstrap_servers)
        self.group_id = os.getenv("KAFKA_GROUP_ID", self.group_id)

@dataclass  
class ProcessingConfig:
    """Log processing configuration"""
    enable_analytics: bool = True
    window_size_seconds: int = 60
    retention_hours: int = 24
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 0
