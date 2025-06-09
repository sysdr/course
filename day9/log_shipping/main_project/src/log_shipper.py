import socket
import time
from typing import Optional, List
from src.log_reader import LogReader

class LogShipper:
    """Client that ships logs to a remote TCP server."""
    
    def __init__(self, server_host: str, server_port: int, 
                 log_reader: LogReader, max_retries: int = 3):
        """Initialize the log shipper.
        
        Args:
            server_host: Hostname or IP of the TCP log server
            server_port: Port the TCP log server is listening on
            log_reader: LogReader instance to read logs from
            max_retries: Maximum number of connection retry attempts
        """
        self.server_host = server_host
        self.server_port = server_port
        self.log_reader = log_reader
        self.max_retries = max_retries
        self.socket = None
    
    def connect(self) -> bool:
        """Establish connection to the TCP server.
        
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
                time.sleep(2 ** retries)
                
        print("Failed to connect after maximum retry attempts")
        return False
    
    def ship_logs_batch(self, logs: Optional[List[str]] = None) -> int:
        """Ship a batch of logs to the server.
        
        Args:
            logs: List of log strings to ship. If None, reads from the log_reader.
            
        Returns:
            Number of logs successfully shipped
        """
        if logs is None:
            logs = self.log_reader.read_batch()
        
        if not logs:
            return 0
            
        if not self.socket and not self.connect():
            return 0
            
        logs_shipped = 0
        for log in logs:
            try:
                # Ensure log ends with newline
                if not log.endswith('\n'):
                    log += '\n'
                self.socket.sendall(log.encode('utf-8'))
                logs_shipped += 1
            except socket.error as e:
                print(f"Error shipping log: {e}")
                # Try to reconnect
                if self.connect():
                    # Retry the current log
                    try:
                        self.socket.sendall(log.encode('utf-8'))
                        logs_shipped += 1
                    except socket.error:
                        # Give up on this log if we still can't send it
                        pass
                
        return logs_shipped
    
    def ship_logs_continuously(self) -> None:
        """Continuously ship logs as they're generated.
        
        This method blocks indefinitely, shipping logs as they appear.
        """
        if not self.connect():
            print("Could not establish initial connection, aborting")
            return
            
        for log in self.log_reader.read_incremental():
            retry_count = 0
            sent = False
            
            while not sent and retry_count < self.max_retries:
                try:
                    if not log.endswith('\n'):
                        log += '\n'
                    self.socket.sendall(log.encode('utf-8'))
                    sent = True
                except socket.error as e:
                    print(f"Error shipping log: {e}")
                    retry_count += 1
                    
                    # Try to reconnect
                    if self.connect():
                        continue
                    else:
                        # Wait before retrying
                        time.sleep(2 ** retry_count)
    
    def close(self) -> None:
        """Close connection to the server."""
        if self.socket:
            try:
                self.socket.close()
                print("Connection closed")
            except socket.error as e:
                print(f"Error closing connection: {e}")
            finally:
                self.socket = None