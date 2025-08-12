import pytest
from unittest.mock import Mock, AsyncMock
from services.connection_manager import ConnectionManager

@pytest.fixture
def connection_manager():
    return ConnectionManager()

@pytest.fixture
def mock_websocket():
    websocket = Mock()
    websocket.send_json = AsyncMock()
    websocket.receive_json = AsyncMock()
    return websocket

def test_connection_manager_initialization(connection_manager):
    """Test connection manager initialization"""
    assert connection_manager.active_connections == {}
    assert connection_manager.multi_stream_connections == set()

@pytest.mark.asyncio
async def test_connect_single_stream(connection_manager, mock_websocket):
    """Test connecting to a single stream"""
    stream_id = "application"
    await connection_manager.connect(mock_websocket, stream_id)
    
    assert stream_id in connection_manager.active_connections
    assert mock_websocket in connection_manager.active_connections[stream_id]

@pytest.mark.asyncio
async def test_disconnect_single_stream(connection_manager, mock_websocket):
    """Test disconnecting from a single stream"""
    stream_id = "application"
    await connection_manager.connect(mock_websocket, stream_id)
    
    # Verify connection exists
    assert mock_websocket in connection_manager.active_connections[stream_id]
    
    # Disconnect
    connection_manager.disconnect(mock_websocket, stream_id)
    
    # Verify connection removed
    assert stream_id not in connection_manager.active_connections

@pytest.mark.asyncio
async def test_connect_multi_stream(connection_manager, mock_websocket):
    """Test connecting to multi-stream mode"""
    await connection_manager.connect_multi(mock_websocket)
    
    assert mock_websocket in connection_manager.multi_stream_connections

@pytest.mark.asyncio
async def test_disconnect_multi_stream(connection_manager, mock_websocket):
    """Test disconnecting from multi-stream mode"""
    await connection_manager.connect_multi(mock_websocket)
    
    # Verify connection exists
    assert mock_websocket in connection_manager.multi_stream_connections
    
    # Disconnect
    await connection_manager.disconnect_multi(mock_websocket)
    
    # Verify connection removed
    assert mock_websocket not in connection_manager.multi_stream_connections
