import json
import time
import socket
import logging
import threading
from queue import Queue

# Import from local module
try:
    from compression import CompressionHandler
except ImportError:
    from src.compression import CompressionHandler

class LogShipper:
    def __init__(self, server_host, server_port, batch_size=100, batch_interval=5, 
                 compression_enabled=True, compression_algorithm='gzip', compression_level=6):
        self.server_host = server_host
        self.server_port = server_port
        self.batch_size = batch_size
        self.batch_interval = batch_interval
        self.log_queue = Queue()
        self.batch = []
        self.lock = threading.Lock()
        self.stats = {
            'logs_sent': 0,
            'batches_sent': 0,
            'failed_sends': 0,
            'compression_ratio_avg': 0,
            'compression_time_avg': 0
        }
        
        # Initialize compression handler if enabled
        self.compression_enabled = compression_enabled
        if compression_enabled:
            self.compressor = CompressionHandler(
                algorithm=compression_algorithm,
                level=compression_level
            )
        
        # Start the background worker thread
        self._start_worker()
        
    def _start_worker(self):
        """Start the background thread that processes the log queue."""
        self.running = True
        self.worker_thread = threading.Thread(target=self._process_queue)
        self.worker_thread.daemon = True
        self.worker_thread.start()
        
    def _process_queue(self):
        """Process logs from the queue and send in batches."""
        last_send_time = time.time()
        
        while self.running:
            # Get a log entry with a timeout
            try:
                log_entry = self.log_queue.get(timeout=0.1)
                with self.lock:
                    self.batch.append(log_entry)
            except:
                # Queue empty, continue with processing
                pass
                
            current_time = time.time()
            time_since_last_send = current_time - last_send_time
            
            with self.lock:
                # Send batch if we've reached batch size or time interval
                if (len(self.batch) >= self.batch_size or 
                    (len(self.batch) > 0 and time_since_last_send >= self.batch_interval)):
                    self._send_batch()
                    last_send_time = current_time
            
            time.sleep(0.01)  # Small sleep to reduce CPU usage
            
    def _send_batch(self):
        """Send the current batch of logs to the server."""
        if not self.batch:
            return
            
        try:
            # Convert batch to JSON and encode as bytes
            batch_data = json.dumps(self.batch).encode('utf-8')
            
            # Apply compression if enabled
            is_compressed = False
            compression_stats = {}
            if self.compression_enabled and batch_data:
                compressed_data, compression_stats = self.compressor.compress(batch_data)
                if not compression_stats.get('error'):
                    batch_data = compressed_data
                    is_compressed = True
                    
                    # Update compression stats
                    current_ratio_avg = self.stats['compression_ratio_avg']
                    current_time_avg = self.stats['compression_time_avg']
                    batches_sent = self.stats['batches_sent']
                    
                    # Calculate new rolling averages
                    if batches_sent > 0:
                        self.stats['compression_ratio_avg'] = (current_ratio_avg * batches_sent + compression_stats['ratio']) / (batches_sent + 1)
                        self.stats['compression_time_avg'] = (current_time_avg * batches_sent + compression_stats['time_ms']) / (batches_sent + 1)
            
            # Create a header to indicate if the data is compressed
            header = {
                'compressed': is_compressed,
                'algorithm': self.compressor.algorithm if is_compressed else None,
                'original_size': compression_stats.get('original_size', len(batch_data)),
                'log_count': len(self.batch)
            }
            header_data = json.dumps(header).encode('utf-8')
            
            # Send the data
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.connect((self.server_host, self.server_port))
                
                # Send header length as 4 bytes
                header_length = len(header_data)
                sock.sendall(header_length.to_bytes(4, byteorder='big'))
                
                # Send header
                sock.sendall(header_data)
                
                # Send the actual log data
                sock.sendall(batch_data)
                
            # Update stats
            self.stats['logs_sent'] += len(self.batch)
            self.stats['batches_sent'] += 1
            
            # Clear the batch
            self.batch = []
            
        except Exception as e:
            logging.error(f"Failed to send batch: {str(e)}")
            self.stats['failed_sends'] += 1
            
    def ship_log(self, log_entry):
        """Add a log entry to the queue for shipping."""
        self.log_queue.put(log_entry)
        
    def get_stats(self):
        """Get current statistics."""
        with self.lock:
            return self.stats.copy()
            
    def shutdown(self):
        """Shutdown the shipper and send any remaining logs."""
        self.running = False
        self.worker_thread.join(timeout=5)
        
        # Send any remaining logs
        with self.lock:
            if self.batch:
                self._send_batch()
