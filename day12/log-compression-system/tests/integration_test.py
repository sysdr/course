import time
import threading
import unittest
import logging
import json
import random
import sys
import os

# Add the src directory to the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

try:
    from src.log_shipper import LogShipper
    from src.log_receiver import LogReceiver
except ImportError:
    from log_shipper import LogShipper
    from log_receiver import LogReceiver

class TestLogCompression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Configure logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        
        # Start the log receiver
        cls.receiver = LogReceiver(host='localhost', port=5000)
        cls.receiver.start()
        time.sleep(1)  # Give the receiver time to start
        
    @classmethod
    def tearDownClass(cls):
        # Stop the log receiver
        cls.receiver.stop()
        
    def generate_log_batch(self, count):
        """Generate a batch of test log entries."""
        logs = []
        for i in range(count):
            logs.append({
                'timestamp': time.time(),
                'level': random.choice(['INFO', 'WARN', 'ERROR']),
                'message': f"Test log message {i}",
                'data': 'x' * random.randint(50, 200)  # Add random padding to test compression
            })
        return logs
        
    def test_compression_disabled(self):
        # Create shipper with compression disabled
        shipper = LogShipper(
            server_host='localhost',
            server_port=5000,
            batch_size=50,
            batch_interval=1,
            compression_enabled=False
        )
        
        # Initial receiver stats
        initial_stats = self.receiver.get_stats()
        
        # Ship 100 logs
        logs = self.generate_log_batch(100)
        for log in logs:
            shipper.ship_log(log)
            
        # Wait for logs to be processed
        time.sleep(3)
        shipper.shutdown()
        
        # Check stats
        final_stats = self.receiver.get_stats()
        logs_received = final_stats['logs_received'] - initial_stats['logs_received']
        
        self.assertEqual(logs_received, 100)
        
    def test_compression_enabled(self):
        # Create shipper with compression enabled
        shipper = LogShipper(
            server_host='localhost',
            server_port=5000,
            batch_size=50,
            batch_interval=1,
            compression_enabled=True,
            compression_algorithm='gzip',
            compression_level=6
        )
        
        # Initial receiver stats
        initial_stats = self.receiver.get_stats()
        
        # Ship 100 logs
        logs = self.generate_log_batch(100)
        for log in logs:
            shipper.ship_log(log)
            
        # Wait for logs to be processed
        time.sleep(3)
        shipper.shutdown()
        
        # Check shipper stats
        shipper_stats = shipper.get_stats()
        self.assertGreater(shipper_stats['compression_ratio_avg'], 1.0)
        
        # Check receiver stats
        final_stats = self.receiver.get_stats()
        logs_received = final_stats['logs_received'] - initial_stats['logs_received']
        
        self.assertEqual(logs_received, 100)
        # Note: We can't reliably check compression_ratio on receiver side in this test
        # because other tests running concurrently could affect the ratio

if __name__ == '__main__':
    unittest.main()
