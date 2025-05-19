import socket
import time
import json
import os
import gzip
import threading
import io
from collections import deque
from typing import Optional, List, Dict, Any
from src.resilient_shipper import ResilientLogShipper
from src.log_reader import LogReader

class EnhancedLogShipper(ResilientLogShipper):
    """Enhanced log shipping client with compression, batching, and monitoring."""
    
    def __init__(self, server_host: str, server_port: int, 
                 log_reader: LogReader, buffer_size: int = 1000,
                 persistence_file: Optional[str] = "undelivered_logs.json",
                 max_retries: int = 5, compress_logs: bool = True,
                 batch_size: int = 10, heartbeat_interval: int = 30):
        """Initialize the enhanced log shipper.
        
        Args:
            server_host: Hostname or IP of the TCP log server
            server_port: Port the TCP log server is listening on
            log_reader: LogReader instance to read logs from
            buffer_size: Maximum number of logs to keep in memory buffer
            persistence_file: File to store undelivered logs between restarts
            max_retries: Maximum number of connection retry attempts
            compress_logs: Whether to compress logs before sending
            batch_size: Number of logs to batch together before sending
            heartbeat_interval: Seconds between server heartbeat checks
        """
        super().__init__(server_host, server_port, log_reader, 
                         buffer_size, persistence_file, max_retries)
                         
        self.compress_logs = compress_logs
        self.batch_size = batch_size
        self.heartbeat_interval = heartbeat_interval
        
        # Metrics
        self.metrics = {
            "logs_sent": 0,
            "logs_failed": 0,
            "bytes_sent": 0,
            "bytes_saved_by_compression": 0,
            "connection_attempts": 0,
            "connection_failures": 0,
            "heartbeats_sent": 0,
            "heartbeats_failed": 0,
            "average_latency_ms": 0,
            "total_latency_samples": 0,
        }
        
        # Start heartbeat thread if interval > 0
        self.running = True
        if self.heartbeat_interval > 0:
            self.heartbeat_thread = threading.Thread(target=self._heartbeat_loop)
            self.heartbeat_thread.daemon = True
            self.heartbeat_thread.start()
    
    def _heartbeat_loop(self) -> None:
        """Background thread that sends heartbeats to check server connectivity."""
        while self.running:
            time.sleep(self.heartbeat_interval)
            self._send_heartbeat()
    
    def _send_heartbeat(self) -> bool:
        """Send a heartbeat to check if the server is available.
        
        Returns:
            True if server responded, False otherwise
        """
        if self.socket is None:
            # Try to establish a connection
            connection_result = self.connect()
            if not connection_result:
                self.metrics["heartbeats_failed"] += 1
                return False
        
        try:
            # Send a small heartbeat message
            start_time = time.time()
            self.socket.sendall(b"HEARTBEAT\n")
            
            # Set a timeout for the response
            self.socket.settimeout(2)
            
            # We don't actually need to read anything, just make sure
            # the send succeeds and the connection is still up
            
            # Update metrics
            end_time = time.time()
            latency_ms = (end_time - start_time) * 1000
            
            # Update rolling average latency
            total_latency = (self.metrics["average_latency_ms"] * 
                            self.metrics["total_latency_samples"])
            self.metrics["total_latency_samples"] += 1
            self.metrics["average_latency_ms"] = (total_latency + latency_ms) / \
                                                self.metrics["total_latency_samples"]
            
            self.metrics["heartbeats_sent"] += 1
            
            # Reset timeout to blocking mode
            self.socket.settimeout(None)
            return True
        except socket.error:
            self.metrics["heartbeats_failed"] += 1
            self.socket = None  # Connection is dead
            return False
    
    def _compress_logs(self, logs: List[str]) -> bytes:
        """Compress a batch of logs into a single gzipped payload.
        
        Args:
            logs: List of log strings to compress
            
        Returns:
            Compressed binary data
        """
        # Join logs with newlines
        combined = ''.join(log if log.endswith('\n') else log + '\n' for log in logs)
        combined_bytes = combined.encode('utf-8')
        
        # Compress
        with io.BytesIO() as compressed_stream:
            with gzip.GzipFile(fileobj=compressed_stream, mode='wb') as f:
                f.write(combined_bytes)
            
            compressed_data = compressed_stream.getvalue()
        
        # Update metrics
        self.metrics["bytes_saved_by_compression"] += (len(combined_bytes) - len(compressed_data))
        
        return compressed_data
    
    def _send_batch(self, logs: List[str]) -> int:
        """Send a batch of logs to the server.
        
        Args:
            logs: List of log strings to send
            
        Returns:
            Number of logs successfully sent
        """
        if not logs:
            return 0
            
        if not self.socket and not self.connect():
            return 0
        
        try:
            start_time = time.time()
            
            if self.compress_logs:
                # Send compressed batch with header to indicate compression
                compressed_data = self._compress_logs(logs)
                self.socket.sendall(b"COMPRESSED\n")
                
                # Send length of compressed data followed by the data itself
                length_bytes = str(len(compressed_data)).encode('utf-8') + b"\n"
                self.socket.sendall(length_bytes)
                self.socket.sendall(compressed_data)
                
                self.metrics["bytes_sent"] += len(compressed_data) + len(length_bytes) + 11  # Header length
            else:
                # Send each log individually
                batch_data = ''.join(log if log.endswith('\n') else log + '\n' for log in logs)
                batch_bytes = batch_data.encode('utf-8')
                self.socket.sendall(batch_bytes)
                
                self.metrics["bytes_sent"] += len(batch_bytes)
            
            # Update metrics
            end_time = time.time()
            latency_ms = (end_time - start_time) * 1000
            
            # Update rolling average latency
            total_latency = (self.metrics["average_latency_ms"] * 
                           self.metrics["total_latency_samples"])
            self.metrics["total_latency_samples"] += 1
            self.metrics["average_latency_ms"] = (total_latency + latency_ms) / \
                                               self.metrics["total_latency_samples"]
            
            self.metrics["logs_sent"] += len(logs)
            
            return len(logs)
        except socket.error as e:
            print(f"Error sending batch: {e}")
            self.metrics["logs_failed"] += len(logs)
            self.socket = None  # Mark connection as dead
            return 0
    
    def connect(self) -> bool:
        """Establish connection to the TCP server with metrics tracking."""
        self.metrics["connection_attempts"] += 1
        result = super().connect()
        
        if not result:
            self.metrics["connection_failures"] += 1
            
        return result
    
    def ship_logs_batch(self, logs: Optional[List[str]] = None) -> int:
        """Ship logs in batches with compression.
        
        Args:
            logs: List of log strings to ship. If None, reads from the log_reader.
            
        Returns:
            Number of logs successfully shipped
        """
        # First, try to send any buffered logs
        buffer_sent = self._process_buffer_in_batches()
        
        # Get new logs if none were provided
        if logs is None:
            logs = self.log_reader.read_batch()
        
        if not logs:
            return buffer_sent
        
        # Ensure we have a connection
        if not self.socket and not self.connect():
            # If we can't connect, buffer all logs
            self.buffer.extend(logs)
            return buffer_sent
        
        # Process logs in batches
        logs_shipped = buffer_sent
        for i in range(0, len(logs), self.batch_size):
            batch = logs[i:i + self.batch_size]
            sent = self._send_batch(batch)
            
            if sent == 0:
                # Failed to send batch, buffer remaining logs
                self.buffer.extend(logs[i:])
                break
                
            logs_shipped += sent
        
        return logs_shipped
    
    def _process_buffer_in_batches(self) -> int:
        """Process buffered logs in batches.
        
        Returns:
            Number of logs successfully sent
        """
        if not self.buffer:
            return 0
            
        if not self.socket and not self.connect():
            return 0
            
        logs_sent = 0
        # Process the buffer in batches
        while self.buffer and logs_sent < len(self.buffer):
            # Get a batch from the buffer
            batch = []
            for _ in range(min(self.batch_size, len(self.buffer))):
                if self.buffer:
                    batch.append(self.buffer.popleft())
            
            # Send the batch
            sent = self._send_batch(batch)
            
            if sent == 0:
                # Failed to send batch, put logs back in buffer
                self.buffer.extendleft(reversed(batch))
                break
                
            logs_sent += sent
        
        return logs_sent
    
    def ship_logs_continuously(self) -> None:
        """Continuously ship logs as they're generated, in batches with compression."""
        # First, process any buffered logs
        self._process_buffer_in_batches()
        
        # Ensure initial connection
        if not self.socket and not self.connect():
            print("Could not establish initial connection, will retry")
        
        try:
            current_batch = []
            
            for log in self.log_reader.read_incremental():
                # Add to current batch
                current_batch.append(log)
                
                # If we've reached batch size, send the batch
                if len(current_batch) >= self.batch_size:
                    # Try to process any buffered logs first
                    self._process_buffer_in_batches()
                    
                    # Try to send the current batch
                    if self.socket:
                        sent = self._send_batch(current_batch)
                        if sent == 0:
                            # Failed to send, buffer the batch
                            self.buffer.extend(current_batch)
                            
                            # Try to reconnect
                            self.connect()
                    else:
                        # No connection, buffer the batch
                        self.buffer.extend(current_batch)
                        
                        # Try to reconnect
                        self.connect()
                    
                    # Clear the batch
                    current_batch = []
        except KeyboardInterrupt:
            print("\nStopping log shipping")
        finally:
            # Send any remaining logs in the current batch
            if current_batch:
                if self.socket:
                    sent = self._send_batch(current_batch)
                    if sent == 0:
                        # Failed to send, buffer the batch
                        self.buffer.extend(current_batch)
                else:
                    # No connection, buffer the batch
                    self.buffer.extend(current_batch)
            
            self.close()
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get current metrics.
        
        Returns:
            Dictionary of metric names and values
        """
        # Add buffer utilization to metrics
        buffer_utilization = len(self.buffer) / self.buffer_size if self.buffer_size > 0 else 0
        metrics_copy = self.metrics.copy()
        metrics_copy["buffer_utilization"] = buffer_utilization
        metrics_copy["buffer_size"] = len(self.buffer)
        metrics_copy["buffer_capacity"] = self.buffer_size
        
        return metrics_copy
    
    def print_metrics(self) -> None:
        """Print current metrics to console."""
        metrics = self.get_metrics()
        
        print("\n=== Log Shipping Metrics ===")
        print(f"Logs Sent: {metrics['logs_sent']}")
        print(f"Logs Failed: {metrics['logs_failed']}")
        print(f"Bytes Sent: {metrics['bytes_sent']} bytes")
        print(f"Bytes Saved by Compression: {metrics['bytes_saved_by_compression']} bytes")
        print(f"Average Latency: {metrics['average_latency_ms']:.2f} ms")
        print(f"Connection Attempts: {metrics['connection_attempts']}")
        print(f"Connection Failures: {metrics['connection_failures']}")
        print(f"Heartbeats Sent: {metrics['heartbeats_sent']}")
        print(f"Heartbeats Failed: {metrics['heartbeats_failed']}")
        print(f"Buffer Utilization: {metrics['buffer_utilization']*100:.1f}% ({metrics['buffer_size']}/{metrics['buffer_capacity']})")
        print("===========================\n")
    
    def close(self) -> None:
        """Close connection and stop heartbeat thread."""
        self.running = False
        
        # Print final metrics
        self.print_metrics()
        
        # Call parent close method
        super().close()