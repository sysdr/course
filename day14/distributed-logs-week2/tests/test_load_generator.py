# tests/test_load_generator.py
import pytest
import asyncio
import sys
import os

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from load_generator import LoadGenerator

@pytest.mark.asyncio
async def test_log_generation():
    generator = LoadGenerator(target_rps=10, duration=1, num_workers=1)
    log = generator.generate_log()
    
    assert 'timestamp' in log
    assert 'level' in log
    assert 'service' in log
    assert 'message' in log
    assert 'request_id' in log

@pytest.mark.asyncio
async def test_load_test_basic():
    # Very short test to verify functionality
    generator = LoadGenerator(target_rps=10, duration=2, num_workers=1)
    
    results = await generator.run_load_test()
    
    assert results['logs_sent'] >= 0
    assert results['actual_rps'] >= 0
    assert 0 <= results['success_rate'] <= 100
    assert results['duration'] >= 1.5  # Should run for close to specified duration

# tests/test_integration.py
import pytest
import asyncio
import time
import sys
import os

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from tcp_server import TCPLogServer
from log_shipper import LogShipper

@pytest.mark.asyncio
async def test_server_startup():
    """Test that server can start without errors"""
    server = TCPLogServer(port=9999, use_tls=False)
    
    # Start server task
    server_task = asyncio.create_task(server.start_server())
    
    # Give server time to start
    await asyncio.sleep(0.5)
    
    # Verify server is running by checking if port is bound
    try:
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection('localhost', 9999), 
            timeout=2.0
        )
        writer.close()
        await writer.wait_closed()
        success = True
    except:
        success = False
    
    # Cleanup
    server.running = False
    server_task.cancel()
    try:
        await server_task
    except asyncio.CancelledError:
        pass
    
    assert success, "Server should be reachable on port 9999"

@pytest.mark.asyncio
async def test_shipper_connection():
    """Test log shipper can connect to server"""
    # Start server
    server = TCPLogServer(port=9998, use_tls=False)
    server_task = asyncio.create_task(server.start_server())
    
    # Give server time to start
    await asyncio.sleep(0.5)
    
    try:
        # Test connection
        shipper = LogShipper(server_port=9998, use_tls=False, batch_size=5)
        connected = await shipper.start()
        
        if connected:
            # Send a test log
            await shipper.ship_log({
                'timestamp': time.time(),
                'level': 'INFO',
                'message': 'Test log'
            })
            
            # Flush remaining logs
            await shipper.close()
            
            # Give server time to process
            await asyncio.sleep(0.5)
            
            # Check if server received the log
            stats = server.metrics.get_stats()
            success = stats['logs_received'] > 0
        else:
            success = False
            
    except Exception as e:
        print(f"Test error: {e}")
        success = False
    finally:
        # Cleanup
        server.running = False
        server_task.cancel()
        try:
            await server_task
        except asyncio.CancelledError:
            pass
    
    assert success, "Should be able to connect and send logs"

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])