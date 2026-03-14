import pytest
from unittest.mock import MagicMock, patch
from src.enhanced_shipper import EnhancedLogShipper
from src.log_reader import LogReader

class TestEnhancedShipper:
    
    def test_metrics_initialization(self):
        # Create enhanced shipper
        log_reader = MagicMock(spec=LogReader)
        shipper = EnhancedLogShipper('localhost', 9000, log_reader, heartbeat_interval=0)
        
        # Check initial metrics
        metrics = shipper.get_metrics()
        assert metrics["logs_sent"] == 0
        assert metrics["logs_failed"] == 0
        assert metrics["bytes_sent"] == 0
        
        shipper.close()
    
    @patch('socket.socket')
    def test_batch_sending(self, mock_socket):
        # Mock socket
        mock_socket_instance = MagicMock()
        mock_socket.return_value = mock_socket_instance
        
        # Create enhanced shipper with small batch size
        log_reader = MagicMock(spec=LogReader)
        shipper = EnhancedLogShipper('localhost', 9000, log_reader, 
                                    batch_size=2, compress_logs=False,
                                    heartbeat_interval=0)
        
        # Ship logs in batches
        logs_shipped = shipper.ship_logs_batch(["Log 1", "Log 2", "Log 3", "Log 4"])
        
        # Check that logs were shipped
        assert logs_shipped == 4
        
        # Check metrics
        metrics = shipper.get_metrics()
        assert metrics["logs_sent"] == 4
        
        shipper.close()
    
    def test_compression(self):
        # Create enhanced shipper
        log_reader = MagicMock(spec=LogReader)
        shipper = EnhancedLogShipper('localhost', 9000, log_reader, 
                                    compress_logs=True, heartbeat_interval=0)
        
        # Test compression
        test_logs = ["Test log 1\n", "Test log 2\n", "Test log 3\n"]
        compressed_data = shipper._compress_logs(test_logs)
        
        # Compressed data should be smaller than original (for this test data)
        original_size = sum(len(log.encode('utf-8')) for log in test_logs)
        assert len(compressed_data) < original_size
        
        shipper.close()
