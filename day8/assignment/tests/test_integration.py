import unittest
import socket
import threading
import time
import json
from src.server import LogTCPServer

class TestIntegration(unittest.TestCase):
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
    
    def test_json_log_processing(self):
        # Create a client socket
        client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        
        try:
            # Connect to the server
            client.connect(('localhost', self.port))
            
            # Create a JSON log message
            log_data = {
                "timestamp": time.time(),
                "level": "INFO",
                "message": "Integration test log message",
                "source": "integration_test"
            }
            log_message = json.dumps(log_data)
            
            # Send the log message
            client.sendall(log_message.encode('utf-8'))
            
            # Wait for a response
            response = client.recv(1024)
            
            # Check if we got the expected acknowledgment
            self.assertEqual(response.decode('utf-8').strip(), "ACK")
            
        finally:
            # Close the client socket
            client.close()
    
    def test_multiple_clients(self):
        num_clients = 5
        client_threads = []
        
        def client_task(client_id):
            # Create a client socket
            client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            
            try:
                # Connect to the server
                client.connect(('localhost', self.port))
                
                # Create a log message
                log_message = f"Test from client {client_id}"
                
                # Send the log message
                client.sendall(log_message.encode('utf-8'))
                
                # Wait for a response
                response = client.recv(1024)
                
                # Check if we got the expected acknowledgment
                self.assertEqual(response.decode('utf-8').strip(), "ACK")
                
            finally:
                # Close the client socket
                client.close()
        
        # Create and start client threads
        for i in range(num_clients):
            thread = threading.Thread(target=client_task, args=(i,))
            thread.start()
            client_threads.append(thread)
        
        # Wait for all client threads to finish
        for thread in client_threads:
            thread.join(timeout=5.0)

if __name__ == '__main__':
    unittest.main()