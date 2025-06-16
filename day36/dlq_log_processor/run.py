#!/usr/bin/env python3
"""
DLQ Log Processing System Runner
Starts all components for demonstration
"""

import asyncio
import signal
import sys
from concurrent.futures import ThreadPoolExecutor
import subprocess
import time

from src.producer import LogProducer
from src.processor import LogProcessor
from src.dashboard import app
import uvicorn

class SystemRunner:
    def __init__(self):
        self.producer = LogProducer()
        self.processor = LogProcessor()
        self.running = False
        
    async def start_producer(self):
        """Start message producer"""
        print("🚀 Starting message producer...")
        while self.running:
            await self.producer.produce_messages(50, 0.1)
            await asyncio.sleep(2)
    
    async def start_processor(self):
        """Start message processor"""
        print("⚙️  Starting message processor...")
        await self.processor.run()
    
    def start_dashboard(self):
        """Start web dashboard"""
        print("📊 Starting web dashboard on http://localhost:8000")
        uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
    
    async def run_system(self):
        """Run the complete system"""
        self.running = True
        
        print("🎯 Starting DLQ Log Processing System...")
        print("📊 Dashboard will be available at: http://localhost:8000")
        print("🔄 Producer will generate log messages continuously")
        print("⚙️  Processor will handle messages with simulated failures")
        print("💀 Failed messages will be sent to dead letter queue")
        print("\nPress Ctrl+C to stop the system\n")
        
        # Start dashboard in a separate thread
        executor = ThreadPoolExecutor(max_workers=1)
        dashboard_future = executor.submit(self.start_dashboard)
        
        # Give dashboard time to start
        await asyncio.sleep(3)
        
        try:
            # Run producer and processor concurrently
            await asyncio.gather(
                self.start_producer(),
                self.start_processor(),
                return_exceptions=True
            )
        except KeyboardInterrupt:
            print("\n🛑 Shutting down system...")
        finally:
            self.running = False
            await self.producer.close()
            await self.processor.close()
            executor.shutdown(wait=False)

def signal_handler(signum, frame):
    print("\n🛑 Received interrupt signal, shutting down...")
    sys.exit(0)

if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    runner = SystemRunner()
    asyncio.run(runner.run_system())
