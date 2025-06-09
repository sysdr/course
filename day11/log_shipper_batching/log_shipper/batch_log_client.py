# week2/day11/log_shipper/batch_log_client.py
import socket
import json
import time
import threading
import logging
from queue import Queue, Empty
from typing import Dict, List, Any, Optional

class BatchLogClient:
    def __init__(self, 
                server_host: str = 'localhost', 
                server_port: int = 9999,
                batch_size: int = 100, 
                batch_interval: float = 5.0):
        """Initialize a batch log client.
        
        Args:
            server_host (str): Log server hostname or IP
            server_port (int): Log server port
            batch_size (int): Maximum number of logs per batch
            batch_interval (float): Maximum seconds to wait before sending a batch
        """
        self.server_host = server_host
        self.server_port = server_port
        self.batch_size = batch_size
        self.batch_interval = batch_interval
        
        # Socket for sending logs
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        
        # Queue for storing logs before batching
        self.log_queue = Queue()
        
        # Batch storage
        self.current_batch: List[Dict[str, Any]] = []
        self.last_send_time = time.time()
        
        # Control flags
        self.running = False
        self.batch_thread: Optional[threading.Thread] = None
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger("BatchLogClient")
        
    def start(self):
        """Start the batch processing thread."""
        if self.running:
            return
            
        self.running = True
        self.batch_thread = threading.Thread(target=self._batch_worker)
        self.batch_thread.daemon = True
        self.batch_thread.start()
        self.logger.info(f"Batch Log Client started (batch_size={self.batch_size}, " 
                        f"batch_interval={self.batch_interval}s)")
        
    def stop(self):
        """Stop the batch processing and flush any remaining logs."""
        if not self.running:
            return
            
        self.running = False
        
        # Send any remaining logs in the current batch
        self.flush()
        
        if self.batch_thread:
            self.batch_thread.join(timeout=2.0)
            
        self.logger.info("Batch Log Client stopped")
        
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
                    if len(self.current_batch) >= self.batch_size:
                        self.logger.debug(f"Batch size of {self.batch_size} reached, sending batch")
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
            
        try:
            # Convert batch to JSON and send over UDP
            batch_data = json.dumps(batch).encode('utf-8')
            
            # Check if the batch is too large for UDP
            if len(batch_data) > 65507:  # UDP practical limit
                self.logger.warning(f"Batch size ({len(batch_data)} bytes) exceeds UDP limit. Splitting...")
                # In a real system, we would implement batch splitting
                # For this example, we'll just show a warning
                
            self.sock.sendto(batch_data, (self.server_host, self.server_port))
            self.logger.info(f"Sent batch of {len(batch)} logs ({len(batch_data)} bytes)")
            
        except Exception as e:
            self.logger.error(f"Error sending batch: {e}")

# Example usage
if __name__ == "__main__":
    # Create a client with a small batch size and interval for demonstration
    client = BatchLogClient(batch_size=5, batch_interval=3.0)
    client.start()
    
    try:
        # Send some example logs
        for i in range(20):
            log = {
                "timestamp": time.time(),
                "level": "INFO",
                "message": f"Test log message {i}",
                "service": "example-service",
                "metadata": {"iteration": i}
            }
            client.send_log(log)
            
            # Sleep a bit to simulate log generation over time
            time.sleep(0.5)
            
    except KeyboardInterrupt:
        pass
    finally:
        # Stop the client, which will flush any remaining logs
        client.stop()