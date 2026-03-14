import os
import socket
import threading
import time
import tempfile
import pytest
from src.log_reader import LogReader
from src.log_shipper import LogShipper

class MockLogServer:
    """A simple mock TCP server to receive logs."""
    
    def __init__(self, host='localhost', port=9001):
        self.host = host
        self.port = port
        self.server_socket = None
        self.received_logs = []
        self.running = False
        self.thread = None
    
    def start(self):
        """Start the mock server in a new thread."""
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((self.host, self.port))
        self.server_socket.listen(1)
        self.server_socket.settimeout(1)  # 1 second timeout for accepting connections
        
        self.running = True
        self.thread = threading.Thread(target=self._run_server)
        self.thread.daemon = True
        self.thread.start()
    
    def _run_server(self):
        """Accept connections and receive logs."""
        while self.running:
            try:
                client_socket, _ = self.server_socket.accept()
                client_socket.settimeout(1)
                
                while self.running:
                    try:
                        data = client_socket.recv(4096)
                        if not data:
                            break
                        self.received_logs.append(data.decode('utf-8'))
                    except socket.timeout:
                        continue
                    except Exception:
                        break
                
                client_socket.close()
            except socket.timeout:
                continue
            except Exception:
                break
    
    def stop(self):
        """Stop the server."""
        self.running = False
        if self.thread:
            self.thread.join(timeout=2)
        if self.server_socket:
            self.server_socket.close()

class TestIntegration:
    
    @pytest.fixture
    def mock_server(self):
        """Fixture to create and manage a mock log server."""
        server = MockLogServer(port=9001)
        server.start()
        yield server
        server.stop()
    
    def test_log_shipping_integration(self, mock_server):
        # Create a temporary log file
        with tempfile.NamedTemporaryFile(mode='w+', delete=False) as temp:
            temp.write("Integration test log 1\n")
            temp.write("Integration test log 2\n")
            temp_path = temp.name
        
        try:
            # Create a log reader and shipper
            log_reader = LogReader(temp_path)
            shipper = LogShipper('localhost', 9001, log_reader)
            
            # Ship logs in batch mode
            logs_shipped = shipper.ship_logs_batch()
            shipper.close()
            
            # Wait a moment for the server to process the logs
            time.sleep(0.5)
            
            # Check that the logs were received
            assert logs_shipped == 2
            
            # Check the server received the logs
            received_text = ''.join(mock_server.received_logs)
            assert "Integration test log 1" in received_text
            assert "Integration test log 2" in received_text
        finally:
            # Clean up
            os.unlink(temp_path)
