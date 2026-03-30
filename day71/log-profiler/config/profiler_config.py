from dataclasses import dataclass
from typing import Dict, List, Optional

@dataclass
class ProfilerConfig:
    # Profiling settings
    sampling_interval: float = 0.1  # seconds
    max_memory_samples: int = 10000
    enable_cpu_profiling: bool = True
    enable_memory_profiling: bool = True
    enable_io_profiling: bool = True
    
    # Performance thresholds
    cpu_threshold: float = 80.0  # percent
    memory_threshold: float = 85.0  # percent
    latency_threshold: float = 100.0  # milliseconds
    
    # Optimization settings
    auto_optimize: bool = False
    optimization_strategies: List[str] = None
    
    def __post_init__(self):
        if self.optimization_strategies is None:
            self.optimization_strategies = [
                'batch_optimization',
                'memory_pooling',
                'async_io',
                'compression',
                'caching'
            ]

# Default configuration
DEFAULT_CONFIG = ProfilerConfig()
