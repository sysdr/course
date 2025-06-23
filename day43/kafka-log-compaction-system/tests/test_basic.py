import pytest
import sys
import os

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from src.config.kafka_config import KafkaConfig
from src.config.app_config import AppConfig

def test_kafka_config_loading():
    """Test that Kafka config can be loaded"""
    try:
        config = KafkaConfig.from_yaml()
        assert config.bootstrap_servers is not None
        assert config.topic_name is not None
        print("✅ Kafka config loading test passed")
    except Exception as e:
        pytest.fail(f"Failed to load Kafka config: {e}")

def test_app_config_loading():
    """Test that app config can be loaded"""
    try:
        config = AppConfig.from_yaml()
        assert config.monitoring_interval_ms > 0
        print("✅ App config loading test passed")
    except Exception as e:
        pytest.fail(f"Failed to load app config: {e}")

def test_imports():
    """Test that all modules can be imported"""
    try:
        from src.models.user_profile import UserProfile
        from src.producer.state_producer import AsyncStateProducer
        from src.consumer.state_consumer import AsyncStateConsumer
        from src.monitor.compaction_monitor import AsyncCompactionMonitor
        print("✅ All imports test passed")
    except Exception as e:
        pytest.fail(f"Failed to import modules: {e}")

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
