import asyncio
import json
import time
import uuid
from typing import Dict, Any, List
from .priority_queue import PriorityQueue, PriorityQueueManager, Message, Priority
from .message_classifier import MessageClassifier

class LogProcessor:
    def __init__(self, max_queue_size: int = 10000, num_workers: int = 4):
        self.queue_manager = PriorityQueueManager(num_workers)
        self.classifier = MessageClassifier()
        self.running = False
        self.metrics = {
            'messages_received': 0,
            'messages_processed': 0,
            'messages_by_priority': {p.name: 0 for p in Priority}
        }
        
    async def start(self):
        """Start the log processor"""
        self.running = True
        await self.queue_manager.start()
        print("🚀 Log processor started")
        
    async def stop(self):
        """Stop the log processor"""
        self.running = False
        await self.queue_manager.stop()
        print("🛑 Log processor stopped")
        
    def process_log_message(self, raw_message: Dict[str, Any]) -> bool:
        """Process a single log message"""
        if not self.running:
            return False
            
        # Classify the message
        priority = self.classifier.classify(raw_message)
        
        # Create message object
        message = Message(
            priority=priority,
            timestamp=time.time(),
            content=raw_message,
            message_id=str(uuid.uuid4())
        )
        
        # Add to priority queue
        success = self.queue_manager.queue.put(message)
        
        if success:
            self.metrics['messages_received'] += 1
            self.metrics['messages_by_priority'][priority.name] += 1
            
        return success
    
    def get_queue_status(self) -> Dict[str, Any]:
        """Get current queue status and metrics"""
        queue_sizes = self.queue_manager.queue.size_by_priority()
        
        return {
            'total_queue_size': self.queue_manager.queue.size(),
            'queue_by_priority': {p.name: queue_sizes.get(p, 0) for p in Priority},
            'metrics': self.metrics,
            'processed_messages_count': len(self.queue_manager.processed_messages),
            'is_running': self.running
        }
    
    def get_processed_messages(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Get recently processed messages"""
        return self.queue_manager.processed_messages[-limit:]
