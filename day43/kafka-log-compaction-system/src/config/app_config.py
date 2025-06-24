import yaml
from dataclasses import dataclass
from typing import Dict, Any


@dataclass
class AppConfig:
    state_rebuild_batch_size: int
    monitoring_interval_ms: int
    web_port: int
    
    @classmethod
    def from_yaml(cls, config_path: str = "config.yaml") -> 'AppConfig':
        """Load app configuration from YAML file"""
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        app_config = config['app']
        
        return cls(
            state_rebuild_batch_size=app_config['state_rebuild_batch_size'],
            monitoring_interval_ms=app_config['monitoring_interval_ms'],
            web_port=app_config['web_port']
        )
