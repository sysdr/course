import unittest
import socket
import threading
import time
from src.server import LogTCPServer

class TestLogTCPServer(unittest.TestCase):
    def setUp(self):
        # Create a server instance with a random port
        self.server = LogTCPServer(port=0)  # Port 0 means OS will assign a free port
        
        # Start the server in a separate thread
        self.server_thread = threading.Thread(target=self.server.start)
        self.server_thread.daemon = True
        self.server_thread.start()
        
        # Wait for the server to start
        time.sleep(0.1)
        
        # Get the actual port the server is listening on
        self.port = self.server.socket.getsockname()[1]
    
    def tearDown(self):
        # Stop the server
        self.server.stop()
        
        # Wait for the server thread to finish
        self.server_thread.join(timeout=1.0)
    
    def test_server_accepts_connection(self):
        # Create a client socket
        client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        
        try:
            # Connect to the server
            client.connect(('localhost', self.port))
            
            # If we get here, the connection was successful
            self.assertTrue(True)
            
        finally:
            # Close the client socket
            client.close()
    
    def test_server_receives_data(self):
        # Create a client socket
        client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        
        try:
            # Connect to the server
            client.connect(('localhost', self.port))
            
            # Send some data
            test_data = "TEST LOG MESSAGE"
            client.sendall(test_data.encode('utf-8'))
            
            # Wait for a response
            response = client.recv(1024)
            
            # Check if we got the expected acknowledgment
            self.assertEqual(response.decode('utf-8').strip(), "ACK")
            
        finally:
            # Close the client socket
            client.close()

if __name__ == '__main__':
    unittest.main()