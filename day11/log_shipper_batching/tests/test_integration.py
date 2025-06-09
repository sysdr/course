# week2/day11/tests/test_integration.py
import unittest
import time
import threading
import json
import socket
import sys
import os

# Add the parent directory to sys.path to import our modules
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from log_shipper.batch_log_client import BatchLogClient
from log_server.udp_log_server import UDPLogServer

class MockUDPServer:
    def __init__(self, host='localhost', port=9999):
        self.host = host
        self.port = port
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((self.host, self.port))
        self.sock.settimeout(5.0)  # Set timeout for recvfrom
        self.received_batches = []
        self.running = False
        self.thread = None
    
    def start(self):
        self.running = True
        self.thread = threading.Thread(target=self._receive_loop)
        self.thread.daemon = True
        self.thread.start()
    
    def stop(self):
        self.running = False
        if self.thread:
            self.thread.join(timeout=1.0)
        self.sock.close()
    
    def _receive_loop(self):
        while self.running:
            try:
                data, _ = self.sock.recvfrom(65535)
                batch = json.loads(data.decode('utf-8'))
                self.received_batches.append(batch)
            except socket.timeout:
                continue
            except Exception as e:
                print(f"Error in mock server: {e}")
                break

class TestIntegration(unittest.TestCase):
    
    def setUp(self):
        # Use a high port number for testing
        self.test_port = 9876
        
        # Start a mock server
        self.server = MockUDPServer(port=self.test_port)
        self.server.start()
        
        # Create a client that points to our test server
        self.client = BatchLogClient(
            server_port=self.test_port,
            batch_size=5,
            batch_interval=1.0
        )
        self.client.start()
    
    def tearDown(self):
        # Stop the client and server
        self.client.stop()
        self.server.stop()
    
    def test_end_to_end_batch_size(self):
        """Test end-to-end batch sending triggered by batch size."""
        # Send exactly one batch worth of logs
        for i in range(5):
            self.client.send_log({"message": f"Integration test log {i}"})
        
        # Wait for processing
        time.sleep(0.5)
        
        # Check that the server received one batch
        self.assertEqual(len(self.server.received_batches), 1)
        
        # Check batch contents
        batch = self.server.received_batches[0]
        self.assertEqual(len(batch), 5)
        self.assertEqual(batch[0]["message"], "Integration test log 0")
        self.assertEqual(batch[4]["message"], "Integration test log 4")
    
    def test_end_to_end_interval(self):
        """Test end-to-end batch sending triggered by interval."""
        # Send less than a full batch
        for i in range(3):
            self.client.send_log({"message": f"Integration test log {i}"})
        
        # Wait for the interval to trigger sending
        time.sleep(1.5)
        
        # Check that the server received one batch
        self.assertEqual(len(self.server.received_batches), 1)
        
        # Check batch contents
        batch = self.server.received_batches[0]
        self.assertEqual(len(batch), 3)

if __name__ == '__main__':
    unittest.main()