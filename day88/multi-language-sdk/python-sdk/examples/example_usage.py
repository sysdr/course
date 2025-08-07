#!/usr/bin/env python3

import asyncio
import os
from datetime import datetime
from logplatform_sdk import LogPlatformClient, Config, LogEntry, StreamConfig

async def main():
    # Configure the client
    config = Config(
        api_key="demo-api-key-12345",
        base_url="http://localhost:8000",
        websocket_url="ws://localhost:8000"
    )
    
    # Create client
    with LogPlatformClient(config) as client:
        print("🐍 Python SDK Demo")
        print("=" * 50)
        
        # Submit a single log
        log_entry = LogEntry(
            level="INFO",
            message="Python SDK test message",
            service="demo-service",
            metadata={"source": "python-example", "user_id": "123"}
        )
        
        print("📝 Submitting single log...")
        result = client.submit_log(log_entry)
        print(f"✅ Result: {result}")
        
        # Submit batch logs
        batch_logs = [
            LogEntry(level="INFO", message=f"Batch message {i}", service="batch-service")
            for i in range(5)
        ]
        
        print("\n📦 Submitting batch logs...")
        batch_result = client.submit_logs_batch(batch_logs)
        print(f"✅ Batch result: {batch_result}")
        
        # Query logs
        print("\n🔍 Querying logs...")
        query_result = client.query_logs("INFO", limit=10)
        print(f"✅ Found {len(query_result.logs)} logs in {query_result.query_time_ms}ms")
        
        # Stream logs for 10 seconds
        print("\n🌊 Streaming logs for 10 seconds...")
        stream_config = StreamConfig(real_time=True)
        
        async def stream_demo():
            count = 0
            async for log in client.stream_logs(stream_config):
                print(f"📨 Streamed log: {log.message}")
                count += 1
                if count >= 5:  # Limit for demo
                    break
        
        try:
            await asyncio.wait_for(stream_demo(), timeout=10.0)
        except asyncio.TimeoutError:
            print("⏰ Stream demo timeout")
        
        # Health check
        print("\n❤️ Health check...")
        health = client.health_check()
        print(f"✅ Platform status: {health}")

if __name__ == "__main__":
    asyncio.run(main())
