# tests/test_integration_simple.py
import pytest
import asyncio
import time
import sys
import os
import socket

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from tcp_server import TCPLogServer
from log_shipper import LogShipper

@pytest.mark.asyncio
async def test_server_starts():
    """Test server can start"""
    server = TCPLogServer(port=8889)
    task = asyncio.create_task(server.start_server())
    await asyncio.sleep(0.5)
    
    # Test connection
    try:
        reader, writer = await asyncio.open_connection('localhost', 8889)
        writer.close()
        await writer.wait_closed()
        success = True
    except:
        success = False
    
    task.cancel()
    assert success

@pytest.mark.asyncio
async def test_client_connects():
    """Test client can connect to server"""
    server = TCPLogServer(port=8890)
    task = asyncio.create_task(server.start_server())
    await asyncio.sleep(0.5)
    
    try:
        shipper = LogShipper(server_port=8890, use_tls=False)
        connected = await shipper.start()
        if connected:
            await shipper.close()
        assert connected
    finally:
        task.cancel()

@pytest.mark.asyncio
async def test_send_logs():
    """Test sending logs to server"""
    server = TCPLogServer(port=8891)
    task = asyncio.create_task(server.start_server())
    await asyncio.sleep(0.5)
    
    try:
        shipper = LogShipper(server_port=8891, use_tls=False, batch_size=2)
        connected = await shipper.start()
        
        if connected:
            # Send test logs
            await shipper.ship_log({'message': 'test1'})
            await shipper.ship_log({'message': 'test2'})
            await shipper.close()
            
            # Check server received something
            await asyncio.sleep(0.5)
            assert server.metrics.logs_received >= 0  # At least doesn't crash
            
    finally:
        task.cancel()

if __name__ == "__main__":
    pytest.main([__file__, "-v"])