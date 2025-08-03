#!/usr/bin/env python3
"""
Demo script for Root Cause Analysis Engine
Generates sample incidents and demonstrates analysis capabilities
"""

import asyncio
import aiohttp
import json
from datetime import datetime, timedelta
import time

class DemoRunner:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url
        
    async def wait_for_server(self, timeout=30):
        """Wait for server to be ready"""
        print("🔄 Waiting for server to start...")
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(f"{self.base_url}/api/health") as response:
                        if response.status == 200:
                            print("✅ Server is ready!")
                            return True
            except:
                pass
            await asyncio.sleep(1)
        
        return False
    
    async def run_demo(self):
        """Run complete demonstration"""
        if not await self.wait_for_server():
            print("❌ Server failed to start")
            return
        
        print("\n🚀 Root Cause Analysis Engine Demo")
        print("=" * 50)
        
        # Demo scenarios
        scenarios = [
            self.create_database_incident(),
            self.create_api_cascade_incident(),
            self.create_payment_failure_incident()
        ]
        
        for i, scenario in enumerate(scenarios, 1):
            print(f"\n📊 Demo Scenario {i}: {scenario['name']}")
            print("-" * 30)
            
            # Get events and ensure all fields are properly serializable
            events = scenario['events']
            
            # Analyze the incident
            result = await self.analyze_incident(events)
            if result:
                self.display_analysis_results(result)
            
            await asyncio.sleep(2)
        
        print(f"\n🌐 Dashboard available at: {self.base_url}/dashboard")
        print("✨ Demo completed successfully!")
    
    def create_database_incident(self):
        """Create a database failure incident"""
        base_time = datetime.now()
        return {
            "name": "Database Connection Failure",
            "events": [
                {
                    "timestamp": (base_time - timedelta(minutes=2)).isoformat(),
                    "service": "database",
                    "level": "ERROR", 
                    "message": "Connection pool exhausted - max connections reached",
                    "metadata": {"max_connections": 100, "active_connections": 100}
                },
                {
                    "timestamp": (base_time - timedelta(minutes=1, seconds=30)).isoformat(),
                    "service": "auth-service",
                    "level": "ERROR",
                    "message": "Failed to authenticate user - database unavailable",
                    "metadata": {"error_code": "DB_TIMEOUT", "user_id": "user_12345"}
                },
                {
                    "timestamp": (base_time - timedelta(minutes=1)).isoformat(),
                    "service": "user-service", 
                    "level": "ERROR",
                    "message": "Unable to retrieve user profile",
                    "metadata": {"error_code": "DB_CONNECTION_FAILED", "user_id": "user_12345"}
                },
                {
                    "timestamp": (base_time - timedelta(seconds=30)).isoformat(),
                    "service": "api-gateway",
                    "level": "WARNING",
                    "message": "Response time threshold exceeded",
                    "metadata": {"avg_response_time": "8.5s", "threshold": "2.0s"}
                }
            ]
        }
    
    def create_api_cascade_incident(self):
        """Create an API gateway cascade failure"""
        base_time = datetime.now()
        return {
            "name": "API Gateway Cascade Failure",
            "events": [
                {
                    "timestamp": (base_time - timedelta(minutes=3)).isoformat(),
                    "service": "api-gateway",
                    "level": "ERROR",
                    "message": "Rate limiter malfunction - dropping valid requests",
                    "metadata": {"rate_limit": "1000/min", "actual_rate": "500/min"}
                },
                {
                    "timestamp": (base_time - timedelta(minutes=2, seconds=30)).isoformat(),
                    "service": "user-service",
                    "level": "WARNING",
                    "message": "Unusual request pattern detected",
                    "metadata": {"requests_per_minute": 50, "normal_rate": 200}
                },
                {
                    "timestamp": (base_time - timedelta(minutes=2)).isoformat(),
                    "service": "payment-service",
                    "level": "WARNING", 
                    "message": "Request timeout increase",
                    "metadata": {"avg_timeout": "15s", "normal_timeout": "3s"}
                },
                {
                    "timestamp": (base_time - timedelta(minutes=1)).isoformat(),
                    "service": "auth-service",
                    "level": "ERROR",
                    "message": "Authentication service degraded performance",
                    "metadata": {"success_rate": "75%", "normal_rate": "99.9%"}
                }
            ]
        }
    
    def create_payment_failure_incident(self):
        """Create a payment processing failure"""
        base_time = datetime.now()
        return {
            "name": "Payment Processing Failure",
            "events": [
                {
                    "timestamp": (base_time - timedelta(minutes=4)).isoformat(),
                    "service": "external-payment-api",
                    "level": "ERROR",
                    "message": "Third-party payment gateway timeout",
                    "metadata": {"gateway": "stripe", "timeout_ms": 30000}
                },
                {
                    "timestamp": (base_time - timedelta(minutes=3, seconds=30)).isoformat(),
                    "service": "payment-service",
                    "level": "ERROR",
                    "message": "Payment processing failed",
                    "metadata": {"transaction_id": "txn_67890", "amount": "$99.99"}
                },
                {
                    "timestamp": (base_time - timedelta(minutes=3)).isoformat(),
                    "service": "payment-service",
                    "level": "WARNING",
                    "message": "Retry attempts exhausted",
                    "metadata": {"retry_count": 3, "max_retries": 3}
                },
                {
                    "timestamp": (base_time - timedelta(minutes=2)).isoformat(),
                    "service": "user-service",
                    "level": "ERROR",
                    "message": "Order processing failed - payment unavailable",
                    "metadata": {"order_id": "order_54321", "user_id": "user_98765"}
                }
            ]
        }
    
    async def analyze_incident(self, events):
        """Send incident for analysis"""
        try:
            # Debug the request payload
            print(f"📤 Sending {len(events)} events for analysis")
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/api/analyze-incident",
                    json=events,
                    headers={"Content-Type": "application/json"}
                ) as response:
                    if response.status == 200:
                        return await response.json()
                    else:
                        error_text = await response.text()
                        print(f"❌ Analysis failed: {response.status}")
                        print(f"Error: {error_text}")
                        return None
        except Exception as e:
            print(f"❌ Request failed: {e}")
            return None
    
    def display_analysis_results(self, result):
        """Display analysis results in a formatted way"""
        print(f"📋 Incident ID: {result['incident_id']}")
        print(f"📊 Events Analyzed: {len(result['events'])}")
        
        if result['root_causes']:
            print("\n🎯 Top Root Causes:")
            for i, root_cause in enumerate(result['root_causes'][:3], 1):
                confidence = int(root_cause['confidence'] * 100)
                print(f"  {i}. {root_cause['service']}: {root_cause['description']}")
                print(f"     Confidence: {confidence}% | Affected Services: {len(root_cause['affected_services'])}")
        
        impact = result['impact_analysis']
        print(f"\n📈 Impact Analysis:")
        print(f"  Severity: {impact['severity']}")
        print(f"  Services Affected: {impact['total_services']}")
        print(f"  Duration: {impact['duration_seconds']}s")
        print(f"  Errors: {impact['error_count']} | Warnings: {impact['warning_count']}")

async def main():
    demo = DemoRunner()
    await demo.run_demo()

if __name__ == "__main__":
    asyncio.run(main())
