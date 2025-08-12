import pytest
import asyncio
from unittest.mock import Mock, AsyncMock
from services.log_streamer import LogStreamer
from models.log_entry import LogEntry
from datetime import datetime

@pytest.fixture
def log_streamer():
    return LogStreamer()

@pytest.fixture
def sample_log_entry():
    return LogEntry(
        id="test-123",
        timestamp=datetime.now(),
        level="INFO",
        message="Test log message",
        source="test",
        stream_id="application"
    )

def test_log_streamer_initialization(log_streamer):
    """Test log streamer initialization"""
    assert log_streamer.is_running == False
    assert "application" in log_streamer.available_streams
    assert "system" in log_streamer.available_streams
    assert "security" in log_streamer.available_streams
    assert "database" in log_streamer.available_streams
    assert "api" in log_streamer.available_streams

def test_get_available_streams(log_streamer):
    """Test getting available streams"""
    streams = log_streamer.get_available_streams()
    expected_streams = ["application", "system", "security", "database", "api"]
    
    assert len(streams) == 5
    for stream in expected_streams:
        assert stream in streams

@pytest.mark.asyncio
async def test_start_stop_log_streamer(log_streamer):
    """Test starting and stopping the log streamer"""
    # Start the streamer
    await log_streamer.start()
    assert log_streamer.is_running == True
    
    # Stop the streamer
    await log_streamer.stop()
    assert log_streamer.is_running == False

@pytest.mark.asyncio
async def test_stream_logs_generation(log_streamer):
    """Test that log streams generate log entries"""
    await log_streamer.start()
    
    # Get logs from application stream
    log_count = 0
    async for log_entry in log_streamer.stream_logs("application"):
        assert isinstance(log_entry, LogEntry)
        assert log_entry.stream_id == "application"
        log_count += 1
        if log_count >= 5:  # Limit to 5 logs for testing
            break
    
    await log_streamer.stop()
    assert log_count > 0

@pytest.mark.asyncio
async def test_invalid_stream_id(log_streamer):
    """Test handling of invalid stream ID"""
    await log_streamer.start()
    
    # Try to get logs from invalid stream
    with pytest.raises(ValueError):
        async for _ in log_streamer.stream_logs("invalid_stream"):
            pass
    
    await log_streamer.stop()
