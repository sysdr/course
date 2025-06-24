import time
import threading
from typing import Callable, Dict, List
from dataclasses import dataclass
import structlog
from tenacity import Retrying, stop_after_attempt, wait_exponential, retry_if_exception_type

logger = structlog.get_logger()

class RetryableError(Exception):
    """Exception indicating a retryable failure"""
    pass

class FatalError(Exception):
    """Exception indicating a non-retryable failure"""
    pass

@dataclass
class RedeliveryAttempt:
    delivery_tag: int
    attempt_count: int
    scheduled_time: float
    original_message: bytes
    routing_key: str

class RedeliveryHandler:
    def __init__(self, max_retries: int = 3, base_delay: int = 1, max_delay: int = 30):
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.pending_redeliveries: Dict[int, RedeliveryAttempt] = {}
        self.lock = threading.RLock()
        self.redelivery_callback: Callable = None
        self._stop_redelivery = False
        self._redelivery_thread = threading.Thread(target=self._process_redeliveries, daemon=True)
        self._redelivery_thread.start()
    
    def schedule_redelivery(self, delivery_tag: int, message: bytes, 
                          routing_key: str, current_attempt: int = 0) -> bool:
        """Schedule a message for redelivery with exponential backoff"""
        if current_attempt >= self.max_retries:
            logger.error("Max retries exceeded", 
                        delivery_tag=delivery_tag, 
                        attempts=current_attempt)
            return False
        
        delay = min(self.base_delay * (2 ** current_attempt), self.max_delay)
        scheduled_time = time.time() + delay
        
        with self.lock:
            self.pending_redeliveries[delivery_tag] = RedeliveryAttempt(
                delivery_tag=delivery_tag,
                attempt_count=current_attempt + 1,
                scheduled_time=scheduled_time,
                original_message=message,
                routing_key=routing_key
            )
        
        logger.info("Redelivery scheduled", 
                   delivery_tag=delivery_tag, 
                   attempt=current_attempt + 1,
                   delay_seconds=delay)
        return True
    
    def cancel_redelivery(self, delivery_tag: int) -> bool:
        """Cancel a scheduled redelivery (message was processed successfully)"""
        with self.lock:
            if delivery_tag in self.pending_redeliveries:
                del self.pending_redeliveries[delivery_tag]
                logger.info("Redelivery cancelled", delivery_tag=delivery_tag)
                return True
            return False
    
    def get_retry_decorator(self):
        """Get a tenacity retry decorator with configured parameters"""
        return Retrying(
            stop=stop_after_attempt(self.max_retries),
            wait=wait_exponential(multiplier=self.base_delay, max=self.max_delay),
            retry=retry_if_exception_type(RetryableError),
            reraise=True
        )
    
    def _process_redeliveries(self):
        """Background thread to process scheduled redeliveries"""
        while not self._stop_redelivery:
            try:
                current_time = time.time()
                ready_for_redelivery = []
                
                with self.lock:
                    for delivery_tag, attempt in list(self.pending_redeliveries.items()):
                        if current_time >= attempt.scheduled_time:
                            ready_for_redelivery.append(attempt)
                            del self.pending_redeliveries[delivery_tag]
                
                # Process redeliveries outside of lock
                for attempt in ready_for_redelivery:
                    if self.redelivery_callback:
                        try:
                            self.redelivery_callback(attempt)
                            logger.info("Message redelivered", 
                                      delivery_tag=attempt.delivery_tag,
                                      attempt=attempt.attempt_count)
                        except Exception as e:
                            logger.error("Redelivery callback failed", 
                                       delivery_tag=attempt.delivery_tag,
                                       error=str(e))
                
                time.sleep(0.5)  # Check every 500ms for responsiveness
            except Exception as e:
                logger.error("Error in redelivery processor", error=str(e))
                time.sleep(5)
    
    def set_redelivery_callback(self, callback: Callable[[RedeliveryAttempt], None]):
        """Set callback function for handling redeliveries"""
        self.redelivery_callback = callback
    
    def get_stats(self) -> Dict[str, int]:
        """Get redelivery statistics"""
        with self.lock:
            return {
                'pending_redeliveries': len(self.pending_redeliveries),
                'max_retries': self.max_retries
            }
    
    def stop(self):
        """Stop the redelivery processing thread"""
        self._stop_redelivery = True
