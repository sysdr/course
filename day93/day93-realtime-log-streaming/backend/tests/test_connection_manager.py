import pytest
from unittest.mock import AsyncMock, Mock
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from services.connection_manager import ConnectionManager

@pytest.fixture
def connection_manager():
    return ConnectionManager()

@pytest.fixture
def mock_websocket():
    websocket = Mock()
    websocket.accept = AsyncMock()
    websocket.send_json = AsyncMock()
    return websocket

@pytest.mark.asyncio
async def test_connect_disconnect(connection_manager, mock_websocket):
    """Test basic connection and disconnection"""
    stream_id = "test_stream"
    
    # Connect
    await connection_manager.connect(mock_websocket, stream_id)
    assert stream_id in connection_manager.active_connections
    assert mock_websocket in connection_manager.active_connections[stream_id]
    
    # Disconnect
    connection_manager.disconnect(mock_websocket, stream_id)
    assert stream_id not in connection_manager.active_connections

@pytest.mark.asyncio
async def test_multiple_connections(connection_manager):
    """Test multiple connections to same stream"""
    stream_id = "test_stream"
    ws1 = Mock()
    ws1.accept = AsyncMock()
    ws2 = Mock() 
    ws2.accept = AsyncMock()
    
    await connection_manager.connect(ws1, stream_id)
    await connection_manager.connect(ws2, stream_id)
    
    assert len(connection_manager.active_connections[stream_id]) == 2
    
    # Disconnect one
    connection_manager.disconnect(ws1, stream_id)
    assert len(connection_manager.active_connections[stream_id]) == 1
    assert ws2 in connection_manager.active_connections[stream_id]

@pytest.mark.asyncio 
async def test_broadcast_to_stream(connection_manager):
    """Test broadcasting messages to all connections in a stream"""
    stream_id = "test_stream"
    ws1 = Mock()
    ws1.accept = AsyncMock()
    ws1.send_json = AsyncMock()
    ws2 = Mock()
    ws2.accept = AsyncMock()  
    ws2.send_json = AsyncMock()
    
    await connection_manager.connect(ws1, stream_id)
    await connection_manager.connect(ws2, stream_id)
    
    test_message = {"type": "log", "data": "test"}
    await connection_manager.broadcast_to_stream(stream_id, test_message)
    
    ws1.send_json.assert_called_once_with(test_message)
    ws2.send_json.assert_called_once_with(test_message)
