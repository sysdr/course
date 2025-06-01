import json
import socket
import threading
import logging

# Import from local module
try:
    from compression import CompressionHandler
except ImportError:
    from src.compression import CompressionHandler

class LogReceiver:
    def __init__(self, host='0.0.0.0', port=5000):
        self.host = host
        self.port = port
        self.running = False
        self.server_socket = None
        self.logs_received = 0
        self.bytes_received = 0
        self.bytes_decompressed = 0
        
        # Initialize decompressors for both algorithms
        self.decompressors = {
            'gzip': CompressionHandler(algorithm='gzip'),
            'zlib': CompressionHandler(algorithm='zlib')
        }
        
    def start(self):
        """Start the log receiver server."""
        self.running = True
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((self.host, self.port))
        self.server_socket.listen(5)
        
        logging.info(f"Log receiver started on {self.host}:{self.port}")
        
        # Start accepting connections in a separate thread
        self.accept_thread = threading.Thread(target=self._accept_connections)
        self.accept_thread.daemon = True
        self.accept_thread.start()
        
    def _accept_connections(self):
        """Accept incoming connections."""
        while self.running:
            try:
                client_socket, address = self.server_socket.accept()
                client_thread = threading.Thread(
                    target=self._handle_client,
                    args=(client_socket, address)
                )
                client_thread.daemon = True
                client_thread.start()
            except Exception as e:
                if self.running:
                    logging.error(f"Error accepting connection: {str(e)}")
        
    def _handle_client(self, client_socket, address):
        """Handle an individual client connection."""
        try:
            # Read header length (4 bytes)
            header_length_bytes = client_socket.recv(4)
            if not header_length_bytes:
                return
                
            header_length = int.from_bytes(header_length_bytes, byteorder='big')
            
            # Read header
            header_data = b''
            bytes_remaining = header_length
            while bytes_remaining > 0:
                chunk = client_socket.recv(min(bytes_remaining, 4096))
                if not chunk:
                    break
                header_data += chunk
                bytes_remaining -= len(chunk)
                
            if len(header_data) != header_length:
                logging.error(f"Incomplete header received from {address}")
                return
                
            header = json.loads(header_data.decode('utf-8'))
            
            # Read log data
            log_data = b''
            while True:
                chunk = client_socket.recv(4096)
                if not chunk:
                    break
                log_data += chunk
                
            self.bytes_received += len(log_data)
            
            # Decompress if needed
            if header.get('compressed', False):
                algorithm = header.get('algorithm', 'gzip')
                if algorithm in self.decompressors:
                    decompressor = self.decompressors[algorithm]
                    log_data = decompressor.decompress(log_data)
                    self.bytes_decompressed += header.get('original_size', len(log_data))
                else:
                    logging.error(f"Unsupported compression algorithm: {algorithm}")
            
            # Parse the JSON data
            log_entries = json.loads(log_data.decode('utf-8'))
            self.logs_received += len(log_entries)
            
            # Process log entries (store, forward, etc.)
            self._process_logs(log_entries)
            
        except Exception as e:
            logging.error(f"Error handling client {address}: {str(e)}")
        finally:
            client_socket.close()
            
    def _process_logs(self, log_entries):
        """Process received log entries."""
        # In a real system, you would store these logs or forward them
        # For this example, we'll just log the count
        logging.info(f"Processed {len(log_entries)} log entries")
        
    def get_stats(self):
        """Get receiver statistics."""
        compression_ratio = 0
        if self.bytes_decompressed > 0:
            compression_ratio = self.bytes_decompressed / self.bytes_received
            
        return {
            'logs_received': self.logs_received,
            'bytes_received': self.bytes_received,
            'bytes_decompressed': self.bytes_decompressed,
            'compression_ratio': compression_ratio
        }
        
    def stop(self):
        """Stop the log receiver."""
        self.running = False
        if self.server_socket:
            self.server_socket.close()
        if self.accept_thread:
            self.accept_thread.join(timeout=5)
