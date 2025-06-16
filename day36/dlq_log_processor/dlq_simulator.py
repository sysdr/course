#!/usr/bin/env python3
"""
Dead Letter Queue Simulation Script
Demonstrates various failure scenarios and DLQ behavior
"""

import asyncio
import json
import random
import time
from datetime import datetime
from typing import List

from src.producer import LogProducer
from src.processor import LogProcessor
from src.dlq_handler import DLQHandler
from src.models import LogMessage, LogLevel

class DLQSimulator:
    def __init__(self):
        self.producer = LogProducer()
        self.processor = LogProcessor()
        self.dlq_handler = DLQHandler()
        
    async def simulate_parsing_errors(self, count: int = 10):
        """Generate messages that will cause parsing errors"""
        print(f"🔥 Simulating {count} parsing errors...")
        
        malformed_messages = [
            '{"id": "broken-1", "message": "Invalid JSON: {unclosed',
            '{"id": "broken-2", "timestamp": "not-a-date", "level": "INFO"}',
            '{"incomplete": "message"',  # Missing required fields
            'not json at all',
            '{"id": "broken-3", "level": "INVALID_LEVEL"}',
        ]
        
        for i in range(count):
            # Send malformed JSON directly to queue
            malformed = random.choice(malformed_messages)
            await self.producer.redis.lpush("log_processing", malformed)
            await asyncio.sleep(0.1)
        
        print(f"✅ Injected {count} malformed messages")

    async def simulate_network_errors(self, count: int = 5):
        """Temporarily break network connectivity simulation"""
        print(f"🌐 Simulating {count} network errors...")
        
        # Create messages with network-triggering patterns
        for i in range(count):
            message = LogMessage(
                id=f"network-fail-{i}",
                timestamp=datetime.now(),
                level=LogLevel.ERROR,
                source="external-api",
                message="External API call failed - connection timeout",
                metadata={"api_endpoint": "https://failing-service.com/api"}
            )
            
            await self.producer.redis.lpush(
                "log_processing", 
                json.dumps(message.to_dict(), default=str)
            )
            await asyncio.sleep(0.2)
        
        print(f"✅ Created {count} network-prone messages")

    async def simulate_resource_errors(self, count: int = 5):
        """Generate high-memory messages to trigger resource errors"""
        print(f"💾 Simulating {count} resource errors...")
        
        for i in range(count):
            # Create large messages that consume resources
            large_metadata = {
                "large_data": "x" * 10000,  # 10KB of data per message
                "trace_data": ["stack_frame_" + str(j) for j in range(100)],
                "user_actions": [f"action_{k}" for k in range(200)]
            }
            
            message = LogMessage(
                id=f"resource-heavy-{i}",
                timestamp=datetime.now(),
                level=LogLevel.ERROR,
                source="memory-intensive-service",
                message="Processing large dataset - potential memory issue",
                metadata=large_metadata
            )
            
            await self.producer.redis.lpush(
                "log_processing",
                json.dumps(message.to_dict(), default=str)
            )
            await asyncio.sleep(0.1)
        
        print(f"✅ Created {count} resource-heavy messages")

    async def simulate_overload_scenario(self, burst_count: int = 50):
        """Simulate system overload with message burst"""
        print(f"🚀 Simulating burst overload with {burst_count} messages...")
        
        # Rapid message generation to overwhelm processor
        for i in range(burst_count):
            message = self.producer.generate_log_message()
            message.id = f"burst-{i}"
            
            await self.producer.redis.lpush(
                "log_processing",
                json.dumps(message.to_dict(), default=str)
            )
            
            # Very rapid injection
            if i < 20:
                await asyncio.sleep(0.01)  # Fast initial burst
            else:
                await asyncio.sleep(0.05)  # Sustained load
        
        print(f"✅ Burst completed: {burst_count} messages")

    async def force_retry_exhaustion(self, count: int = 3):
        """Create messages that will exhaust retry attempts"""
        print(f"🔄 Creating {count} messages to exhaust retries...")
        
        # Override processor to always fail these specific messages
        original_process = self.processor.process_message
        
        async def failing_processor(message_data: str):
            try:
                message_dict = json.loads(message_data)
                if "retry-exhaust" in message_dict.get("id", ""):
                    # Always fail these messages
                    raise Exception("Simulated persistent failure")
                else:
                    return await original_process(message_data)
            except json.JSONDecodeError:
                return await original_process(message_data)
        
        # Temporarily replace processor method
        self.processor.process_message = failing_processor
        
        for i in range(count):
            message = LogMessage(
                id=f"retry-exhaust-{i}",
                timestamp=datetime.now(),
                level=LogLevel.WARNING,
                source="persistent-failure-service",
                message="This message will always fail processing",
                metadata={"simulation": "retry_exhaustion"}
            )
            
            await self.producer.redis.lpush(
                "log_processing",
                json.dumps(message.to_dict(), default=str)
            )
            await asyncio.sleep(0.1)
        
        print(f"✅ Created {count} retry-exhaustion messages")
        
        # Process these messages to trigger failures
        print("⚙️ Processing to trigger retry exhaustion...")
        for _ in range(count * 4):  # Process multiple times to exhaust retries
            try:
                message_data = await asyncio.wait_for(
                    self.producer.redis.brpop("log_processing", timeout=1),
                    timeout=2
                )
                if message_data:
                    await self.processor.process_message(message_data[1].decode())
                    await asyncio.sleep(0.5)  # Allow retry processing
            except asyncio.TimeoutError:
                break
        
        # Restore original processor
        self.processor.process_message = original_process
        print("✅ Retry exhaustion simulation complete")

    async def demonstrate_recovery(self):
        """Show DLQ recovery capabilities"""
        print("🔧 Demonstrating DLQ recovery...")
        
        # Get current DLQ status
        stats = await self.dlq_handler.get_dlq_stats()
        dlq_count = stats['dlq_count']
        
        if dlq_count == 0:
            print("No messages in DLQ - generating some failures first...")
            await self.simulate_parsing_errors(3)
            await asyncio.sleep(2)
            stats = await self.dlq_handler.get_dlq_stats()
            dlq_count = stats['dlq_count']
        
        print(f"📊 Current DLQ count: {dlq_count}")
        
        if dlq_count > 0:
            # Show DLQ messages
            dlq_messages = await self.dlq_handler.get_dlq_messages(5)
            print("💀 Sample DLQ messages:")
            for i, msg in enumerate(dlq_messages[:3]):
                print(f"  {i+1}. ID: {msg['original_message']['id']}")
                print(f"     Error: {msg['failure_type']}")
                print(f"     Retries: {msg['retry_count']}")
            
            # Demonstrate reprocessing
            print("🔄 Reprocessing first message...")
            success = await self.dlq_handler.reprocess_message(0)
            print(f"Reprocess result: {'SUCCESS' if success else 'FAILED'}")
            
            # Show failure analysis
            analysis = await self.dlq_handler.get_failure_analysis()
            print("📈 Failure Analysis:")
            print(f"  Failure types: {analysis['failure_types']}")
            print(f"  Failure sources: {analysis['failure_sources']}")

    async def run_full_simulation(self):
        """Run complete DLQ simulation scenario"""
        print("🎭 Starting Complete DLQ Simulation")
        print("=" * 50)
        
        try:
            # Clear existing DLQ for clean test
            cleared = await self.dlq_handler.clear_dlq()
            print(f"🧹 Cleared {cleared} existing DLQ messages")
            
            # Initial stats
            stats = await self.dlq_handler.get_dlq_stats()
            print(f"📊 Initial stats: {stats}")
            
            # Run various failure simulations
            await self.simulate_parsing_errors(5)
            await asyncio.sleep(1)
            
            await self.simulate_network_errors(3)
            await asyncio.sleep(1)
            
            await self.simulate_resource_errors(3)
            await asyncio.sleep(1)
            
            # Start processor to handle messages
            print("⚙️ Starting message processing...")
            
            # Process messages for limited time
            start_time = time.time()
            processed = 0
            
            while time.time() - start_time < 10:  # Process for 10 seconds
                try:
                    message_data = await asyncio.wait_for(
                        self.producer.redis.brpop("log_processing", timeout=1),
                        timeout=2
                    )
                    if message_data:
                        success = await self.processor.process_message(message_data[1].decode())
                        processed += 1
                        if processed % 5 == 0:
                            print(f"  Processed {processed} messages...")
                except asyncio.TimeoutError:
                    print("  No more messages in queue")
                    break
            
            # Show final stats
            final_stats = await self.dlq_handler.get_dlq_stats()
            print(f"\n📊 Final stats:")
            print(f"  Primary queue: {final_stats['primary_count']}")
            print(f"  Retry queue: {final_stats['retry_count']}")
            print(f"  Dead letter queue: {final_stats['dlq_count']}")
            print(f"  Processed messages: {final_stats['processed_count']}")
            
            # Demonstrate recovery
            await self.demonstrate_recovery()
            
            print("\n✅ DLQ Simulation Complete!")
            print(f"🌐 View real-time dashboard at: http://localhost:8000")
            
        except Exception as e:
            print(f"❌ Simulation error: {e}")
            raise
        
        finally:
            await self.cleanup()

    async def cleanup(self):
        """Clean up resources"""
        await self.producer.close()
        await self.processor.close()
        await self.dlq_handler.close()

# Quick simulation functions for specific scenarios

async def quick_parsing_errors():
    """Quick test of parsing error DLQ behavior"""
    simulator = DLQSimulator()
    try:
        await simulator.simulate_parsing_errors(5)
        print("Check dashboard to see DLQ messages appear!")
    finally:
        await simulator.cleanup()

async def quick_overload_test():
    """Quick overload simulation"""
    simulator = DLQSimulator()
    try:
        await simulator.simulate_overload_scenario(30)
        print("Burst load created - monitor system behavior!")
    finally:
        await simulator.cleanup()

# CLI interface
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        scenario = sys.argv[1]
        
        if scenario == "parsing":
            asyncio.run(quick_parsing_errors())
        elif scenario == "overload":
            asyncio.run(quick_overload_test())
        elif scenario == "full":
            simulator = DLQSimulator()
            asyncio.run(simulator.run_full_simulation())
        else:
            print("Usage: python dlq_simulation.py [parsing|overload|full]")
    else:
        # Run full simulation by default
        simulator = DLQSimulator()
        asyncio.run(simulator.run_full_simulation())