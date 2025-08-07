import pytest
import asyncio
from unittest.mock import Mock, patch
from logplatform_sdk import LogPlatformClient, Config, LogEntry
from logplatform_sdk.exceptions import ConnectionError

@pytest.fixture
def mock_config():
    return Config(
        api_key="test-key",
        base_url="http://test.example.com",
        websocket_url="ws://test.example.com"
    )

@pytest.fixture
def client(mock_config):
    return LogPlatformClient(mock_config)

@patch('requests.Session.post')
def test_submit_log_success(mock_post, client):
    # Mock successful response
    mock_response = Mock()
    mock_response.raise_for_status.return_value = None
    mock_response.json.return_value = {"success": True, "log_id": "test-123"}
    mock_post.return_value = mock_response
    
    log_entry = LogEntry(
        level="INFO",
        message="Test message",
        service="test-service"
    )
    
    result = client.submit_log(log_entry)
    
    assert result["success"] is True
    assert result["log_id"] == "test-123"
    mock_post.assert_called_once()

@patch('requests.Session.post')
def test_submit_log_failure(mock_post, client):
    # Mock failed response
    mock_response = Mock()
    mock_response.raise_for_status.side_effect = Exception("HTTP 500")
    mock_post.return_value = mock_response
    
    log_entry = LogEntry(
        level="INFO",
        message="Test message",
        service="test-service"
    )
    
    with pytest.raises(ConnectionError):
        client.submit_log(log_entry)

@patch('requests.Session.get')
def test_query_logs_success(mock_get, client):
    # Mock successful query response
    mock_response = Mock()
    mock_response.raise_for_status.return_value = None
    mock_response.json.return_value = {
        "logs": [
            {
                "timestamp": "2024-01-01T00:00:00",
                "level": "INFO",
                "message": "Test log",
                "service": "test-service",
                "metadata": {}
            }
        ],
        "total_count": 1,
        "query_time_ms": 50
    }
    mock_get.return_value = mock_response
    
    result = client.query_logs("test query")
    
    assert len(result.logs) == 1
    assert result.total_count == 1
    assert result.query_time_ms == 50

def test_context_manager(mock_config):
    with LogPlatformClient(mock_config) as client:
        assert isinstance(client, LogPlatformClient)
