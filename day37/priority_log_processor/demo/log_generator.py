import asyncio
import random
import time
from src.processor import LogProcessor

class LogGenerator:
    def __init__(self, processor: LogProcessor):
        self.processor = processor
        self.running = False
        
    def generate_random_log(self) -> dict:
        """Generate a random log message"""
        message_types = [
            # Critical messages
            {'level': 'ERROR', 'message': 'Payment failed for transaction', 'service': 'payment'},
            {'level': 'ERROR', 'message': 'Database connection lost', 'service': 'database'},
            {'level': 'ERROR', 'message': 'Security breach detected', 'service': 'security'},
            
            # High priority messages
            {'level': 'WARN', 'message': 'High latency detected', 'service': 'api-gateway'},
            {'level': 'WARN', 'message': 'Memory usage above 80%', 'service': 'application'},
            {'level': 'WARN', 'message': 'Queue depth exceeding threshold', 'service': 'message-broker'},
            
            # Medium priority messages
            {'level': 'INFO', 'message': 'User login successful', 'service': 'user-service'},
            {'level': 'INFO', 'message': 'Order processed successfully', 'service': 'order-service'},
            {'level': 'INFO', 'message': 'Cache miss occurred', 'service': 'cache'},
            
            # Low priority messages
            {'level': 'DEBUG', 'message': 'Database query executed', 'service': 'analytics'},
            {'level': 'DEBUG', 'message': 'Request trace logged', 'service': 'tracing'},
            {'level': 'DEBUG', 'message': 'Metric collected', 'service': 'monitoring'}
        ]
        
        base_message = random.choice(message_types)
        return {
            **base_message,
            'timestamp': time.time(),
            'request_id': f"req-{random.randint(1000, 9999)}",
            'user_id': random.randint(1, 1000)
        }
    
    async def start_generating(self, rate: int = 10):
        """Start generating log messages at specified rate (messages per second)"""
        self.running = True
        interval = 1.0 / rate
        
        print(f"🎯 Starting log generation at {rate} messages/second")
        
        while self.running:
            log_message = self.generate_random_log()
            success = self.processor.process_log_message(log_message)
            
            if not success:
                print("⚠️ Queue full, dropping message")
            
            await asyncio.sleep(interval)
    
    def stop_generating(self):
        """Stop generating log messages"""
        self.running = False
        print("🛑 Log generation stopped")

async def main():
    """Demo script showing priority queue in action"""
    processor = LogProcessor(num_workers=6)
    generator = LogGenerator(processor)
    
    try:
        # Start the processor
        await processor.start()
        
        # Generate logs for 30 seconds
        generation_task = asyncio.create_task(generator.start_generating(rate=50))
        
        # Monitor for 30 seconds
        for i in range(30):
            await asyncio.sleep(1)
            status = processor.get_queue_status()
            print(f"[{i+1:2d}s] Queue sizes: C:{status['queue_by_priority']['CRITICAL']} "
                  f"H:{status['queue_by_priority']['HIGH']} "
                  f"M:{status['queue_by_priority']['MEDIUM']} "
                  f"L:{status['queue_by_priority']['LOW']} "
                  f"| Processed: {status['processed_messages_count']}")
        
        generator.stop_generating()
        await generation_task
        
    finally:
        await processor.stop()

if __name__ == "__main__":
    asyncio.run(main())
