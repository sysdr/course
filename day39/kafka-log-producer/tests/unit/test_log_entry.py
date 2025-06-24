import pytest
from datetime import datetime
from src.models.log_entry import LogEntry, LogLevel

def test_log_entry_creation():
    """Test basic log entry creation"""
    log = LogEntry(
        level=LogLevel.INFO,
        message="Test message",
        service="test-service"
    )
    
    assert log.level == LogLevel.INFO
    assert log.message == "Test message"
    assert log.service == "test-service"
    assert log.component == "unknown"  # default value
    assert isinstance(log.timestamp, datetime)

def test_log_entry_serialization():
    """Test log entry serialization to Kafka message"""
    log = LogEntry(
        level=LogLevel.ERROR,
        message="Test error",
        service="test-service",
        user_id="user123"
    )
    
    message = log.to_kafka_message()
    assert isinstance(message, bytes)
    
    # Should be valid JSON
    import json
    data = json.loads(message.decode('utf-8'))
    assert data['level'] == LogLevel.ERROR
    assert data['message'] == "Test error"
    assert data['user_id'] == "user123"

def test_partition_key_logic():
    """Test partition key generation"""
    # Test with user_id
    log1 = LogEntry(
        level=LogLevel.INFO,
        message="Test",
        service="test",
        user_id="user123"
    )
    assert log1.get_partition_key() == "user123"
    
    # Test with session_id when no user_id
    log2 = LogEntry(
        level=LogLevel.INFO,
        message="Test",
        service="test",
        session_id="session456"
    )
    assert log2.get_partition_key() == "session456"
    
    # Test fallback to service
    log3 = LogEntry(
        level=LogLevel.INFO,
        message="Test",
        service="test-service"
    )
    assert log3.get_partition_key() == "test-service"

def test_topic_routing():
    """Test topic routing logic"""
    # Error logs go to error topic
    error_log = LogEntry(
        level=LogLevel.ERROR,
        message="Error",
        service="any-service"
    )
    assert error_log.get_topic() == "logs-errors"
    
    # Database logs go to database topic
    db_log = LogEntry(
        level=LogLevel.INFO,
        message="Query",
        service="database"
    )
    assert db_log.get_topic() == "logs-database"
    
    # Security logs go to security topic
    sec_log = LogEntry(
        level=LogLevel.WARN,
        message="Auth warning",
        service="security"
    )
    assert sec_log.get_topic() == "logs-security"
    
    # Others go to application topic
    app_log = LogEntry(
        level=LogLevel.INFO,
        message="Info",
        service="web-api"
    )
    assert app_log.get_topic() == "logs-application"
