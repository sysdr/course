#!/usr/bin/env python3

import asyncio
import aiohttp
import json
from datetime import datetime

async def demonstrate_webhook_system():
    """Demonstrate the webhook notification system"""
    
    print("🎭 Webhook Notifications System Demonstration")
    print("=" * 50)
    
    base_url = "http://localhost:8000/api/v1"
    
    async with aiohttp.ClientSession() as session:
        # Wait for service to be ready
        print("⏳ Waiting for service to be ready...")
        for attempt in range(30):
            try:
                async with session.get(f"{base_url}/health") as response:
                    if response.status == 200:
                        print("✅ Service is ready!")
                        break
            except:
                await asyncio.sleep(1)
        else:
            print("❌ Service not ready after 30 seconds")
            return
        
        # Get current stats
        print("\n📊 Initial Statistics:")
        async with session.get(f"{base_url}/stats") as response:
            stats = await response.json()
            print(f"   Total subscriptions: {stats.get('total_subscriptions', 0)}")
            print(f"   Active subscriptions: {stats.get('active_subscriptions', 0)}")
        
        # List current subscriptions
        print("\n📋 Current Subscriptions:")
        async with session.get(f"{base_url}/subscriptions") as response:
            subscriptions = await response.json()
            for sub in subscriptions:
                print(f"   • {sub['name']} ({len(sub['events'])} events)")
        
        # Send test events
        print("\n📤 Sending test events...")
        test_events = [
            {
                "level": "CRITICAL",
                "source": "database",
                "message": "Database connection pool exhausted - demo event",
                "event_type": "log.critical",
                "metadata": {"pool_size": 50, "demo": True}
            },
            {
                "level": "ERROR", 
                "source": "payment-service",
                "message": "Payment processing timeout - demo event",
                "event_type": "log.error",
                "metadata": {"transaction_id": "demo_tx_123", "demo": True}
            },
            {
                "level": "WARNING",
                "source": "api-gateway", 
                "message": "High response time detected - demo event",
                "event_type": "log.warning",
                "metadata": {"response_time": 2500, "demo": True}
            }
        ]
        
        for i, event in enumerate(test_events, 1):
            print(f"   Sending event {i}: {event['level']} from {event['source']}")
            async with session.post(f"{base_url}/events", json=event) as response:
                result = await response.json()
                print(f"   ✅ {result['message']}")
            
            await asyncio.sleep(1)  # Small delay between events
        
        # Wait for processing and show updated stats
        print("\n⏳ Waiting for webhook processing...")
        await asyncio.sleep(5)
        
        print("\n📊 Final Statistics:")
        async with session.get(f"{base_url}/stats") as response:
            stats = await response.json()
            print(f"   Total subscriptions: {stats.get('total_subscriptions', 0)}")
            print(f"   Active subscriptions: {stats.get('active_subscriptions', 0)}")
            if 'delivery_stats' in stats:
                delivery_stats = stats['delivery_stats']
                print(f"   Total deliveries: {delivery_stats.get('total_deliveries', 0)}")
                print(f"   Successful deliveries: {delivery_stats.get('delivered', 0)}")
                print(f"   Failed deliveries: {delivery_stats.get('failed', 0)}")
                print(f"   Success rate: {delivery_stats.get('success_rate', 0):.1f}%")
        
        print("\n🎉 Demonstration complete!")
        print("\n💡 Next steps:")
        print("   • Visit http://localhost:8000 for the dashboard")
        print("   • Check http://localhost:8000/docs for API documentation") 
        print("   • View logs for webhook delivery details")

if __name__ == "__main__":
    asyncio.run(demonstrate_webhook_system())
