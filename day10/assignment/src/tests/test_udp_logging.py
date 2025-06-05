"""
Test module for UDP log shipping system
"""

import unittest
import socket
import json
import threading
import time
import sys
import os

# Add the src directory to the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from server.udp_server import UDPLogServer
from client.udp_client import UDPLogClient


class TestUDPLogging(unittest.TestCase):
    """Test cases for UDP log shipping system."""
    
    @classmethod
    def setUpClass(cls):
        """Set up test environment - start server in a separate thread."""
        cls.server = UDPLogServer(host="127.0.0.1", port=9998)
        cls.server_thread = threading.Thread(target=cls.server.run)
        cls.server_thread.daemon = True
        cls.server_thread.start()
        # Give the server a moment to start up
        time.sleep(1)
        
    def setUp(self):
        """Set up each test case."""
        self.client = UDPLogClient(server_host="127.0.0.1", server_port=9998)
    
    def test_log_sending(self):
        """Test that logs can be sent and received."""
        initial_count = self.server.log_count
        
        # Send some test logs
        for i in range(5):
            success = self.client.send_log(f"Test message {i}", "INFO")
            self.assertTrue(success)
            
        # Wait a moment for logs to be processed
        time.sleep(0.5)
        
        # Check that logs were received
        self.assertEqual(self.server.log_count, initial_count + 5)
    
    def test_high_volume(self):
        """Test sending a higher volume of logs."""
        initial_count = self.server.log_count
        num_logs = 100
        
        # Send logs with minimal delay
        self.client.generate_sample_logs(count=num_logs, interval=0.0001)
        
        # Wait a moment for logs to be processed
        time.sleep(1)
        
        # Due to UDP's nature, we might not receive all logs, 
        # but we should receive most of them
        received = self.server.log_count - initial_count
        self.assertGreaterEqual(received, num_logs * 0.9)
        
    def tearDown(self):
        """Clean up after each test case."""
        if self.client:
            self.client.close()


# This allows us to run the tests from the command line
if __name__ == "__main__":
    unittest.main()