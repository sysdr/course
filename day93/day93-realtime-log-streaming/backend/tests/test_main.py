import pytest
import asyncio
from fastapi.testclient import TestClient
from fastapi.websockets import WebSocket
import json
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from main import app

client = TestClient(app)

def test_health_check():
    """Test the health check endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "status" in data
    assert data["status"] == "running"

def test_available_streams():
    """Test getting available streams"""
    response = client.get("/api/streams")
    assert response.status_code == 200
    data = response.json()
    assert "streams" in data
    assert len(data["streams"]) > 0
    
    # Check stream structure
    stream = data["streams"][0]
    assert "id" in stream
    assert "name" in stream
    assert "active" in stream

def test_websocket_connection():
    """Test WebSocket connection to log stream"""
    with client.websocket_connect("/ws/logs/application") as websocket:
        # Should successfully connect
        assert websocket is not None
        
        # Should receive log messages
        data = websocket.receive_json()
        assert "id" in data
        assert "timestamp" in data
        assert "level" in data
        assert "message" in data
        assert "source" in data

@pytest.mark.asyncio
async def test_log_streaming():
    """Test continuous log streaming"""
    from services.log_streamer import LogStreamer
    
    streamer = LogStreamer()
    await streamer.start()
    
    logs = []
    async for log_entry in streamer.stream_logs("application"):
        logs.append(log_entry)
        if len(logs) >= 3:  # Collect 3 logs for testing
            break
    
    await streamer.stop()
    
    assert len(logs) == 3
    for log in logs:
        assert log.source == "application"
        assert log.id is not None
        assert log.message is not None
