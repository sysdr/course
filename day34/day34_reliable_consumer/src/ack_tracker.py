import time
import threading
from typing import Dict, Optional, Callable
from dataclasses import dataclass
from enum import Enum
import structlog

logger = structlog.get_logger()

class MessageStatus(Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    ACKNOWLEDGED = "acknowledged"
    FAILED = "failed"
    REDELIVERED = "redelivered"

@dataclass
class MessageState:
    delivery_tag: int
    timestamp: float
    status: MessageStatus
    retry_count: int = 0
    last_error: Optional[str] = None

class AckTracker:
    def __init__(self, timeout_seconds: int = 30):
        self.timeout_seconds = timeout_seconds
        self.messages: Dict[int, MessageState] = {}
        self.lock = threading.RLock()
        self.timeout_callback: Optional[Callable] = None
        self._stop_monitoring = False
        self._monitor_thread = threading.Thread(target=self._monitor_timeouts, daemon=True)
        self._monitor_thread.start()
    
    def track_message(self, delivery_tag: int) -> None:
        """Start tracking a message for acknowledgment"""
        with self.lock:
            self.messages[delivery_tag] = MessageState(
                delivery_tag=delivery_tag,
                timestamp=time.time(),
                status=MessageStatus.PENDING
            )
            logger.info("Tracking message", delivery_tag=delivery_tag)
    
    def mark_processing(self, delivery_tag: int) -> bool:
        """Mark message as being processed"""
        with self.lock:
            if delivery_tag in self.messages:
                self.messages[delivery_tag].status = MessageStatus.PROCESSING
                logger.info("Message processing started", delivery_tag=delivery_tag)
                return True
            return False
    
    def acknowledge(self, delivery_tag: int) -> bool:
        """Mark message as successfully acknowledged"""
        with self.lock:
            if delivery_tag in self.messages:
                self.messages[delivery_tag].status = MessageStatus.ACKNOWLEDGED
                logger.info("Message acknowledged", delivery_tag=delivery_tag)
                # Clean up acknowledged messages after short delay
                del self.messages[delivery_tag]
                return True
            return False
    
    def mark_failed(self, delivery_tag: int, error: str) -> bool:
        """Mark message as failed with error details"""
        with self.lock:
            if delivery_tag in self.messages:
                state = self.messages[delivery_tag]
                state.status = MessageStatus.FAILED
                state.last_error = error
                state.retry_count += 1
                logger.warning("Message failed", 
                             delivery_tag=delivery_tag, 
                             error=error, 
                             retry_count=state.retry_count)
                return True
            return False
    
    def get_message_state(self, delivery_tag: int) -> Optional[MessageState]:
        """Get current state of a tracked message"""
        with self.lock:
            return self.messages.get(delivery_tag)
    
    def get_stats(self) -> Dict[str, int]:
        """Get current tracking statistics"""
        with self.lock:
            stats = {}
            for status in MessageStatus:
                stats[status.value] = sum(1 for msg in self.messages.values() 
                                        if msg.status == status)
            return stats
    
    def _monitor_timeouts(self):
        """Background thread to monitor message timeouts"""
        while not self._stop_monitoring:
            try:
                current_time = time.time()
                timed_out_messages = []
                
                with self.lock:
                    for delivery_tag, state in list(self.messages.items()):
                        if (state.status in [MessageStatus.PENDING, MessageStatus.PROCESSING] and
                            current_time - state.timestamp > self.timeout_seconds):
                            timed_out_messages.append(delivery_tag)
                
                # Handle timeouts outside of lock
                for delivery_tag in timed_out_messages:
                    if self.timeout_callback:
                        self.timeout_callback(delivery_tag)
                    logger.warning("Message timeout detected", delivery_tag=delivery_tag)
                
                time.sleep(1)  # Check every second
            except Exception as e:
                logger.error("Error in timeout monitor", error=str(e))
                time.sleep(5)
    
    def set_timeout_callback(self, callback: Callable[[int], None]):
        """Set callback function for handling timeouts"""
        self.timeout_callback = callback
    
    def stop(self):
        """Stop the timeout monitoring thread"""
        self._stop_monitoring = True
