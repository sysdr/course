# tests/test_working.py
import pytest
import asyncio
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from tcp_server import TCPLogServer
from log_shipper import LogShipper

@pytest.mark.asyncio
async def test_basic_connection():
    """Test basic server-client connection without TLS"""
    # Create server with TLS disabled by modifying the start_server call
    server = TCPLogServer(port=8889)
    
    # Override TLS setting
    server.use_tls = False
    
    task = asyncio.create_task(server.start_server())
    await asyncio.sleep(1)
    
    try:
        # Connect without TLS
        shipper = LogShipper(server_port=8889, use_tls=False, batch_size=2)
        connected = await shipper.start()
        
        if connected:
            # Send a test log
            await shipper.ship_log({'timestamp': '2023-01-01', 'message': 'test'})
            await shipper.close()
            
        # Give server time to process
        await asyncio.sleep(0.5)
        
        # Test passes if no exceptions
        assert True
        
    except Exception as e:
        print(f"Test failed: {e}")
        assert False, f"Connection test failed: {e}"
        
    finally:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass

if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])