import os
import tempfile
import json
import pytest
from unittest.mock import MagicMock, patch
from src.resilient_shipper import ResilientLogShipper
from src.log_reader import LogReader

class TestResilientShipper:
    
    @patch('socket.socket')
    def test_persistence_saving(self, mock_socket):
        # Create temporary files
        with tempfile.NamedTemporaryFile(mode='w+', delete=False) as temp_log:
            temp_log.write("Test log 1\nTest log 2\n")
            log_path = temp_log.name
        
        persistence_file = tempfile.mktemp(suffix='.json')
        
        try:
            # Mock socket to always fail
            mock_socket_instance = MagicMock()
            mock_socket_instance.connect.side_effect = ConnectionRefusedError("Connection refused")
            mock_socket.return_value = mock_socket_instance
            
            # Create shipper
            log_reader = LogReader(log_path)
            shipper = ResilientLogShipper('localhost', 9000, log_reader, 
                                         persistence_file=persistence_file,
                                         max_retries=1)
            
            # Try to ship logs (will fail and buffer them)
            shipper.ship_logs_batch()
            
            # Close shipper (should persist logs)
            shipper.close()
            
            # Check persistence file was created
            assert os.path.exists(persistence_file)
            
            # Check persisted logs
            with open(persistence_file, 'r') as f:
                persisted_logs = json.load(f)
            
            assert len(persisted_logs) == 2
        finally:
            # Clean up
            os.unlink(log_path)
            if os.path.exists(persistence_file):
                os.unlink(persistence_file)
    
    @patch('socket.socket')
    def test_persistence_loading(self, mock_socket):
        # Create persistence file
        persistence_file = tempfile.mktemp(suffix='.json')
        persisted_logs = ["Persisted log 1\n", "Persisted log 2\n"]
        
        with open(persistence_file, 'w') as f:
            json.dump(persisted_logs, f)
        
        with tempfile.NamedTemporaryFile(mode='w+', delete=False) as temp_log:
            log_path = temp_log.name
        
        try:
            # Mock socket to succeed
            mock_socket_instance = MagicMock()
            mock_socket.return_value = mock_socket_instance
            
            # Create shipper (should load persisted logs)
            log_reader = LogReader(log_path)
            shipper = ResilientLogShipper('localhost', 9000, log_reader, 
                                         persistence_file=persistence_file,
                                         max_retries=1)
            
            # Ship logs (should send persisted logs)
            logs_shipped = shipper.ship_logs_batch()
            
            # Check that persisted logs were sent
            assert logs_shipped == 2
            assert mock_socket_instance.sendall.call_count == 2
            
            shipper.close()
        finally:
            # Clean up
            os.unlink(log_path)
            if os.path.exists(persistence_file):
                os.unlink(persistence_file)
