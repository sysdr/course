import socket
import threading
import logging
from .handler import LogHandler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class LogTCPServer:
    def __init__(self, host='0.0.0.0', port=9000, buffer_size=1024):
        """Initialize a TCP server for receiving logs.
        
        Args:
            host (str): The host address to bind to
            port (int): The port to listen on
            buffer_size (int): Size of the receive buffer
        """
        self.host = host
        self.port = port
        self.buffer_size = buffer_size
        self.socket = None
        self.running = False
        self.handlers = []
        
    def start(self):
        """Start the TCP server and begin accepting connections."""
        # Create a TCP/IP socket
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        
        # Allow reuse of the address
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        
        # Bind the socket to the address
        self.socket.bind((self.host, self.port))
        
        # Listen for incoming connections (5 is the max backlog of connections)
        self.socket.listen(5)
        
        self.running = True
        logger.info(f"Server started on {self.host}:{self.port}")
        
        try:
            self._accept_connections()
        except KeyboardInterrupt:
            logger.info("Server stopping due to keyboard interrupt")
        finally:
            self.stop()
            
    def _accept_connections(self):
        """Accept incoming connections and handle them."""
        while self.running:
            try:
                # Wait for a connection
                client_socket, client_address = self.socket.accept()
                logger.info(f"New connection from {client_address}")
                
                # Create a handler for this connection
                handler = LogHandler(client_socket, client_address)
                self.handlers.append(handler)
                
                # Start the handler in a new thread
                handler_thread = threading.Thread(target=handler.handle)
                handler_thread.daemon = True
                handler_thread.start()
                
            except Exception as e:
                if self.running:  # Only log if we're still supposed to be running
                    logger.error(f"Error accepting connection: {e}")
    
    def stop(self):
        """Stop the server and close all connections."""
        self.running = False
        
        # Close all client handlers
        for handler in self.handlers:
            handler.stop()
        
        # Close the server socket
        if self.socket:
            self.socket.close()
            self.socket = None
            
        logger.info("Server stopped")

if __name__ == "__main__":
    # Create and start the server
    server = LogTCPServer()
    try:
        server.start()
    except KeyboardInterrupt:
        pass