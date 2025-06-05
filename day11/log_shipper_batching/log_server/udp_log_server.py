# week2/day11/log_server/udp_log_server.py
import socket
import json
import time
import logging

class UDPLogServer:
    def __init__(self, host='0.0.0.0', port=9999):
        """Initialize a UDP server for receiving batched logs.
        
        Args:
            host (str): Host address to bind the server to
            port (int): Port number to listen on
        """
        self.host = host
        self.port = port
        self.sock = None
        self.running = False
        
        # Configure logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger("UDPLogServer")
        
    def start(self):
        """Start the UDP server."""
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((self.host, self.port))
        self.running = True
        
        self.logger.info(f"UDP Log Server started on {self.host}:{self.port}")
        
        try:
            while self.running:
                data, addr = self.sock.recvfrom(65535)  # UDP packet size limit
                self.process_batch(data, addr)
        except KeyboardInterrupt:
            self.logger.info("Server shutdown requested")
        finally:
            self.stop()
    
    def process_batch(self, data, addr):
        """Process a received batch of logs.
        
        Args:
            data (bytes): The batch data received
            addr (tuple): The address of the sender (host, port)
        """
        try:
            batch = json.loads(data.decode('utf-8'))
            log_count = len(batch)
            self.logger.info(f"Received batch of {log_count} logs from {addr}")
            
            # Process each log in the batch
            for log in batch:
                self.logger.info(f"Processing log: {log}")
                
        except json.JSONDecodeError:
            self.logger.error(f"Failed to decode JSON from {addr}: {data}")
        except Exception as e:
            self.logger.error(f"Error processing batch from {addr}: {e}")
    
    def stop(self):
        """Stop the UDP server."""
        self.running = False
        if self.sock:
            self.sock.close()
            self.sock = None
        self.logger.info("UDP Log Server stopped")

if __name__ == "__main__":
    server = UDPLogServer()
    server.start()