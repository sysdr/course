import logging
import json
import time
import os
from datetime import datetime
from .config import (
    LOG_LEVELS, MIN_LOG_LEVEL, LOG_FILE_PATH, ENABLE_LOG_PERSISTENCE,
    RATE_LIMIT_ENABLED, RATE_LIMIT_WINDOW, RATE_LIMIT_MAX_REQUESTS
)

# Configure logging
logger = logging.getLogger(__name__)

# Create logs directory if it doesn't exist
os.makedirs(os.path.dirname(LOG_FILE_PATH), exist_ok=True)

class LogHandler:
    # Class-level rate limiting
    request_times = []
    
    def __init__(self, client_socket, client_address):
        """Initialize a handler for a client connection.
        
        Args:
            client_socket: The socket for this client connection
            client_address: The address of the connected client
        """
        self.client_socket = client_socket
        self.client_address = client_address
        self.running = False
        self.buffer_size = 1024
    
    def handle(self):
        """Handle the client connection by receiving and processing log data."""
        self.running = True
        
        try:
            while self.running:
                # Receive data from the client
                data = self.client_socket.recv(self.buffer_size)
                
                # If no data is received, the client has closed the connection
                if not data:
                    logger.info(f"Connection closed by {self.client_address}")
                    break
                
                # Check rate limit
                if not self._check_rate_limit():
                    # Send rate limit exceeded message
                    self.client_socket.sendall(b"RATE_LIMIT_EXCEEDED\n")
                    continue
                
                # Process the received data
                self.process_data(data)
                
        except Exception as e:
            logger.error(f"Error handling connection from {self.client_address}: {e}")
        finally:
            self.stop()
    
    def _check_rate_limit(self):
        """Check if the rate limit has been exceeded.
        
        Returns:
            bool: True if the request is allowed, False if it exceeds the rate limit
        """
        if not RATE_LIMIT_ENABLED:
            return True
            
        current_time = time.time()
        
        # Add current request time
        LogHandler.request_times.append(current_time)
        
        # Remove old requests outside the window
        LogHandler.request_times = [t for t in LogHandler.request_times 
                                   if current_time - t <= RATE_LIMIT_WINDOW]
        
        # Check if we've exceeded the limit
        return len(LogHandler.request_times) <= RATE_LIMIT_MAX_REQUESTS
    
    def _should_process_log(self, log_level):
        """Determine if a log should be processed based on its level.
        
        Args:
            log_level (str): The log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
            
        Returns:
            bool: True if the log should be processed, False otherwise
        """
        # Default to processing if level is unknown
        if log_level not in LOG_LEVELS:
            return True
            
        # Process if log level is >= minimum level
        return LOG_LEVELS.get(log_level, 0) >= LOG_LEVELS.get(MIN_LOG_LEVEL, 0)
    
    def _persist_log(self, log_data):
        """Save the log to a file.
        
        Args:
            log_data (str): The log data to save
        """
        if not ENABLE_LOG_PERSISTENCE:
            return
            
        try:
            with open(LOG_FILE_PATH, 'a') as log_file:
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')
                log_file.write(f"[{timestamp}] {log_data}\n")
        except Exception as e:
            logger.error(f"Error persisting log: {e}")
    
    def process_data(self, data):
        """Process the received log data.
        
        Args:
            data (bytes): The received log data
        """
        try:
            # Decode the bytes to a string
            log_data = data.decode('utf-8').strip()
            logger.info(f"Received log: {log_data}")
            
            # Try to parse as JSON
            try:
                log_json = json.loads(log_data)
                
                # Check if we should process this log based on level
                log_level = log_json.get('level', 'INFO').upper()
                if not self._should_process_log(log_level):
                    logger.debug(f"Filtered out log with level {log_level}")
                    self.client_socket.sendall(b"FILTERED\n")
                    return
                
                # Persist the log
                self._persist_log(json.dumps(log_json))
                
                # Here we would typically forward the log to the next component
                logger.info(f"Processed JSON log: {log_json}")
                
            except json.JSONDecodeError:
                # Not JSON, treat as plain text
                logger.info(f"Received plain text log: {log_data}")
                self._persist_log(log_data)
                
            # Send acknowledgment
            self.client_socket.sendall(b"ACK\n")
            
        except Exception as e:
            logger.error(f"Error processing data: {e}")
    
    def stop(self):
        """Close the client connection."""
        self.running = False
        if self.client_socket:
            try:
                self.client_socket.close()
            except Exception as e:
                logger.error(f"Error closing client socket: {e}")