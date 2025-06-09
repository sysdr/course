# week2/day11/tests/test_batch_log_client.py
import unittest
import time
import threading
import socket
import json
from unittest.mock import patch, MagicMock
import sys
import os

# Add the parent directory to sys.path to import our modules
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from log_shipper.batch_log_client import BatchLogClient

class TestBatchLogClient(unittest.TestCase):
    
    def setUp(self):
        # Create a client with test settings
        self.client = BatchLogClient(
            batch_size=3,  # Small batch size for testing
            batch_interval=1.0  # Small interval for faster testing
        )
        
        # Mock the socket to prevent actual network calls
        self.socket_patcher = patch('socket.socket')
        self.mock_socket = self.socket_patcher.start()
        self.client.sock = self.mock_socket.return_value
    
    def tearDown(self):
        # Stop the client if it's running
        if self.client.running:
            self.client.stop()
        
        # Stop the socket patcher
        self.socket_patcher.stop()
    
    def test_batch_size_trigger(self):
        """Test that batches are sent when the batch size is reached."""
        self.client.start()
        
        # Send three logs (matching our batch size)
        for i in range(3):
            self.client.send_log({"message": f"Test log {i}"})
        
        # Allow time for batch processing
        time.sleep(0.2)
        
        # Verify that sendto was called once with the batch
        self.client.sock.sendto.assert_called_once()
        
        # Check the content of what was sent
        args, _ = self.client.sock.sendto.call_args
        sent_data = json.loads(args[0].decode('utf-8'))
        self.assertEqual(len(sent_data), 3)
        self.assertEqual(sent_data[0]["message"], "Test log 0")
        self.assertEqual(sent_data[2]["message"], "Test log 2")
    
    def test_batch_interval_trigger(self):
        """Test that batches are sent when the interval expires."""
        self.client.start()
        
        # Send only two logs (less than batch size)
        for i in range(2):
            self.client.send_log({"message": f"Test log {i}"})
        
        # Wait for the interval to expire
        time.sleep(1.2)
        
        # Verify that sendto was called once with the partial batch
        self.client.sock.sendto.assert_called_once()
        
        # Check the content
        args, _ = self.client.sock.sendto.call_args
        sent_data = json.loads(args[0].decode('utf-8'))
        self.assertEqual(len(sent_data), 2)
    
    def test_flush(self):
        """Test that flush immediately sends the current batch."""
        self.client.start()
        
        # Send one log
        self.client.send_log({"message": "Test log"})
        
        # Allow time for processing
        time.sleep(0.1)
        
        # Call flush
        self.client.flush()
        
        # Verify that sendto was called once
        self.client.sock.sendto.assert_called_once()
        
        # Check the content
        args, _ = self.client.sock.sendto.call_args
        sent_data = json.loads(args[0].decode('utf-8'))
        self.assertEqual(len(sent_data), 1)
    
    def test_stop_flushes_remaining_logs(self):
        """Test that stopping the client flushes remaining logs."""
        self.client.start()
        
        # Send one log
        self.client.send_log({"message": "Test log"})
        
        # Allow time for processing
        time.sleep(0.1)
        
        # Stop the client (should flush)
        self.client.stop()
        
        # Verify that sendto was called once
        self.client.sock.sendto.assert_called_once()

if __name__ == '__main__':
    unittest.main()