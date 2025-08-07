import os
import yaml
from pathlib import Path
from typing import Dict, Any, Optional, List

class ConfigManager:
    """Manage CLI configuration files"""
    
    def __init__(self, profile: str = 'default'):
        self.profile = profile
        self.config_dir = Path.home() / '.logplatform'
        self.config_file = self.config_dir / f'{profile}.yaml'
        self.config_dir.mkdir(exist_ok=True)
        self._config = self._load_config()
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from file"""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    return yaml.safe_load(f) or {}
            except Exception:
                return {}
        return {}
    
    def save(self) -> None:
        """Save configuration to file"""
        try:
            with open(self.config_file, 'w') as f:
                yaml.dump(self._config, f, default_flow_style=False)
        except Exception as e:
            raise RuntimeError(f"Failed to save config: {e}")
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value"""
        return self._config.get(key, default)
    
    def set(self, key: str, value: Any) -> None:
        """Set configuration value"""
        self._config[key] = value
    
    def remove(self, key: str) -> None:
        """Remove configuration key"""
        self._config.pop(key, None)
    
    def get_all(self) -> Dict[str, Any]:
        """Get all configuration"""
        return self._config.copy()
    
    def list_profiles(self) -> List[str]:
        """List available configuration profiles"""
        profiles = []
        for file in self.config_dir.glob('*.yaml'):
            profiles.append(file.stem)
        return sorted(profiles) if profiles else ['default']
