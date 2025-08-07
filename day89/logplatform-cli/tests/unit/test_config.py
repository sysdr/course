import pytest
import tempfile
import os
from pathlib import Path

from logplatform_cli.config.manager import ConfigManager

class TestConfigManager:
    
    def test_config_creation(self):
        """Test configuration manager creation"""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Override home directory
            original_home = Path.home
            Path.home = lambda: Path(temp_dir)
            
            try:
                config = ConfigManager('test')
                assert config.profile == 'test'
                assert config.config_dir.exists()
            finally:
                Path.home = original_home
    
    def test_set_and_get(self):
        """Test setting and getting configuration values"""
        with tempfile.TemporaryDirectory() as temp_dir:
            original_home = Path.home
            Path.home = lambda: Path(temp_dir)
            
            try:
                config = ConfigManager('test')
                config.set('test_key', 'test_value')
                assert config.get('test_key') == 'test_value'
                assert config.get('nonexistent', 'default') == 'default'
            finally:
                Path.home = original_home
    
    def test_save_and_load(self):
        """Test saving and loading configuration"""
        with tempfile.TemporaryDirectory() as temp_dir:
            original_home = Path.home
            Path.home = lambda: Path(temp_dir)
            
            try:
                # Create and save config
                config1 = ConfigManager('test')
                config1.set('server_url', 'http://test.example.com')
                config1.save()
                
                # Load in new instance
                config2 = ConfigManager('test')
                assert config2.get('server_url') == 'http://test.example.com'
            finally:
                Path.home = original_home
