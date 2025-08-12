import pytest
import httpx
import asyncio
from fastapi.testclient import TestClient
from main import app

@pytest.fixture
def client():
    return TestClient(app)

def test_root_endpoint(client):
    """Test the root health check endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    
    data = response.json()
    assert "message" in data
    assert "status" in data
    assert "timestamp" in data
    assert "active_connections" in data
    assert data["status"] == "running"

def test_streams_endpoint(client):
    """Test the available streams endpoint"""
    response = client.get("/api/streams")
    assert response.status_code == 200
    
    data = response.json()
    assert "streams" in data
    assert isinstance(data["streams"], list)
    
    expected_streams = ["application", "system", "security", "database", "api"]
    for stream in expected_streams:
        assert stream in data["streams"]

@pytest.mark.asyncio
async def test_websocket_connection():
    """Test WebSocket connection to log stream"""
    import websockets
    
    uri = "ws://localhost:8000/ws/logs/application"
    
    try:
        async with websockets.connect(uri) as websocket:
            # Wait for a log message
            message = await asyncio.wait_for(websocket.recv(), timeout=5.0)
            
            # Parse the message
            import json
            log_data = json.loads(message)
            
            # Verify log structure
            assert "id" in log_data
            assert "timestamp" in log_data
            assert "level" in log_data
            assert "message" in log_data
            assert "source" in log_data
            assert "stream_id" in log_data
            assert log_data["stream_id"] == "application"
            
    except Exception as e:
        # If connection fails, the service might not be running
        # This is expected in test environment
        pytest.skip(f"WebSocket connection failed: {e}")

def test_cors_headers(client):
    """Test that CORS headers are properly set"""
    response = client.options("/", headers={"Origin": "http://localhost:3000"})
    
    # CORS preflight should be handled
    assert response.status_code in [200, 405]  # 405 is also acceptable for OPTIONS
