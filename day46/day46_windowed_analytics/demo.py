#!/usr/bin/env python3

import asyncio
import json
import time
import random
from datetime import datetime
import redis.asyncio as redis

async def demo_windowed_analytics():
    """Demonstrate windowed analytics functionality"""
    print("🎬 Windowed Analytics Demo")
    print("=" * 50)
    
    # Connect to Redis
    r = redis.Redis(host='localhost', port=6379, decode_responses=True)
    
    # Simulate log events
    services = ['api-gateway', 'user-service', 'payment-service']
    levels = ['INFO', 'WARN', 'ERROR']
    
    print("📊 Generating sample log events...")
    
    for i in range(50):
        event = {
            'timestamp': int(time.time()),
            'service': random.choice(services),
            'level': random.choice(levels),
            'response_time': random.uniform(50, 500),
            'message': f'Demo event {i}'
        }
        
        # Store in Redis for processing
        await r.lpush('demo_events', json.dumps(event))
        
        if i % 10 == 0:
            print(f"   Generated {i+1} events...")
            
        await asyncio.sleep(0.1)
    
    print("✅ Demo events generated!")
    print("🌐 Start the main application to see windowed analytics:")
    print("   python src/main.py")
    print("   Visit: http://localhost:8000")

if __name__ == "__main__":
    asyncio.run(demo_windowed_analytics())
