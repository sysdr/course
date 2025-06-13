import pytest
import tempfile
import os
from src.processors.log_processor import LogProcessor
from src.consumers.log_consumer import LogMessage

@pytest.fixture
def log_processor():
    return LogProcessor()

@pytest.fixture
def web_server_log():
    return LogMessage(
        id="web-1",
        timestamp=1234567890.0,
        level="INFO",
        message="GET /api/users 200",
        source="web-server",
        metadata={
            "endpoint": "/api/users",
            "response_time": 45.2,
            "status_code": 200,
            "method": "GET"
        }
    )

def test_process_basic_log(log_processor):
    """Test processing a basic log message"""
    log_message = LogMessage(
        id="test-1",
        timestamp=1234567890.0,
        level="ERROR",
        message="Database connection failed",
        source="app-server"
    )
    
    result = log_processor.process(log_message)
    assert result is True
    assert log_processor.metrics["total_processed"] == 1
    assert log_processor.metrics["error_logs"] == 1

def test_process_web_server_log(log_processor, web_server_log):
    """Test processing web server log with metrics extraction"""
    result = log_processor.process(web_server_log)
    
    assert result is True
    assert log_processor.metrics["total_processed"] == 1
    assert len(log_processor.metrics["response_times"]) == 1
    assert log_processor.metrics["response_times"][0] == 45.2
    assert "/api/users" in log_processor.metrics["endpoints"]

def test_get_metrics(log_processor, web_server_log):
    """Test getting processor metrics"""
    log_processor.process(web_server_log)
    
    metrics = log_processor.get_metrics()
    assert metrics["total_processed"] == 1
    assert metrics["avg_response_time"] == 45.2
    assert "/api/users" in metrics["endpoints"]
    assert metrics["endpoints"]["/api/users"]["avg_response_time"] == 45.2
