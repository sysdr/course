# assignment/tests/test_enhanced_client.py
import unittest
import time
import threading
import socket
import json
import zlib
from unittest.mock import patch, MagicMock
import sys
import os

# Add the parent directory to sys.path to import our modules
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from enhanced_log_shipper.enhanced_batch_client import EnhancedBatchLogClient

class TestEnhancedBatchLogClient(unittest.TestCase):
    
    def setUp(self):
        # Create a client with test settings
        self.client = EnhancedBatchLogClient(
            batch_size=3,  # Small batch size for testing
            batch_interval=1.0,  # Small interval for faster testing
            enable_compression=True,
            retry_attempts=2
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
    
    def test_batch_compression(self):
        """Test that batches are compressed."""
        self.client.start()
        
        # Send logs with repeating data that compresses well
        for i in range(3):
            self.client.send_log({
                "message": "Test log",
                "data": "A" * 1000  # Easily compressible data
            })
        
        # Allow time for batch processing
        time.sleep(0.2)
        
        # Verify that sendto was called once
        self.client.sock.sendto.assert_called_once()
        
        # Check the content of what was sent
        args, _ = self.client.sock.sendto.call_args
        sent_data = args[0]
        
        # First byte should be 'C' for compressed
        self.assertEqual(sent_data[0:1], b'C')
        
        # Metrics should show compression savings
        metrics = self.client.get_metrics()
        self.assertGreater(metrics['avg_space_saving'], 0)
    
    def test_batch_splitting(self):
        """Test that large batches are split."""
        # Create a batch that will exceed the max UDP size
        large_batch = []
        for i in range(10):
            large_batch.append({
                "message": f"Test log {i}",
                "data": "X" * 10000  # Large data that will make the batch exceed UDP limits
            })
        
        # Set a small max UDP size to force splitting
        self.client.max_udp_size = 30000
        
        # Use the internal _split_batch method to test splitting
        sub_batches = self.client._split_batch(large_batch)
        
        # Verify that the batch was split
        self.assertGreater(len(sub_batches), 1)
        
        # Verify that each sub-batch is smaller than our original
        self.assertLess(len(sub_batches[0]), len(large_batch))
    
    def test_retry_mechanism(self):
        """Test that send retries on failure."""
        self.client.start()
        
        # Configure the mock to fail the first time, succeed the second time
        self.client.sock.sendto.side_effect = [
            socket.error("Simulated network error"),
            None  # Success on second attempt
        ]
        
        # Send a batch
        for i in range(3):
            self.client.send_log({"message": f"Test log {i}"})
        
        # Allow time for batch processing and retries
        time.sleep(1.5)
        
        # Verify that sendto was called twice (initial + retry)
        self.assertEqual(self.client.sock.sendto.call_count, 2)
        
        # Check metrics
        metrics = self.client.get_metrics()
        self.assertEqual(metrics['total_retries'], 1)
        self.assertEqual(metrics['total_failures'], 0)
    
    def test_dynamic_configuration(self):
        """Test that configuration can be updated at runtime."""
        # Initial configuration
        self.assertEqual(self.client.batch_size, 3)
        self.assertEqual(self.client.batch_interval, 1.0)
        
        # Update configuration
        self.client.batch_size = 5
        self.client.batch_interval = 2.0
        
        # Verify the updates
        self.assertEqual(self.client.batch_size, 5)
        self.assertEqual(self.client.batch_interval, 2.0)
        
        # Test validation
        with self.assertRaises(ValueError):
            self.client.batch_size = 0
            
        with self.assertRaises(ValueError):
            self.client.batch_interval = -1.0

if __name__ == '__main__':
    unittest.main()