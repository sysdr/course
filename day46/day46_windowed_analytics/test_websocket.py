#!/usr/bin/env python3
"""
Simple WebSocket test script to verify the dashboard WebSocket connection
"""
import asyncio
import websockets
import json
import sys

async def test_websocket():
    """Test WebSocket connection to the dashboard"""
    uri = "ws://localhost:8000/ws"
    
    try:
        print(f"Connecting to {uri}...")
        async with websockets.connect(uri) as websocket:
            print("✅ WebSocket connected successfully!")
            
            # Wait for a few messages
            for i in range(5):
                try:
                    message = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                    data = json.loads(message)
                    print(f"📨 Received message {i+1}:")
                    print(f"   Type: {data.get('type')}")
                    if data.get('type') == 'metrics_update':
                        metrics = data.get('data', {})
                        print(f"   5min windows: {len(metrics.get('5min', []))}")
                        print(f"   1hour windows: {len(metrics.get('1hour', []))}")
                        print(f"   Active windows: {metrics.get('active_windows', 0)}")
                        
                        # Check if we have actual data
                        if metrics.get('5min'):
                            latest = metrics['5min'][0]
                            if latest.get('metrics'):
                                print(f"   Latest 5min window: {latest['metrics'].get('count', 0)} events")
                                print(f"   Error rate: {latest['metrics'].get('error_rate', 0):.2%}")
                    print()
                    
                except asyncio.TimeoutError:
                    print(f"⏰ Timeout waiting for message {i+1}")
                    break
                    
    except Exception as e:
        print(f"❌ WebSocket test failed: {e}")
        return False
    
    print("✅ WebSocket test completed successfully!")
    return True

if __name__ == "__main__":
    success = asyncio.run(test_websocket())
    sys.exit(0 if success else 1) 