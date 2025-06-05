import threading
import time
from typing import Callable, List, Optional

class BatchCollector:
    """
    Collects log messages into batches and triggers sending when
    either batch size or time interval thresholds are reached.
    """
    
    def __init__(
        self,
        send_callback: Callable[[List[str]], None],
        max_batch_size: int = 100,
        max_interval_seconds: float = 5.0
        self.check_interval = min(1.0, max_interval_seconds / 2)
        self._start_periodic_check()
    ):
        """
        Initialize a new BatchCollector.
        
        Args:
            send_callback: Function to call when a batch is ready to send
            max_batch_size: Maximum number of messages in a batch
            max_interval_seconds: Maximum time to wait before sending a batch
        """
        self.send_callback = send_callback
        self.max_batch_size = max_batch_size
        self.max_interval_seconds = max_interval_seconds
        
        # Initialize batch storage
        self.current_batch: List[str] = []
        self.batch_lock = threading.Lock()
        
        # Timer tracking
        self.batch_start_time: Optional[float] = None
        self.timer: Optional[threading.Timer] = None
    
    def add_log(self, log_message: str) -> None:
        """
        Add a log message to the current batch.
        Sends the batch if thresholds are met.
        
        Args:
            log_message: The log message to add
        """
        with self.batch_lock:
            # Start timer on first message in batch
            if not self.current_batch:
                self.batch_start_time = time.time()
                self._start_timer()
            
            # Add message to batch
            self.current_batch.append(log_message)
            
            # Check if we've reached max batch size
            if len(self.current_batch) >= self.max_batch_size:
                self._send_batch()
    
    def _start_timer(self) -> None:
        """Start a timer that will trigger batch sending after max_interval_seconds."""
        if self.timer:
            self.timer.cancel()
        
        self.timer = threading.Timer(
            self.max_interval_seconds, 
            self._timer_triggered
        )
        self.timer.daemon = True  # Don't prevent program exit
        self.timer.start()
    
    def _timer_triggered(self) -> None:
        """Called when the timer expires. Sends the current batch if not empty."""
        with self.batch_lock:
            if self.current_batch:
                self._send_batch()
    
    def _send_batch(self) -> None:
        """Send the current batch using the callback and reset batch state."""
        if not self.current_batch:
            return
            
        # Make a copy of the current batch
        batch_to_send = self.current_batch.copy()
        
        # Reset the batch
        self.current_batch = []
        self.batch_start_time = None
        
        # Cancel any pending timer
        if self.timer:
            self.timer.cancel()
            self.timer = None
        
        # Send the batch (outside the lock to avoid blocking)
        self.send_callback(batch_to_send)
    def add_log(self, log_message: str) -> None:
        """
        Add a log message to the current batch.
        Sends the batch if size thresholds are met.
        
        Args:
            log_message: The log message to add
        """
        message_size = len(log_message.encode('utf-8'))  # Size in bytes
    
        with self.batch_lock:
            # Start timer on first message in batch
            if not self.current_batch:
                self.batch_start_time = time.time()
                self.current_batch_bytes = 0
                self._start_timer()
            
            # Add message to batch
            self.current_batch.append(log_message)
            self.current_batch_bytes += message_size
            
            # Check if we've reached max batch size (either count or bytes)
            if (len(self.current_batch) >= self.max_batch_size or
                    self.current_batch_bytes >= self.max_batch_bytes):
                self._send_batch()
    
    def flush(self) -> None:
        """
        Immediately send any logs in the current batch.
        Useful for graceful shutdown.
        """
        with self.batch_lock:
            self._send_batch()
        

    def _start_periodic_check(self):
        """Start a periodic check for time-based batch sending."""
        def check_and_reschedule():
            self._check_time_trigger()
            self.check_timer = threading.Timer(self.check_interval, check_and_reschedule)
            self.check_timer.daemon = True
            self.check_timer.start()
        
        self.check_timer = threading.Timer(self.check_interval, check_and_reschedule)
        self.check_timer.daemon = True
        self.check_timer.start()

    def _check_time_trigger(self):
        """Check if the current batch has exceeded the time threshold."""
        with self.batch_lock:
            if (self.current_batch and self.batch_start_time and
                    time.time() - self.batch_start_time >= self.max_interval_seconds):
                self._send_batch()

