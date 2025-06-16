#!/usr/bin/env python3
"""
DLQ System Demonstration Script
Shows the system working with specific test cases
"""

import asyncio
import json
import time
from datetime import datetime

from src.producer import LogProducer
from src.processor import LogProcessor
from src.dlq_handler import DLQHandler

async def demonstrate_dlq_system():
    """Demonstrate the DLQ system functionality"""
    print("🎭 DLQ System Demonstration")
    print("=" * 50)
    
    producer = LogProducer()
    processor = LogProcessor()
    handler = DLQHandler()
    
    try:
        # Clear existing data
        await handler.clear_dlq()
        print("🧹 Cleared existing DLQ data")
        
        # Show initial stats
        stats = await handler.get_dlq_stats()
        print(f"\n📊 Initial Stats:")
        print(f"   DLQ Count: {stats['dlq_count']}")
        print(f"   Retry Count: {stats['retry_count']}")
        print(f"   Primary Count: {stats['primary_count']}")
        
        # Produce messages
        print(f"\n🏭 Producing 100 log messages...")
        await producer.produce_messages(100, 0.01)
        
        # Process messages for 10 seconds
        print(f"\n⚙️  Processing messages for 10 seconds...")
        start_time = time.time()
        
        async def process_for_duration():
            while time.time() - start_time < 10:
                try:
                    message_data = await asyncio.wait_for(
                        producer.redis.brpop("log_processing", timeout=1),
                        timeout=2
                    )
                    if message_data:
                        await processor.process_message(message_data[1].decode())
                except asyncio.TimeoutError:
                    continue
                except Exception as e:
                    print(f"   Processing error: {e}")
        
        await process_for_duration()
        
        # Show final stats
        stats = await handler.get_dlq_stats()
        print(f"\n📊 Final Stats:")
        print(f"   DLQ Count: {stats['dlq_count']}")
        print(f"   Retry Count: {stats['retry_count']}")
        print(f"   Primary Count: {stats['primary_count']}")
        print(f"   Processed Count: {stats['processed_count']}")
        
        # Show DLQ messages
        if stats['dlq_count'] > 0:
            print(f"\n💀 Dead Letter Queue Messages:")
            dlq_messages = await handler.get_dlq_messages(5)
            for i, msg in enumerate(dlq_messages[:5]):
                print(f"   {i+1}. ID: {msg['original_message']['id']}")
                print(f"      Type: {msg['failure_type']}")
                print(f"      Error: {msg['error_details']}")
                print(f"      Retries: {msg['retry_count']}")
                print()
        
        # Show failure analysis
        analysis = await handler.get_failure_analysis()
        print(f"\n📈 Failure Analysis:")
        print(f"   Total Analyzed: {analysis['total_analyzed']}")
        print(f"   Failure Types: {analysis['failure_types']}")
        print(f"   Failure Sources: {analysis['failure_sources']}")
        
        print(f"\n✅ Demonstration completed!")
        print(f"🌐 Visit http://localhost:8000 to see the web dashboard")
        
    finally:
        await producer.close()
        await processor.close()
        await handler.close()

if __name__ == "__main__":
    asyncio.run(demonstrate_dlq_system())