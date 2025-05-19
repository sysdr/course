import logging
import json

# Configure logging
logger = logging.getLogger(__name__)

class LogHandler:
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
                
                # Process the received data
                self.process_data(data)
                
        except Exception as e:
            logger.error(f"Error handling connection from {self.client_address}: {e}")
        finally:
            self.stop()
    
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
                # Here we would typically forward the log to the next component
                # For now, we'll just log it
                logger.info(f"Parsed JSON log: {log_json}")
            except json.JSONDecodeError:
                # Not JSON, treat as plain text
                logger.info(f"Received plain text log: {log_data}")
                
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