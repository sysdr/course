from dataclasses import dataclass
from typing import Dict, Any
import os

@dataclass
class IndexingConfig:
    # Memory segment configuration
    memory_segment_max_size: int = 10000  # documents per segment
    memory_segment_max_memory: int = 50 * 1024 * 1024  # 50MB
    
    # Index configuration
    index_root_path: str = "data/indexes"
    segment_merge_threshold: int = 5  # merge when 5+ segments
    
    # Stream processing
    batch_size: int = 100
    batch_timeout_ms: int = 100
    
    # Performance thresholds
    max_indexing_latency_ms: int = 100
    target_throughput: int = 1000  # logs per second
    
    # Redis configuration
    redis_url: str = "redis://localhost:6379"
    log_stream_key: str = "log_stream"
    
    # Web interface
    web_host: str = "0.0.0.0"
    web_port: int = 8080

config = IndexingConfig()

def _env_int(name: str, default: int) -> int:
    val = os.getenv(name)
    if val is None or val == "":
        return default
    try:
        return int(val)
    except ValueError:
        return default

# Optional demo overrides (used by `start.sh`)
config.memory_segment_max_size = _env_int("INDEX_MEMORY_SEGMENT_MAX_SIZE", config.memory_segment_max_size)
config.memory_segment_max_memory = _env_int("INDEX_MEMORY_SEGMENT_MAX_MEMORY", config.memory_segment_max_memory)
config.segment_merge_threshold = _env_int("INDEX_SEGMENT_MERGE_THRESHOLD", config.segment_merge_threshold)
config.redis_url = os.getenv("REDIS_URL", config.redis_url)
config.log_stream_key = os.getenv("LOG_STREAM_KEY", config.log_stream_key)
config.web_port = _env_int("WEB_PORT", config.web_port)
