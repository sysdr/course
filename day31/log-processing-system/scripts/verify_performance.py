#!/usr/bin/env python3
"""
Performance verification for RabbitMQ setup.
"""
import time
import statistics
from message_queue.queue_manager import QueueManager

def performance_test():
    """Run basic performance verification."""
    print("🚀 Running RabbitMQ Performance Verification")
    
    manager = QueueManager()
    if not manager.connect():
        print("❌ Failed to connect")
        return
        
    try:
        # Publish 100 messages and measure time
        messages = 100
        start_time = time.time()
        
        for i in range(messages):
            message = {
                'id': i,
                'level': 'INFO',
                'source': 'performance_test',
                'message': f'Test message {i}'
            }
            manager.publish_message('logs.info.perf', message)
            
        end_time = time.time()
        duration = end_time - start_time
        throughput = messages / duration
        
        print(f"📊 Performance Results:")
        print(f"   Messages: {messages}")
        print(f"   Duration: {duration:.2f}s")
        print(f"   Throughput: {throughput:.0f} messages/second")
        
        # Check queue status
        info = manager.get_queue_info('log_messages')
        if info:
            print(f"   Queue depth: {info['message_count']} messages")
            
        if throughput > 100:
            print("✅ Performance verification PASSED")
        else:
            print("⚠️ Performance below expected threshold")
            
    finally:
        manager.close()

if __name__ == "__main__":
    performance_test()
