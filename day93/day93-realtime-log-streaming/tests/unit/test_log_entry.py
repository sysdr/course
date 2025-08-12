import pytest
from datetime import datetime
from models.log_entry import LogEntry

def test_log_entry_creation():
    """Test creating a log entry"""
    log_entry = LogEntry(
        id="test-123",
        timestamp=datetime.now(),
        level="INFO",
        message="Test log message",
        source="test",
        stream_id="application"
    )
    
    assert log_entry.id == "test-123"
    assert log_entry.level == "INFO"
    assert log_entry.message == "Test log message"
    assert log_entry.source == "test"
    assert log_entry.stream_id == "application"

def test_log_entry_serialization():
    """Test log entry serialization to dict"""
    timestamp = datetime.now()
    log_entry = LogEntry(
        id="test-456",
        timestamp=timestamp,
        level="ERROR",
        message="Error message",
        source="test",
        stream_id="system"
    )
    
    data = log_entry.dict()
    assert data["id"] == "test-456"
    assert data["level"] == "ERROR"
    assert data["message"] == "Error message"
    assert data["source"] == "test"
    assert data["stream_id"] == "system"
