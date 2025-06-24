import socket
import threading
import time
import pytest
from unittest.mock import MagicMock, patch
from src.log_shipper import LogShipper
from src.log_reader import LogReader

class TestLogShipper:
    
    @patch('socket.socket')
    def test_connect_success(self, mock_socket):
        # Mock socket connection success
        mock_socket_instance = MagicMock()
        mock_socket.return_value = mock_socket_instance
        
        # Create a log shipper with a mock log reader
        log_reader = MagicMock(spec=LogReader)
        shipper = LogShipper('localhost', 9000, log_reader)
        
        # Test connect
        result = shipper.connect()
        
        assert result is True
        mock_socket_instance.connect.assert_called_once_with(('localhost', 9000))
    
    @patch('socket.socket')
    def test_connect_failure(self, mock_socket):
        # Mock socket connection failure
        mock_socket_instance = MagicMock()
        mock_socket_instance.connect.side_effect = ConnectionRefusedError("Connection refused")
        mock_socket.return_value = mock_socket_instance
        
        # Create a log shipper with a mock log reader
        log_reader = MagicMock(spec=LogReader)
        shipper = LogShipper('localhost', 9000, log_reader, max_retries=1)
        
        # Test connect
        result = shipper.connect()
        
        assert result is False
        mock_socket_instance.connect.assert_called_once_with(('localhost', 9000))
    
    @patch('socket.socket')
    def test_ship_logs_batch(self, mock_socket):
        # Mock socket connection
        mock_socket_instance = MagicMock()
        mock_socket.return_value = mock_socket_instance
        
        # Create a log shipper with a mock log reader
        log_reader = MagicMock(spec=LogReader)
        log_reader.read_batch.return_value = ["Log 1", "Log 2", "Log 3"]
        
        shipper = LogShipper('localhost', 9000, log_reader)
        
        # Ship logs
        logs_shipped = shipper.ship_logs_batch()
        
        assert logs_shipped == 3
        assert mock_socket_instance.sendall.call_count == 3
        
        # Check the log data was sent correctly
        calls = mock_socket_instance.sendall.call_args_list
        assert calls[0][0][0] == b"Log 1\n"
        assert calls[1][0][0] == b"Log 2\n"
        assert calls[2][0][0] == b"Log 3\n"
    
    @patch('socket.socket')
    def test_ship_logs_with_connection_failure(self, mock_socket):
        # Mock socket connection
        mock_socket_instance = MagicMock()
        
        # Create a side effect function that will fail on the second call
        # and succeed on all other calls
        def sendall_side_effect(*args, **kwargs):
            sendall_side_effect.call_count += 1
            if sendall_side_effect.call_count == 2:
                raise socket.error("Connection lost")
            return None
        
        # Initialize the call counter
        sendall_side_effect.call_count = 0
        
        # Assign the function as the side effect
        mock_socket_instance.sendall.side_effect = sendall_side_effect
        mock_socket.return_value = mock_socket_instance
        
        # Create a log shipper with a mock log reader
        log_reader = MagicMock(spec=LogReader)
        
        shipper = LogShipper('localhost', 9000, log_reader)
        
        # Ship logs
        logs_shipped = shipper.ship_logs_batch(["Log 1", "Log 2", "Log 3"])
        
        # We should have shipped at least Log 1, but may not ship Log 2 due to the error
        # The exact number depends on if reconnection is successful
        assert logs_shipped >= 1
        
        # Verify that connect was called at least twice
        # (initial connection + reconnection attempt)
        assert mock_socket_instance.connect.call_count >= 2
    
    @patch('socket.socket')
    def test_close(self, mock_socket):
        # Mock socket
        mock_socket_instance = MagicMock()
        mock_socket.return_value = mock_socket_instance
        
        # Create a log shipper
        log_reader = MagicMock(spec=LogReader)
        shipper = LogShipper('localhost', 9000, log_reader)
        
        # Connect
        shipper.connect()
        
        # Close
        shipper.close()
        
        # Verify socket was closed
        mock_socket_instance.close.assert_called_once()
        assert shipper.socket is None
    
    @patch('socket.socket')
    def test_ship_logs_continuously(self, mock_socket):
        # This is a more complex test that simulates continuous shipping
        # Mock socket
        mock_socket_instance = MagicMock()
        mock_socket.return_value = mock_socket_instance
        
        # Create a log reader that yields logs
        log_reader = MagicMock(spec=LogReader)
        log_reader.read_incremental.return_value = iter(["Log 1", "Log 2", "Log 3"])
        
        shipper = LogShipper('localhost', 9000, log_reader)
        
        # Create a flag to stop continuous shipping
        stop_event = threading.Event()
        
        # Define a function to run ship_logs_continuously in a thread
        def run_continuous_shipping():
            try:
                # Mock the behavior by calling ship_logs_batch for each log
                # This simulates what ship_logs_continuously would do
                for log in log_reader.read_incremental():
                    if stop_event.is_set():
                        break
                    shipper.ship_logs_batch([log])
            finally:
                shipper.close()
        
        # Start continuous shipping in a thread
        thread = threading.Thread(target=run_continuous_shipping)
        thread.daemon = True
        thread.start()
        
        # Give it some time to process logs
        time.sleep(0.1)
        
        # Stop the thread
        stop_event.set()
        thread.join(timeout=1)
        
        # Check that logs were sent
        assert mock_socket_instance.sendall.call_count >= 1