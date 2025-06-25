#!/usr/bin/env python3
"""
Comprehensive test script for the Windowed Analytics System
"""
import asyncio
import aiohttp
import websockets
import json
import time
import sys
from typing import Dict, Any

class SystemTester:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.ws_url = f"ws://localhost:8000/ws"
        
    async def test_api_endpoints(self) -> bool:
        """Test all API endpoints"""
        print("🔍 Testing API endpoints...")
        
        async with aiohttp.ClientSession() as session:
            # Test main dashboard
            try:
                async with session.get(f"{self.base_url}/") as response:
                    if response.status == 200:
                        print("✅ Main dashboard endpoint working")
                    else:
                        print(f"❌ Main dashboard failed: {response.status}")
                        return False
            except Exception as e:
                print(f"❌ Main dashboard error: {e}")
                return False
            
            # Test test dashboard
            try:
                async with session.get(f"{self.base_url}/test") as response:
                    if response.status == 200:
                        print("✅ Test dashboard endpoint working")
                    else:
                        print(f"❌ Test dashboard failed: {response.status}")
                        return False
            except Exception as e:
                print(f"❌ Test dashboard error: {e}")
                return False
            
            # Test metrics API
            try:
                async with session.get(f"{self.base_url}/api/metrics/5min?limit=3") as response:
                    if response.status == 200:
                        data = await response.json()
                        metrics = data.get('metrics', [])
                        print(f"✅ Metrics API working - {len(metrics)} 5min windows")
                        
                        if metrics:
                            latest = metrics[0]
                            count = latest.get('metrics', {}).get('count', 0)
                            print(f"   Latest window: {count} events")
                    else:
                        print(f"❌ Metrics API failed: {response.status}")
                        return False
            except Exception as e:
                print(f"❌ Metrics API error: {e}")
                return False
            
            # Test active windows API
            try:
                async with session.get(f"{self.base_url}/api/active_windows") as response:
                    if response.status == 200:
                        data = await response.json()
                        active_count = data.get('count', 0)
                        print(f"✅ Active windows API working - {active_count} active windows")
                    else:
                        print(f"❌ Active windows API failed: {response.status}")
                        return False
            except Exception as e:
                print(f"❌ Active windows API error: {e}")
                return False
        
        return True
    
    async def test_websocket(self) -> bool:
        """Test WebSocket connection and data flow"""
        print("🔍 Testing WebSocket connection...")
        
        try:
            async with websockets.connect(self.ws_url) as websocket:
                print("✅ WebSocket connected successfully")
                
                # Wait for a few messages to verify data flow
                messages_received = 0
                for i in range(3):
                    try:
                        message = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                        data = json.loads(message)
                        
                        if data.get('type') == 'metrics_update':
                            messages_received += 1
                            metrics = data.get('data', {})
                            print(f"   Message {i+1}: {len(metrics.get('5min', []))} 5min windows, "
                                  f"{len(metrics.get('1hour', []))} 1hour windows")
                            
                    except asyncio.TimeoutError:
                        print(f"⏰ Timeout waiting for message {i+1}")
                        break
                
                if messages_received > 0:
                    print(f"✅ WebSocket data flow working - {messages_received} messages received")
                    return True
                else:
                    print("❌ No WebSocket messages received")
                    return False
                    
        except Exception as e:
            print(f"❌ WebSocket test failed: {e}")
            return False
    
    async def test_data_processing(self) -> bool:
        """Test that data is being processed and windows are being created"""
        print("🔍 Testing data processing...")
        
        async with aiohttp.ClientSession() as session:
            # Get initial state
            async with session.get(f"{self.base_url}/api/metrics/5min?limit=1") as response:
                if response.status != 200:
                    print("❌ Cannot get initial metrics")
                    return False
                
                initial_data = await response.json()
                initial_count = len(initial_data.get('metrics', []))
                print(f"   Initial 5min windows: {initial_count}")
            
            # Wait a bit for more data to be processed
            await asyncio.sleep(3)
            
            # Get updated state
            async with session.get(f"{self.base_url}/api/metrics/5min?limit=1") as response:
                if response.status != 200:
                    print("❌ Cannot get updated metrics")
                    return False
                
                updated_data = await response.json()
                updated_count = len(updated_data.get('metrics', []))
                print(f"   Updated 5min windows: {updated_count}")
                
                # Check if we have new data
                if updated_count > 0:
                    latest = updated_data['metrics'][0]
                    event_count = latest.get('metrics', {}).get('count', 0)
                    print(f"   Latest window events: {event_count}")
                    
                    if event_count > 0:
                        print("✅ Data processing working - events being processed")
                        return True
                    else:
                        print("❌ No events in latest window")
                        return False
                else:
                    print("❌ No windows available")
                    return False
    
    async def run_all_tests(self) -> bool:
        """Run all tests"""
        print("🚀 Starting comprehensive system test...")
        print("=" * 50)
        
        tests = [
            ("API Endpoints", self.test_api_endpoints),
            ("WebSocket Connection", self.test_websocket),
            ("Data Processing", self.test_data_processing),
        ]
        
        results = []
        for test_name, test_func in tests:
            print(f"\n📋 {test_name}")
            print("-" * 30)
            try:
                result = await test_func()
                results.append((test_name, result))
            except Exception as e:
                print(f"❌ {test_name} failed with exception: {e}")
                results.append((test_name, False))
        
        # Summary
        print("\n" + "=" * 50)
        print("📊 Test Results Summary:")
        print("=" * 50)
        
        passed = 0
        for test_name, result in results:
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"{test_name}: {status}")
            if result:
                passed += 1
        
        print(f"\nOverall: {passed}/{len(results)} tests passed")
        
        if passed == len(results):
            print("🎉 All tests passed! System is working correctly.")
            return True
        else:
            print("⚠️  Some tests failed. Please check the system.")
            return False

async def main():
    """Main test function"""
    tester = SystemTester()
    success = await tester.run_all_tests()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    asyncio.run(main()) 