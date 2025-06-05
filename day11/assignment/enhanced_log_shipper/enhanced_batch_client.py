# assignment/enhanced_log_shipper/enhanced_batch_client.py
import socket
import json
import time
import threading
import logging
import zlib
import base64
from queue import Queue, Empty
from typing import Dict, List, Any, Optional, Tuple

from .metrics_collector import MetricsCollector

class EnhancedBatchLogClient:
    def __init__(self, 
                server_host: str = 'localhost', 
                server_port: int = 9999,
                batch_size: int = 100, 
                batch_interval: float = 5.0,
                max_udp_size: int = 65000,
                enable_compression: bool = True,
                compression_level: int = 6,
                retry_attempts: int = 3,
                retry_delay: float = 1.0):
        """Initialize an enhanced batch log client.
        
        Args:
            server_host (str): Log server hostname or IP
            server_port (int): Log server port
            batch_size (int): Maximum number of logs per batch
            batch_interval (float): Maximum seconds to wait before sending a batch
            max_udp_size (int): Maximum UDP packet size in bytes
            enable_compression (bool): Whether to compress batches
            compression_level (int): Compression level (1-9, higher = more compression)
            retry_attempts (int): Number of retry attempts for failed transmissions
            retry_delay (float): Initial delay between retries (will use exponential backoff)
        """
        self.server_host = server_host
        self.server_port = server_port
        self._batch_size = batch_size
        self._batch_interval = batch_interval
        self.max_udp_size = max_udp_size
        self.enable_compression = enable_compression
        self.compression_level = compression_level
        self.retry_attempts = retry_attempts
        self.retry_delay = retry_delay
        
        # Socket for sending logs
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        
        # Queue for storing logs before batching
        self.log_queue = Queue()
        
        # Batch storage
        self.current_batch: List[Dict[str, Any]] = []
        self.last_send_time = time.time()
        
        # Metrics collector
        self.metrics = MetricsCollector()
        
        # For dynamic configuration updates
        self._config_lock = threading.Lock()
        
        # Control flags
        self.running = False
        self.batch_thread: Optional[threading.Thread] = None
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger("EnhancedBatchLogClient")
    
    @property
    def batch_size(self) -> int:
        """Get the current batch size."""
        with self._config_lock:
            return self._batch_size
    
    @batch_size.setter
    def batch_size(self, value: int):
        """Set a new batch size."""
        if value <= 0:
            raise ValueError("Batch size must be greater than 0")
        
        with self._config_lock:
            old_value = self._batch_size
            self._batch_size = value
            self.logger.info(f"Updated batch size: {old_value} -> {value}")
    
    @property
    def batch_interval(self) -> float:
        """Get the current batch interval."""
        with self._config_lock:
            return self._batch_interval
    
    @batch_interval.setter
    def batch_interval(self, value: float):
        """Set a new batch interval."""
        if value <= 0:
            raise ValueError("Batch interval must be greater than 0")
        
        with self._config_lock:
            old_value = self._batch_interval
            self._batch_interval = value
            self.logger.info(f"Updated batch interval: {old_value}s -> {value}s")
    
    def start(self):
        """Start the batch processing thread."""
        if self.running:
            return
            
        self.running = True
        self.batch_thread = threading.Thread(target=self._batch_worker)
        self.batch_thread.daemon = True
        self.batch_thread.start()
        self.logger.info(f"Enhanced Batch Log Client started "
                       f"(batch_size={self.batch_size}, "
                       f"batch_interval={self.batch_interval}s, "
                       f"compression={'enabled' if self.enable_compression else 'disabled'})")
        
    def stop(self):
        """Stop the batch processing and flush any remaining logs."""
        if not self.running:
            return
            
        self.running = False
        
        # Send any remaining logs in the current batch
        self.flush()
        
        if self.batch_thread:
            self.batch_thread.join(timeout=2.0)
            
        self.logger.info("Enhanced Batch Log Client stopped")
        
    def send_log(self, log: Dict[str, Any]):
        """Queue a log to be sent in the next batch.
        
        Args:
            log (dict): The log message to send
        """
        if not self.running:
            self.start()
            
        self.log_queue.put(log)
        
    def flush(self):
        """Force send the current batch even if it's not full."""
        with threading.Lock():
            if self.current_batch:
                self._send_batch(self.current_batch)
                self.current_batch = []
                self.last_send_time = time.time()
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get the current metrics."""
        return self.metrics.get_metrics()
    
    def _compress_batch(self, data: bytes) -> Tuple[bytes, int, int]:
        """Compress batch data.
        
        Args:
            data (bytes): The batch data to compress
            
        Returns:
            Tuple[bytes, int, int]: Compressed data, original size, compressed size
        """
        original_size = len(data)
        
        if self.enable_compression:
            compressed_data = zlib.compress(data, self.compression_level)
            compressed_size = len(compressed_data)
            
            # Only use compression if it actually reduces size
            if compressed_size < original_size:
                self.logger.debug(f"Compressed batch: {original_size} -> {compressed_size} bytes "
                                f"({compressed_size/original_size:.2%} of original)")
                return compressed_data, original_size, compressed_size
        
        # Return original data if compression is disabled or not beneficial
        return data, original_size, original_size
    
    def _split_batch(self, batch: List[Dict[str, Any]]) -> List[List[Dict[str, Any]]]:
        """Split a batch into smaller batches that fit within UDP size limit.
        
        Args:
            batch (list): List of log dictionaries
            
        Returns:
            List[List[Dict]]: List of smaller batches
        """
        if not batch:
            return []
            
        result = []
        current_batch = []
        current_size = 0
        
        # Conservative estimate for batch overhead (JSON formatting, etc.)
        estimated_overhead = 50  
        
        for log in batch:
            # Estimate the size of this log
            log_json = json.dumps(log)
            log_size = len(log_json.encode('utf-8')) + 2  # +2 for comma and newline
            
            # If adding this log would exceed our limit, start a new batch
            if current_batch and (current_size + log_size + estimated_overhead > self.max_udp_size):
                result.append(current_batch)
                current_batch = []
                current_size = 0
            
            current_batch.append(log)
            current_size += log_size
        
        # Add the last batch if it's not empty
        if current_batch:
            result.append(current_batch)
        
        if len(result) > 1:
            self.logger.info(f"Split large batch of {len(batch)} logs into {len(result)} smaller batches")
        
        return result
    
    def _send_batch_with_retry(self, batch_data: bytes) -> bool:
        """Send batch data with retry logic.
        
        Args:
            batch_data (bytes): The batch data to send
            
        Returns:
            bool: True if send was successful, False otherwise
        """
        current_retry = 0
        current_delay = self.retry_delay
        
        while current_retry <= self.retry_attempts:
            try:
                start_time = time.time()
                self.sock.sendto(batch_data, (self.server_host, self.server_port))
                transmission_time = time.time() - start_time
                
                self.logger.debug(f"Batch sent successfully in {transmission_time:.3f}s")
                return True, transmission_time
            
            except Exception as e:
                current_retry += 1
                
                if current_retry <= self.retry_attempts:
                    self.logger.warning(f"Failed to send batch: {e}. "
                                      f"Retrying ({current_retry}/{self.retry_attempts}) "
                                      f"in {current_delay:.2f}s")
                    self.metrics.record_retry()
                    
                    # Exponential backoff
                    time.sleep(current_delay)
                    current_delay *= 2
                else:
                    self.logger.error(f"Failed to send batch after {self.retry_attempts} retries: {e}")
                    self.metrics.record_failure()
                    return False, 0
        
        return False, 0
    
    def _batch_worker(self):
        """Background thread that processes the log queue and creates batches."""
        while self.running:
            # Check if it's time to send the current batch based on the interval
            current_time = time.time()
            time_since_last_send = current_time - self.last_send_time
            
            if time_since_last_send >= self.batch_interval and self.current_batch:
                self.logger.debug(f"Batch interval of {self.batch_interval}s reached, sending batch")
                self.flush()
            
            # Try to get a log from the queue with a timeout
            try:
                log = self.log_queue.get(timeout=0.1)
                
                with threading.Lock():
                    self.current_batch.append(log)
                    
                    # If we've reached batch size, send the batch
                    batch_size = self.batch_size  # Get current batch size under lock
                    if len(self.current_batch) >= batch_size:
                        self.logger.debug(f"Batch size of {batch_size} reached, sending batch")
                        self._send_batch(self.current_batch)
                        self.current_batch = []
                        self.last_send_time = time.time()
                        
                self.log_queue.task_done()
                
            except Empty:
                # No logs in the queue, just continue and check interval
                pass
            except Exception as e:
                self.logger.error(f"Error in batch worker: {e}")
                
        # One final flush when shutting down
        self.flush()
        
    def _send_batch(self, batch: List[Dict[str, Any]]):
        """Send a batch of logs to the server.
        
        Args:
            batch (list): List of log dictionaries to send
        """
        if not batch:
            return
            
        # Split the batch if necessary
        sub_batches = self._split_batch(batch)
        
        for sub_batch in sub_batches:
            try:
                # Convert batch to JSON
                batch_json = json.dumps(sub_batch)
                batch_data = batch_json.encode('utf-8')
                original_size = len(batch_data)
                
                # Compress the data if enabled
                compressed_data, bytes_before, bytes_after = self._compress_batch(batch_data)
                
                # Add a simple protocol header to indicate if the batch is compressed
                header = b'C' if self.enable_compression and bytes_after < bytes_before else b'U'
                final_data = header + compressed_data
                
                # Send with retry logic
                success, transmission_time = self._send_batch_with_retry(final_data)
                
                if success:
                    self.metrics.record_batch_sent(
                        batch_size=len(sub_batch),
                        transmission_time=transmission_time,
                        bytes_before=bytes_before,
                        bytes_after=bytes_after
                    )
                    
                    self.logger.info(
                        f"Sent batch of {len(sub_batch)} logs "
                        f"({bytes_before} -> {bytes_after} bytes, "
                        f"{bytes_after/bytes_before:.1%} of original)"
                    )
                
            except Exception as e:
                self.logger.error(f"Error preparing batch for transmission: {e}")

# Example usage
if __name__ == "__main__":
    # Create a client with a small batch size and interval for demonstration
    client = EnhancedBatchLogClient(
        batch_size=5,
        batch_interval=3.0,
        enable_compression=True
    )
    client.start()
    
    try:
        # Send some example logs
        for i in range(20):
            log = {
                "timestamp": time.time(),
                "level": "INFO",
                "message": f"Test log message {i}",
                "service": "example-service",
                "metadata": {"iteration": i, "data": "A" * (i * 100)}  # Variable size data to show compression
            }
            client.send_log(log)
            
            # Sleep a bit to simulate log generation over time
            time.sleep(0.5)
            
        # Print metrics
        print("\nMetrics:")
        metrics = client.get_metrics()
        for key, value in metrics.items():
            if isinstance(value, list):
                continue  # Skip list metrics for brevity
            elif isinstance(value, float):
                print(f"  {key}: {value:.4f}")
            else:
                print(f"  {key}: {value}")
            
    except KeyboardInterrupt:
        pass
    finally:
        # Stop the client, which will flush any remaining logs
        client.stop()