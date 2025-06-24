#!/bin/bash

echo "🧪 Running tests..."

# Check if pytest is available
if ! command -v pytest &> /dev/null; then
    echo "❌ pytest not found. Please install pytest first:"
    echo "   pip3 install pytest pytest-asyncio pytest-cov"
    exit 1
fi

# Check if there are any test files
if [ ! -d "tests" ] || [ -z "$(find tests -name 'test_*.py' 2>/dev/null)" ]; then
    echo "⚠️  No test files found. Creating comprehensive test structure..."
    
    # Create tests directory if it doesn't exist
    mkdir -p tests
    
    # Create a comprehensive test file
    cat > tests/test_comprehensive.py << 'EOF'
import pytest
import sys
import os
import asyncio
from unittest.mock import Mock, patch

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from src.config.kafka_config import KafkaConfig
from src.config.app_config import AppConfig
from src.models.user_profile import UserProfile

def test_kafka_config_loading():
    """Test that Kafka config can be loaded"""
    try:
        config = KafkaConfig.from_yaml()
        assert config.bootstrap_servers is not None
        assert config.topic_name is not None
        assert config.partitions > 0
        assert config.replication_factor > 0
        print("✅ Kafka config loading test passed")
    except Exception as e:
        pytest.fail(f"Failed to load Kafka config: {e}")

def test_app_config_loading():
    """Test that app config can be loaded"""
    try:
        config = AppConfig.from_yaml()
        assert config.monitoring_interval_ms > 0
        assert config.state_rebuild_batch_size > 0
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
        from src.web.dashboard_app import create_app
        print("✅ All imports test passed")
    except Exception as e:
        pytest.fail(f"Failed to import modules: {e}")

def test_user_profile_model():
    """Test UserProfile model functionality"""
    try:
        profile = UserProfile(
            user_id="test_user",
            email="test@example.com",
            first_name="Test",
            last_name="User",
            age=25,
            preferences="theme:dark"
        )
        
        assert profile.user_id == "test_user"
        assert profile.email == "test@example.com"
        assert profile.first_name == "Test"
        assert profile.last_name == "User"
        assert profile.age == 25
        assert profile.version == 1
        
        # Test version increment
        updated_profile = profile.increment_version()
        assert updated_profile.version == 2
        
        print("✅ UserProfile model test passed")
    except Exception as e:
        pytest.fail(f"Failed to test UserProfile model: {e}")

def test_environment_variable_override():
    """Test that environment variables override config"""
    try:
        # Test with environment variable
        with patch.dict(os.environ, {'KAFKA_BOOTSTRAP_SERVERS': 'test:9092'}):
            config = KafkaConfig.from_yaml()
            assert config.bootstrap_servers == 'test:9092'
        
        print("✅ Environment variable override test passed")
    except Exception as e:
        pytest.fail(f"Failed to test environment variable override: {e}")

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

    echo "📝 Created comprehensive test file: tests/test_comprehensive.py"
fi

# Run tests with coverage
echo "🔍 Running tests with coverage..."
PYTHONPATH=. pytest tests/ -v --cov=src --cov-report=term-missing --cov-report=html

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
    echo "📊 Coverage report generated in htmlcov/index.html"
else
    echo "❌ Some tests failed!"
    exit 1
fi
