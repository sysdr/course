import socket
import time
import json
import os
from collections import deque
from typing import Optional, List, Dict
from src.log_reader import LogReader

class ResilientLogShipper:
    """A more resilient log shipping client with buffering and persistence."""
    
    def __init__(self, server_host: str, server_port: int, 
                 log_reader: LogReader, buffer_size: int = 1000,
                 persistence_file: Optional[str] = "undelivered_logs.json",
                 max_retries: int = 5):
        """Initialize the resilient log shipper.
        
        Args:
            server_host: Hostname or IP of the TCP log server
            server_port: Port the TCP log server is listening on
            log_reader: LogReader instance to read logs from
            buffer_size: Maximum number of logs to keep in memory buffer
            persistence_file: File to store undelivered logs between restarts
            max_retries: Maximum number of connection retry attempts
        """
        self.server_host = server_host
        self.server_port = server_port
        self.log_reader = log_reader
        self.buffer_size = buffer_size
        self.persistence_file = persistence_file
        self.max_retries = max_retries
        self.socket = None
        
        # In-memory buffer for logs
        self.buffer = deque(maxlen=buffer_size)
        
        # Load any persisted logs
        self._load_persisted_logs()
    
    def _load_persisted_logs(self) -> None:
        """Load any logs that weren't delivered in previous runs."""
        if not self.persistence_file or not os.path.exists(self.persistence_file):
            return
            
        try:
            with open(self.persistence_file, 'r') as f:
                persisted_logs = json.load(f)
                
                # Add persisted logs to the buffer
                for log in persisted_logs:
                    self.buffer.append(log)
                    
            print(f"Loaded {len(persisted_logs)} persisted logs")
            
            # Clear the persistence file since we've loaded the logs
            os.unlink(self.persistence_file)
        except (json.JSONDecodeError, IOError) as e:
            print(f"Error loading persisted logs: {e}")
    
    def _persist_undelivered_logs(self) -> None:
        """Save any undelivered logs to disk."""
        if not self.persistence_file or not self.buffer:
            return
            
        try:
            with open(self.persistence_file, 'w') as f:
                json.dump(list(self.buffer), f)
                
            print(f"Persisted {len(self.buffer)} undelivered logs")
        except IOError as e:
            print(f"Error persisting logs: {e}")
    
    def connect(self) -> bool:
        """Establish connection to the TCP server with exponential backoff.
        
        Returns:
            True if connection successful, False otherwise
        """
        retries = 0
        
        while retries < self.max_retries:
            try:
                self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                self.socket.connect((self.server_host, self.server_port))
                print(f"Connected to {self.server_host}:{self.server_port}")
                return True
            except (socket.error, ConnectionRefusedError) as e:
                print(f"Connection failed (attempt {retries+1}/{self.max_retries}): {e}")
                retries += 1
                
                # Exponential backoff: wait longer between each retry
                backoff_time = min(60, 2 ** retries)  # Cap at 60 seconds
                print(f"Retrying in {backoff_time} seconds...")
                time.sleep(backoff_time)
                
        print("Failed to connect after maximum retry attempts")
        return False
    
    def _process_buffer(self) -> int:
        """Attempt to send any logs in the buffer.
        
        Returns:
            Number of logs successfully sent
        """
        if not self.buffer:
            return 0
            
        if not self.socket and not self.connect():
            return 0
            
        logs_sent = 0
        buffer_size = len(self.buffer)
        
        for _ in range(buffer_size):
            try:
                log = self.buffer.popleft()  # Get the oldest log
                
                # Ensure log ends with newline
                if not log.endswith('\n'):
                    log += '\n'
                    
                self.socket.sendall(log.encode('utf-8'))
                logs_sent += 1
            except socket.error as e:
                print(f"Error shipping log from buffer: {e}")
                
                # Put the log back in the buffer
                self.buffer.appendleft(log)
                
                # Try to reconnect
                if not self.connect():
                    # If reconnection fails, stop processing the buffer
                    break
        
        return logs_sent
    
    def ship_logs_batch(self, logs: Optional[List[str]] = None) -> int:
        """Ship a batch of logs to the server, with buffering for resilience.
        
        Args:
            logs: List of log strings to ship. If None, reads from the log_reader.
            
        Returns:
            Number of logs successfully shipped
        """
        # First, try to send any buffered logs
        buffer_sent = self._process_buffer()
        
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
            
        logs_shipped = buffer_sent
        
        for log in logs:
            try:
                # Ensure log ends with newline
                if not log.endswith('\n'):
                    log += '\n'
                    
                self.socket.sendall(log.encode('utf-8'))
                logs_shipped += 1
            except socket.error as e:
                print(f"Error shipping log: {e}")
                
                # Buffer the log for later retry
                self.buffer.append(log)
                
                # Try to reconnect
                if not self.connect():
                    # If reconnection fails, buffer remaining logs
                    self.buffer.extend(logs[logs.index(log)+1:])
                    break
        
        return logs_shipped
    
    def ship_logs_continuously(self) -> None:
        """Continuously ship logs as they're generated, with resilience.
        
        This method blocks indefinitely, shipping logs as they appear.
        """
        # First, process any buffered logs
        self._process_buffer()
        
        # Ensure initial connection
        if not self.socket and not self.connect():
            print("Could not establish initial connection, will retry")
        
        try:
            for log in self.log_reader.read_incremental():
                # Try to process any buffered logs first
                self._process_buffer()
                
                try:
                    if self.socket:
                        # Try to send the new log directly
                        if not log.endswith('\n'):
                            log += '\n'
                            
                        self.socket.sendall(log.encode('utf-8'))
                    else:
                        # No connection, buffer the log
                        self.buffer.append(log)
                        
                        # Try to reconnect
                        self.connect()
                except socket.error as e:
                    print(f"Error shipping log: {e}")
                    
                    # Buffer the log for later
                    self.buffer.append(log)
                    
                    # Try to reconnect
                    self.connect()
        except KeyboardInterrupt:
            print("\nStopping log shipping")
        finally:
            self.close()
    
    def close(self) -> None:
        """Close connection to the server and persist any undelivered logs."""
        # Try to send any remaining buffered logs
        if self.buffer:
            print(f"Attempting to send {len(self.buffer)} buffered logs before shutdown")
            self._process_buffer()
        
        # Persist any logs that couldn't be delivered
        self._persist_undelivered_logs()
        
        # Close the socket
        if self.socket:
            try:
                self.socket.close()
                print("Connection closed")
            except socket.error as e:
                print(f"Error closing connection: {e}")
            finally:
                self.socket = None