#!/bin/bash

echo "================================================"
echo "Setting up Log Shipping Project"
echo "================================================"

# Create top-level project directory
PROJECT_ROOT="log_shipping_project"
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

echo "Creating directory structure..."

# Create main project structure
mkdir -p main_project/src
mkdir -p main_project/tests
mkdir -p main_project/logs

# Create assignment project structure
mkdir -p assignment/src
mkdir -p assignment/tests
mkdir -p assignment/logs

echo "✅ Directory structure created"

#################################################
# MAIN PROJECT FILES
#################################################

echo "Creating main project files..."

# Main Project: requirements.txt
cat > main_project/requirements.txt << 'EOF'
pytest==7.3.1
pytest-cov==4.1.0
EOF

# Main Project: sample_logs.txt
cat > main_project/sample_logs.txt << 'EOF'
2023-05-19 10:15:22 INFO User login successful: user123
2023-05-19 10:15:25 DEBUG Loading user preferences
2023-05-19 10:15:30 WARNING Failed to load optional module: analytics
2023-05-19 10:16:02 ERROR Database connection timeout after 30s
2023-05-19 10:16:10 INFO User logout: user123
EOF

# Main Project: src/__init__.py
cat > main_project/src/__init__.py << 'EOF'
# Log Shipping Client Package
EOF

# Main Project: src/log_reader.py
cat > main_project/src/log_reader.py << 'EOF'
import time
from typing import Iterator, Optional

class LogReader:
    """Reads logs from a file, supporting both batch and real-time reading."""
    
    def __init__(self, log_file_path: str):
        """Initialize with path to log file.
        
        Args:
            log_file_path: Path to the log file to read
        """
        self.log_file_path = log_file_path
        self.last_position = 0
    
    def read_batch(self) -> list[str]:
        """Read all logs in the file as a batch.
        
        Returns:
            List of log lines
        """
        try:
            with open(self.log_file_path, 'r') as file:
                return file.readlines()
        except FileNotFoundError:
            print(f"Warning: Log file {self.log_file_path} not found")
            return []
    
    def read_incremental(self) -> Iterator[str]:
        """Read logs incrementally, yielding only new lines.
        
        Yields:
            New log lines as they are written to the file
        """
        try:
            with open(self.log_file_path, 'r') as file:
                # Move to the last read position
                file.seek(self.last_position)
                
                while True:
                    line = file.readline()
                    if line:
                        yield line
                        self.last_position = file.tell()
                    else:
                        # No new lines, wait before checking again
                        time.sleep(0.1)
        except FileNotFoundError:
            print(f"Warning: Log file {self.log_file_path} not found")
            yield from []
EOF

# Main Project: src/log_shipper.py
cat > main_project/src/log_shipper.py << 'EOF'
import socket
import time
from typing import Optional, List
from src.log_reader import LogReader

class LogShipper:
    """Client that ships logs to a remote TCP server."""
    
    def __init__(self, server_host: str, server_port: int, 
                 log_reader: LogReader, max_retries: int = 3):
        """Initialize the log shipper.
        
        Args:
            server_host: Hostname or IP of the TCP log server
            server_port: Port the TCP log server is listening on
            log_reader: LogReader instance to read logs from
            max_retries: Maximum number of connection retry attempts
        """
        self.server_host = server_host
        self.server_port = server_port
        self.log_reader = log_reader
        self.max_retries = max_retries
        self.socket = None
    
    def connect(self) -> bool:
        """Establish connection to the TCP server.
        
        Returns:
            True if connection successful, False otherwise
        """
        retries = 0
        while retries < self.max_retries:
            try:
                self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                self.socket.connect((self.server_host, self.server_port))
                print(f"Connected to {self.server_host}:{self.server_port}")
                return True
            except (socket.error, ConnectionRefusedError) as e:
                print(f"Connection failed (attempt {retries+1}/{self.max_retries}): {e}")
                retries += 1
                # Exponential backoff: wait longer between each retry
                time.sleep(2 ** retries)
                
        print("Failed to connect after maximum retry attempts")
        return False
    
    def ship_logs_batch(self, logs: Optional[List[str]] = None) -> int:
        """Ship a batch of logs to the server.
        
        Args:
            logs: List of log strings to ship. If None, reads from the log_reader.
            
        Returns:
            Number of logs successfully shipped
        """
        if logs is None:
            logs = self.log_reader.read_batch()
        
        if not logs:
            return 0
            
        if not self.socket and not self.connect():
            return 0
            
        logs_shipped = 0
        for log in logs:
            try:
                # Ensure log ends with newline
                if not log.endswith('\n'):
                    log += '\n'
                self.socket.sendall(log.encode('utf-8'))
                logs_shipped += 1
            except socket.error as e:
                print(f"Error shipping log: {e}")
                # Try to reconnect
                if self.connect():
                    # Retry the current log
                    try:
                        self.socket.sendall(log.encode('utf-8'))
                        logs_shipped += 1
                    except socket.error:
                        # Give up on this log if we still can't send it
                        pass
                
        return logs_shipped
    
    def ship_logs_continuously(self) -> None:
        """Continuously ship logs as they're generated.
        
        This method blocks indefinitely, shipping logs as they appear.
        """
        if not self.connect():
            print("Could not establish initial connection, aborting")
            return
            
        for log in self.log_reader.read_incremental():
            retry_count = 0
            sent = False
            
            while not sent and retry_count < self.max_retries:
                try:
                    if not log.endswith('\n'):
                        log += '\n'
                    self.socket.sendall(log.encode('utf-8'))
                    sent = True
                except socket.error as e:
                    print(f"Error shipping log: {e}")
                    retry_count += 1
                    
                    # Try to reconnect
                    if self.connect():
                        continue
                    else:
                        # Wait before retrying
                        time.sleep(2 ** retry_count)
    
    def close(self) -> None:
        """Close connection to the server."""
        if self.socket:
            try:
                self.socket.close()
                print("Connection closed")
            except socket.error as e:
                print(f"Error closing connection: {e}")
            finally:
                self.socket = None
EOF

# Main Project: src/main.py
cat > main_project/src/main.py << 'EOF'
import argparse
import signal
import sys
from src.log_reader import LogReader
from src.log_shipper import LogShipper

def parse_args():
    parser = argparse.ArgumentParser(description='Ship logs to a remote TCP server')
    parser.add_argument('--log-file', required=True, help='Path to the log file to ship')
    parser.add_argument('--server-host', default='localhost', help='Host of the TCP log server')
    parser.add_argument('--server-port', type=int, default=9000, help='Port of the TCP log server')
    parser.add_argument('--batch', action='store_true', help='Ship logs in batch mode instead of continuous')
    return parser.parse_args()

def main():
    args = parse_args()
    
    log_reader = LogReader(args.log_file)
    shipper = LogShipper(args.server_host, args.server_port, log_reader)
    
    # Set up graceful shutdown
    def handle_shutdown(sig, frame):
        print("\nShutting down log shipper...")
        shipper.close()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)
    
    try:
        if args.batch:
            log_count = shipper.ship_logs_batch()
            print(f"Shipped {log_count} logs in batch mode")
        else:
            print(f"Starting continuous log shipping from {args.log_file} to {args.server_host}:{args.server_port}")
            print("Press Ctrl+C to stop")
            shipper.ship_logs_continuously()
    except Exception as e:
        print(f"Error during log shipping: {e}")
    finally:
        shipper.close()

if __name__ == "__main__":
    main()
EOF

# Main Project: server.py
cat > main_project/server.py << 'EOF'
import socket
import threading
import argparse

def handle_client(client_socket, address):
    print(f"New connection from {address}")
    try:
        while True:
            data = client_socket.recv(4096)
            if not data:
                break
            print(f"Received log from {address}: {data.decode('utf-8').strip()}")
    except Exception as e:
        print(f"Error handling client {address}: {e}")
    finally:
        client_socket.close()
        print(f"Connection from {address} closed")

def start_server(host, port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind((host, port))
        server.listen(5)
        print(f"Server listening on {host}:{port}")
        
        while True:
            client, address = server.accept()
            client_handler = threading.Thread(target=handle_client, args=(client, address))
            client_handler.daemon = True
            client_handler.start()
    except KeyboardInterrupt:
        print("Server shutting down")
    except Exception as e:
        print(f"Server error: {e}")
    finally:
        server.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='TCP Log Server')
    parser.add_argument('--host', default='0.0.0.0', help='Server host')
    parser.add_argument('--port', type=int, default=9000, help='Server port')
    args = parser.parse_args()
    
    start_server(args.host, args.port)
EOF

# Main Project: Dockerfile
cat > main_project/Dockerfile << 'EOF'
FROM python:3.10-slim

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ src/
COPY sample_logs.txt .

# Environment variables for configuration
ENV LOG_FILE=/app/sample_logs.txt
ENV SERVER_HOST=log-server
ENV SERVER_PORT=9000
ENV SHIPPING_MODE=continuous

# Run the log shipper
CMD python -m src.main --log-file $LOG_FILE --server-host $SERVER_HOST --server-port $SERVER_PORT $([ "$SHIPPING_MODE" = "batch" ] && echo "--batch")
EOF

# Main Project: Dockerfile.server
cat > main_project/Dockerfile.server << 'EOF'
FROM python:3.10-slim

WORKDIR /app

COPY server.py .

EXPOSE 9000

CMD ["python", "server.py", "--host", "0.0.0.0", "--port", "9000"]
EOF

# Main Project: docker-compose.yml
cat > main_project/docker-compose.yml << 'EOF'
version: '3'

services:
  log-server:
    build: 
      context: .
      dockerfile: Dockerfile.server
    ports:
      - "9000:9000"
    networks:
      - log-network

  log-client:
    build: .
    environment:
      - SERVER_HOST=log-server
      - SERVER_PORT=9000
      - SHIPPING_MODE=continuous
    volumes:
      # Mount a logs directory for real-time log generation
      - ./logs:/app/logs
    networks:
      - log-network
    depends_on:
      - log-server

networks:
  log-network:
    driver: bridge
EOF

# Main Project: tests/__init__.py
cat > main_project/tests/__init__.py << 'EOF'
# Test Package
EOF

# Main Project: tests/test_log_reader.py
cat > main_project/tests/test_log_reader.py << 'EOF'
import os
import tempfile
import threading
import time
import pytest
from src.log_reader import LogReader

class TestLogReader:
    
    def test_read_batch_existing_file(self):
        # Create a temporary file with test logs
        with tempfile.NamedTemporaryFile(mode='w+', delete=False) as temp:
            temp.write("Log line 1\nLog line 2\nLog line 3\n")
            temp_path = temp.name
        
        try:
            # Test reading the file in batch mode
            reader = LogReader(temp_path)
            logs = reader.read_batch()
            
            assert len(logs) == 3
            assert logs[0] == "Log line 1\n"
            assert logs[1] == "Log line 2\n"
            assert logs[2] == "Log line 3\n"
        finally:
            # Clean up
            os.unlink(temp_path)
    
    def test_read_batch_nonexistent_file(self):
        # Test with a file that doesn't exist
        reader = LogReader("/path/that/does/not/exist")
        logs = reader.read_batch()
        
        assert logs == []
    
    def test_read_incremental(self):
        # Create a temporary file
        with tempfile.NamedTemporaryFile(mode='w+', delete=False) as temp:
            temp.write("Log line 1\n")
            temp_path = temp.name
        
        try:
            reader = LogReader(temp_path)
            
            # Start reading in a separate thread
            logs = []
            stop_event = threading.Event()
            
            def read_thread():
                for log in reader.read_incremental():
                    logs.append(log)
                    if stop_event.is_set():
                        break
            
            thread = threading.Thread(target=read_thread)
            thread.daemon = True
            thread.start()
            
            # Wait a moment for the thread to start
            time.sleep(0.2)
            
            # Append more logs to the file
            with open(temp_path, 'a') as f:
                f.write("Log line 2\n")
                f.write("Log line 3\n")
            
            # Wait for logs to be read
            time.sleep(0.2)
            stop_event.set()
            thread.join(timeout=1)
            
            assert len(logs) >= 3
            assert logs[0] == "Log line 1\n"
            assert logs[1] == "Log line 2\n"
            assert logs[2] == "Log line 3\n"
        finally:
            # Clean up
            os.unlink(temp_path)
EOF

# Main Project: tests/test_log_shipper.py
cat > main_project/tests/test_log_shipper.py << 'EOF'
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
EOF

# Main Project: tests/test_integration.py
cat > main_project/tests/test_integration.py << 'EOF'
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
EOF

echo "✅ Main project files created"

#################################################
# ASSIGNMENT FILES
#################################################

echo "Creating assignment files..."

# Assignment: requirements.txt
cat > assignment/requirements.txt << 'EOF'
pytest==7.3.1
pytest-cov==4.1.0
psutil==5.9.5
EOF

# Assignment: sample_logs.txt
cat > assignment/sample_logs.txt << 'EOF'
2023-05-19 10:15:22 INFO User login successful: user123
2023-05-19 10:15:25 DEBUG Loading user preferences
2023-05-19 10:15:30 WARNING Failed to load optional module: analytics
2023-05-19 10:16:02 ERROR Database connection timeout after 30s
2023-05-19 10:16:10 INFO User logout: user123
EOF

# Assignment: src/__init__.py
cat > assignment/src/__init__.py << 'EOF'
# Enhanced Log Shipping Client Package
EOF

# Assignment: Copy log_reader.py from main project
cp main_project/src/log_reader.py assignment/src/log_reader.py

# Assignment: src/resilient_shipper.py
cat > assignment/src/resilient_shipper.py << 'EOF'
import socket
import time
import json
import os
from collections import deque
from typing import Optional, List, Dict
from src.log_reader import LogReader

class ResilientLogShipper:
    """A more resilient log shipping client with buffering and persistence."""
    
    def __init__(self, server_host: str, server_port: int, 
                 log_reader: LogReader, buffer_size: int = 1000,
                 persistence_file: Optional[str] = "undelivered_logs.json",
                 max_retries: int = 5):
        """Initialize the resilient log shipper.
        
        Args:
            server_host: Hostname or IP of the TCP log server
            server_port: Port the TCP log server is listening on
            log_reader: LogReader instance to read logs from
            buffer_size: Maximum number of logs to keep in memory buffer
            persistence_file: File to store undelivered logs between restarts
            max_retries: Maximum number of connection retry attempts
        """
        self.server_host = server_host
        self.server_port = server_port
        self.log_reader = log_reader
        self.buffer_size = buffer_size
        self.persistence_file = persistence_file
        self.max_retries = max_retries
        self.socket = None
        
        # In-memory buffer for logs
        self.buffer = deque(maxlen=buffer_size)
        
        # Load any persisted logs
        self._load_persisted_logs()
    
    def _load_persisted_logs(self) -> None:
        """Load any logs that weren't delivered in previous runs."""
        if not self.persistence_file or not os.path.exists(self.persistence_file):
            return
            
        try:
            with open(self.persistence_file, 'r') as f:
                persisted_logs = json.load(f)
                
                # Add persisted logs to the buffer
                for log in persisted_logs:
                    self.buffer.append(log)
                    
            print(f"Loaded {len(persisted_logs)} persisted logs")
            
            # Clear the persistence file since we've loaded the logs
            os.unlink(self.persistence_file)
        except (json.JSONDecodeError, IOError) as e:
            print(f"Error loading persisted logs: {e}")
    
    def _persist_undelivered_logs(self) -> None:
        """Save any undelivered logs to disk."""
        if not self.persistence_file or not self.buffer:
            return
            
        try:
            with open(self.persistence_file, 'w') as f:
                json.dump(list(self.buffer), f)
                
            print(f"Persisted {len(self.buffer)} undelivered logs")
        except IOError as e:
            print(f"Error persisting logs: {e}")
    
    def connect(self) -> bool:
        """Establish connection to the TCP server with exponential backoff.
        
        Returns:
            True if connection successful, False otherwise
        """
        retries = 0
        
        while retries < self.max_retries:
            try:
                self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                self.socket.connect((self.server_host, self.server_port))
                print(f"Connected to {self.server_host}:{self.server_port}")
                return True
            except (socket.error, ConnectionRefusedError) as e:
                print(f"Connection failed (attempt {retries+1}/{self.max_retries}): {e}")
                retries += 1
                
                # Exponential backoff: wait longer between each retry
                backoff_time = min(60, 2 ** retries)  # Cap at 60 seconds
                print(f"Retrying in {backoff_time} seconds...")
                time.sleep(backoff_time)
                
        print("Failed to connect after maximum retry attempts")
        return False
    
    def _process_buffer(self) -> int:
        """Attempt to send any logs in the buffer.
        
        Returns:
            Number of logs successfully sent
        """
        if not self.buffer:
            return 0
            
        if not self.socket and not self.connect():
            return 0
            
        logs_sent = 0
        buffer_size = len(self.buffer)
        
        for _ in range(buffer_size):
            try:
                log = self.buffer.popleft()  # Get the oldest log
                
                # Ensure log ends with newline
                if not log.endswith('\n'):
                    log += '\n'
                    
                self.socket.sendall(log.encode('utf-8'))
                logs_sent += 1
            except socket.error as e:
                print(f"Error shipping log from buffer: {e}")
                
                # Put the log back in the buffer
                self.buffer.appendleft(log)
                
                # Try to reconnect
                if not self.connect():
                    # If reconnection fails, stop processing the buffer
                    break
        
        return logs_sent
    
    def ship_logs_batch(self, logs: Optional[List[str]] = None) -> int:
        """Ship a batch of logs to the server, with buffering for resilience.
        
        Args:
            logs: List of log strings to ship. If None, reads from the log_reader.
            
        Returns:
            Number of logs successfully shipped
        """
        # First, try to send any buffered logs
        buffer_sent = self._process_buffer()
        
        # Get new logs if none were provided
        if logs is None:
            logs = self.log_reader.read_batch()
        
        if not logs:
            return buffer_sent
            
        # Ensure we have a connection
        if not self.socket and not self.connect():
            # If we can't connect, buffer all logs
            self.buffer.extend(logs)
            return buffer_sent
            
        logs_shipped = buffer_sent
        
        for log in logs:
            try:
                # Ensure log ends with newline
                if not log.endswith('\n'):
                    log += '\n'
                    
                self.socket.sendall(log.encode('utf-8'))
                logs_shipped += 1
            except socket.error as e:
                print(f"Error shipping log: {e}")
                
                # Buffer the log for later retry
                self.buffer.append(log)
                
                # Try to reconnect
                if not self.connect():
                    # If reconnection fails, buffer remaining logs
                    self.buffer.extend(logs[logs.index(log)+1:])
                    break
        
        return logs_shipped
    
    def ship_logs_continuously(self) -> None:
        """Continuously ship logs as they're generated, with resilience.
        
        This method blocks indefinitely, shipping logs as they appear.
        """
        # First, process any buffered logs
        self._process_buffer()
        
        # Ensure initial connection
        if not self.socket and not self.connect():
            print("Could not establish initial connection, will retry")
        
        try:
            for log in self.log_reader.read_incremental():
                # Try to process any buffered logs first
                self._process_buffer()
                
                try:
                    if self.socket:
                        # Try to send the new log directly
                        if not log.endswith('\n'):
                            log += '\n'
                            
                        self.socket.sendall(log.encode('utf-8'))
                    else:
                        # No connection, buffer the log
                        self.buffer.append(log)
                        
                        # Try to reconnect
                        self.connect()
                except socket.error as e:
                    print(f"Error shipping log: {e}")
                    
                    # Buffer the log for later
                    self.buffer.append(log)
                    
                    # Try to reconnect
                    self.connect()
        except KeyboardInterrupt:
            print("\nStopping log shipping")
        finally:
            self.close()
    
    def close(self) -> None:
        """Close connection to the server and persist any undelivered logs."""
        # Try to send any remaining buffered logs
        if self.buffer:
            print(f"Attempting to send {len(self.buffer)} buffered logs before shutdown")
            self._process_buffer()
        
        # Persist any logs that couldn't be delivered
        self._persist_undelivered_logs()
        
        # Close the socket
        if self.socket:
            try:
                self.socket.close()
                print("Connection closed")
            except socket.error as e:
                print(f"Error closing connection: {e}")
            finally:
                self.socket = None
EOF

# Assignment: src/resilient_main.py
cat > assignment/src/resilient_main.py << 'EOF'
import argparse
import signal
import sys
from src.log_reader import LogReader
from src.resilient_shipper import ResilientLogShipper

def parse_args():
    parser = argparse.ArgumentParser(description='Ship logs to a remote TCP server with resilience')
    parser.add_argument('--log-file', required=True, help='Path to the log file to ship')
    parser.add_argument('--server-host', default='localhost', help='Host of the TCP log server')
    parser.add_argument('--server-port', type=int, default=9000, help='Port of the TCP log server')
    parser.add_argument('--batch', action='store_true', help='Ship logs in batch mode instead of continuous')
    parser.add_argument('--buffer-size', type=int, default=1000, help='Maximum logs to keep in memory buffer')
    parser.add_argument('--persistence-file', default='undelivered_logs.json', 
                        help='File to store undelivered logs between restarts')
    return parser.parse_args()

def main():
    args = parse_args()
    
    log_reader = LogReader(args.log_file)
    shipper = ResilientLogShipper(
        args.server_host, 
        args.server_port, 
        log_reader,
        buffer_size=args.buffer_size,
        persistence_file=args.persistence_file
    )
    
    # Set up graceful shutdown
    def handle_shutdown(sig, frame):
        print("\nShutting down log shipper...")
        shipper.close()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)
    
    try:
        if args.batch:
            log_count = shipper.ship_logs_batch()
            print(f"Shipped {log_count} logs in batch mode")
        else:
            print(f"Starting continuous log shipping from {args.log_file} to {args.server_host}:{args.server_port}")
            print("Press Ctrl+C to stop")
            shipper.ship_logs_continuously()
    except Exception as e:
        print(f"Error during log shipping: {e}")
    finally:
        shipper.close()

if __name__ == "__main__":
    main()
EOF

# Assignment: src/enhanced_shipper.py
cat > assignment/src/enhanced_shipper.py << 'EOF'
import socket
import time
import json
import os
import gzip
import threading
import io
from collections import deque
from typing import Optional, List, Dict, Any
from src.resilient_shipper import ResilientLogShipper
from src.log_reader import LogReader

class EnhancedLogShipper(ResilientLogShipper):
    """Enhanced log shipping client with compression, batching, and monitoring."""
    
    def __init__(self, server_host: str, server_port: int, 
                 log_reader: LogReader, buffer_size: int = 1000,
                 persistence_file: Optional[str] = "undelivered_logs.json",
                 max_retries: int = 5, compress_logs: bool = True,
                 batch_size: int = 10, heartbeat_interval: int = 30):
        """Initialize the enhanced log shipper.
        
        Args:
            server_host: Hostname or IP of the TCP log server
            server_port: Port the TCP log server is listening on
            log_reader: LogReader instance to read logs from
            buffer_size: Maximum number of logs to keep in memory buffer
            persistence_file: File to store undelivered logs between restarts
            max_retries: Maximum number of connection retry attempts
            compress_logs: Whether to compress logs before sending
            batch_size: Number of logs to batch together before sending
            heartbeat_interval: Seconds between server heartbeat checks
        """
        super().__init__(server_host, server_port, log_reader, 
                         buffer_size, persistence_file, max_retries)
                         
        self.compress_logs = compress_logs
        self.batch_size = batch_size
        self.heartbeat_interval = heartbeat_interval
        
        # Metrics
        self.metrics = {
            "logs_sent": 0,
            "logs_failed": 0,
            "bytes_sent": 0,
            "bytes_saved_by_compression": 0,
            "connection_attempts": 0,
            "connection_failures": 0,
            "heartbeats_sent": 0,
            "heartbeats_failed": 0,
            "average_latency_ms": 0,
            "total_latency_samples": 0,
        }
        
        # Start heartbeat thread if interval > 0
        self.running = True
        if self.heartbeat_interval > 0:
            self.heartbeat_thread = threading.Thread(target=self._heartbeat_loop)
            self.heartbeat_thread.daemon = True
            self.heartbeat_thread.start()
    
    def _heartbeat_loop(self) -> None:
        """Background thread that sends heartbeats to check server connectivity."""
        while self.running:
            time.sleep(self.heartbeat_interval)
            self._send_heartbeat()
    
    def _send_heartbeat(self) -> bool:
        """Send a heartbeat to check if the server is available.
        
        Returns:
            True if server responded, False otherwise
        """
        if self.socket is None:
            # Try to establish a connection
            connection_result = self.connect()
            if not connection_result:
                self.metrics["heartbeats_failed"] += 1
                return False
        
        try:
            # Send a small heartbeat message
            start_time = time.time()
            self.socket.sendall(b"HEARTBEAT\n")
            
            # Set a timeout for the response
            self.socket.settimeout(2)
            
            # We don't actually need to read anything, just make sure
            # the send succeeds and the connection is still up
            
            # Update metrics
            end_time = time.time()
            latency_ms = (end_time - start_time) * 1000
            
            # Update rolling average latency
            total_latency = (self.metrics["average_latency_ms"] * 
                            self.metrics["total_latency_samples"])
            self.metrics["total_latency_samples"] += 1
            self.metrics["average_latency_ms"] = (total_latency + latency_ms) / \
                                                self.metrics["total_latency_samples"]
            
            self.metrics["heartbeats_sent"] += 1
            
            # Reset timeout to blocking mode
            self.socket.settimeout(None)
            return True
        except socket.error:
            self.metrics["heartbeats_failed"] += 1
            self.socket = None  # Connection is dead
            return False
    
    def _compress_logs(self, logs: List[str]) -> bytes:
        """Compress a batch of logs into a single gzipped payload.
        
        Args:
            logs: List of log strings to compress
            
        Returns:
            Compressed binary data
        """
        # Join logs with newlines
        combined = ''.join(log if log.endswith('\n') else log + '\n' for log in logs)
        combined_bytes = combined.encode('utf-8')
        
        # Compress
        with io.BytesIO() as compressed_stream:
            with gzip.GzipFile(fileobj=compressed_stream, mode='wb') as f:
                f.write(combined_bytes)
            
            compressed_data = compressed_stream.getvalue()
        
        # Update metrics
        self.metrics["bytes_saved_by_compression"] += (len(combined_bytes) - len(compressed_data))
        
        return compressed_data
    
    def _send_batch(self, logs: List[str]) -> int:
        """Send a batch of logs to the server.
        
        Args:
            logs: List of log strings to send
            
        Returns:
            Number of logs successfully sent
        """
        if not logs:
            return 0
            
        if not self.socket and not self.connect():
            return 0
        
        try:
            start_time = time.time()
            
            if self.compress_logs:
                # Send compressed batch with header to indicate compression
                compressed_data = self._compress_logs(logs)
                self.socket.sendall(b"COMPRESSED\n")
                
                # Send length of compressed data followed by the data itself
                length_bytes = str(len(compressed_data)).encode('utf-8') + b"\n"
                self.socket.sendall(length_bytes)
                self.socket.sendall(compressed_data)
                
                self.metrics["bytes_sent"] += len(compressed_data) + len(length_bytes) + 11  # Header length
            else:
                # Send each log individually
                batch_data = ''.join(log if log.endswith('\n') else log + '\n' for log in logs)
                batch_bytes = batch_data.encode('utf-8')
                self.socket.sendall(batch_bytes)
                
                self.metrics["bytes_sent"] += len(batch_bytes)
            
            # Update metrics
            end_time = time.time()
            latency_ms = (end_time - start_time) * 1000
            
            # Update rolling average latency
            total_latency = (self.metrics["average_latency_ms"] * 
                           self.metrics["total_latency_samples"])
            self.metrics["total_latency_samples"] += 1
            self.metrics["average_latency_ms"] = (total_latency + latency_ms) / \
                                               self.metrics["total_latency_samples"]
            
            self.metrics["logs_sent"] += len(logs)
            
            return len(logs)
        except socket.error as e:
            print(f"Error sending batch: {e}")
            self.metrics["logs_failed"] += len(logs)
            self.socket = None  # Mark connection as dead
            return 0
    
    def connect(self) -> bool:
        """Establish connection to the TCP server with metrics tracking."""
        self.metrics["connection_attempts"] += 1
        result = super().connect()
        
        if not result:
            self.metrics["connection_failures"] += 1
            
        return result
    
    def ship_logs_batch(self, logs: Optional[List[str]] = None) -> int:
        """Ship logs in batches with compression.
        
        Args:
            logs: List of log strings to ship. If None, reads from the log_reader.
            
        Returns:
            Number of logs successfully shipped
        """
        # First, try to send any buffered logs
        buffer_sent = self._process_buffer_in_batches()
        
        # Get new logs if none were provided
        if logs is None:
            logs = self.log_reader.read_batch()
        
        if not logs:
            return buffer_sent
        
        # Ensure we have a connection
        if not self.socket and not self.connect():
            # If we can't connect, buffer all logs
            self.buffer.extend(logs)
            return buffer_sent
        
        # Process logs in batches
        logs_shipped = buffer_sent
        for i in range(0, len(logs), self.batch_size):
            batch = logs[i:i + self.batch_size]
            sent = self._send_batch(batch)
            
            if sent == 0:
                # Failed to send batch, buffer remaining logs
                self.buffer.extend(logs[i:])
                break
                
            logs_shipped += sent
        
        return logs_shipped
    
    def _process_buffer_in_batches(self) -> int:
        """Process buffered logs in batches.
        
        Returns:
            Number of logs successfully sent
        """
        if not self.buffer:
            return 0
            
        if not self.socket and not self.connect():
            return 0
            
        logs_sent = 0
        # Process the buffer in batches
        while self.buffer and logs_sent < len(self.buffer):
            # Get a batch from the buffer
            batch = []
            for _ in range(min(self.batch_size, len(self.buffer))):
                if self.buffer:
                    batch.append(self.buffer.popleft())
            
            # Send the batch
            sent = self._send_batch(batch)
            
            if sent == 0:
                # Failed to send batch, put logs back in buffer
                self.buffer.extendleft(reversed(batch))
                break
                
            logs_sent += sent
        
        return logs_sent
    
    def ship_logs_continuously(self) -> None:
        """Continuously ship logs as they're generated, in batches with compression."""
        # First, process any buffered logs
        self._process_buffer_in_batches()
        
        # Ensure initial connection
        if not self.socket and not self.connect():
            print("Could not establish initial connection, will retry")
        
        try:
            current_batch = []
            
            for log in self.log_reader.read_incremental():
                # Add to current batch
                current_batch.append(log)
                
                # If we've reached batch size, send the batch
                if len(current_batch) >= self.batch_size:
                    # Try to process any buffered logs first
                    self._process_buffer_in_batches()
                    
                    # Try to send the current batch
                    if self.socket:
                        sent = self._send_batch(current_batch)
                        if sent == 0:
                            # Failed to send, buffer the batch
                            self.buffer.extend(current_batch)
                            
                            # Try to reconnect
                            self.connect()
                    else:
                        # No connection, buffer the batch
                        self.buffer.extend(current_batch)
                        
                        # Try to reconnect
                        self.connect()
                    
                    # Clear the batch
                    current_batch = []
        except KeyboardInterrupt:
            print("\nStopping log shipping")
        finally:
            # Send any remaining logs in the current batch
            if current_batch:
                if self.socket:
                    sent = self._send_batch(current_batch)
                    if sent == 0:
                        # Failed to send, buffer the batch
                        self.buffer.extend(current_batch)
                else:
                    # No connection, buffer the batch
                    self.buffer.extend(current_batch)
            
            self.close()
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get current metrics.
        
        Returns:
            Dictionary of metric names and values
        """
        # Add buffer utilization to metrics
        buffer_utilization = len(self.buffer) / self.buffer_size if self.buffer_size > 0 else 0
        metrics_copy = self.metrics.copy()
        metrics_copy["buffer_utilization"] = buffer_utilization
        metrics_copy["buffer_size"] = len(self.buffer)
        metrics_copy["buffer_capacity"] = self.buffer_size
        
        return metrics_copy
    
    def print_metrics(self) -> None:
        """Print current metrics to console."""
        metrics = self.get_metrics()
        
        print("\n=== Log Shipping Metrics ===")
        print(f"Logs Sent: {metrics['logs_sent']}")
        print(f"Logs Failed: {metrics['logs_failed']}")
        print(f"Bytes Sent: {metrics['bytes_sent']} bytes")
        print(f"Bytes Saved by Compression: {metrics['bytes_saved_by_compression']} bytes")
        print(f"Average Latency: {metrics['average_latency_ms']:.2f} ms")
        print(f"Connection Attempts: {metrics['connection_attempts']}")
        print(f"Connection Failures: {metrics['connection_failures']}")
        print(f"Heartbeats Sent: {metrics['heartbeats_sent']}")
        print(f"Heartbeats Failed: {metrics['heartbeats_failed']}")
        print(f"Buffer Utilization: {metrics['buffer_utilization']*100:.1f}% ({metrics['buffer_size']}/{metrics['buffer_capacity']})")
        print("===========================\n")
    
    def close(self) -> None:
        """Close connection and stop heartbeat thread."""
        self.running = False
        
        # Print final metrics
        self.print_metrics()
        
        # Call parent close method
        super().close()
EOF

# Assignment: src/enhanced_main.py
cat > assignment/src/enhanced_main.py << 'EOF'
import argparse
import signal
import sys
import threading
import time
from src.log_reader import LogReader
from src.enhanced_shipper import EnhancedLogShipper

def parse_args():
    parser = argparse.ArgumentParser(description='Ship logs to a remote TCP server with advanced features')
    parser.add_argument('--log-file', required=True, help='Path to the log file to ship')
    parser.add_argument('--server-host', default='localhost', help='Host of the TCP log server')
    parser.add_argument('--server-port', type=int, default=9000, help='Port of the TCP log server')
    parser.add_argument('--batch', action='store_true', help='Ship logs in batch mode instead of continuous')
    parser.add_argument('--buffer-size', type=int, default=1000, help='Maximum logs to keep in memory buffer')
    parser.add_argument('--persistence-file', default='undelivered_logs.json', 
                        help='File to store undelivered logs between restarts')
    parser.add_argument('--compress', action='store_true', default=True, help='Compress logs before sending')
    parser.add_argument('--no-compress', action='store_false', dest='compress', help='Disable log compression')
    parser.add_argument('--batch-size', type=int, default=10, help='Number of logs to batch together')
    parser.add_argument('--heartbeat-interval', type=int, default=30, 
                        help='Seconds between server heartbeat checks (0 to disable)')
    parser.add_argument('--metrics-interval', type=int, default=60, 
                        help='Seconds between metrics reports (0 to disable)')
    return parser.parse_args()

def main():
    args = parse_args()
    
    log_reader = LogReader(args.log_file)
    shipper = EnhancedLogShipper(
        args.server_host, 
        args.server_port, 
        log_reader,
        buffer_size=args.buffer_size,
        persistence_file=args.persistence_file,
        compress_logs=args.compress,
        batch_size=args.batch_size,
        heartbeat_interval=args.heartbeat_interval
    )
    
    # Set up metrics reporting
    stop_metrics = threading.Event()
    
    def metrics_reporter():
        while not stop_metrics.is_set():
            shipper.print_metrics()
            time.sleep(args.metrics_interval)
    
    if args.metrics_interval > 0:
        metrics_thread = threading.Thread(target=metrics_reporter)
        metrics_thread.daemon = True
        metrics_thread.start()
    
    # Set up graceful shutdown
    def handle_shutdown(sig, frame):
        print("\nShutting down log shipper...")
        stop_metrics.set()
        shipper.close()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)
    
    try:
        if args.batch:
            log_count = shipper.ship_logs_batch()
            print(f"Shipped {log_count} logs in batch mode")
            shipper.print_metrics()
        else:
            print(f"Starting continuous log shipping from {args.log_file} to {args.server_host}:{args.server_port}")
            print(f"Compression: {'Enabled' if args.compress else 'Disabled'}, Batch Size: {args.batch_size}")
            print("Press Ctrl+C to stop")
            shipper.ship_logs_continuously()
    except Exception as e:
        print(f"Error during log shipping: {e}")
    finally:
        stop_metrics.set()
        shipper.close()

if __name__ == "__main__":
    main()
EOF

# Assignment: enhanced_server.py
cat > assignment/enhanced_server.py << 'EOF'
import socket
import threading
import argparse
import gzip
import io
import time

def handle_client(client_socket, address):
    print(f"New connection from {address}")
    total_logs_received = 0
    start_time = time.time()
    
    try:
        buffer = b""
        
        while True:
            data = client_socket.recv(4096)
            if not data:
                break
                
            buffer += data
            
            # Check if we have a complete message
            while buffer:
                # Handle heartbeat messages
                if buffer.startswith(b"HEARTBEAT\n"):
                    print(f"Received heartbeat from {address}")
                    buffer = buffer[10:]  # Remove heartbeat message
                    continue
                
                # Handle compressed logs
                if buffer.startswith(b"COMPRESSED\n"):
                    # Remove the COMPRESSED header
                    buffer = buffer[11:]
                    
                    # Try to read the length
                    length_end = buffer.find(b"\n")
                    if length_end == -1:
                        # We don't have the full length yet
                        break
                        
                    try:
                        length = int(buffer[:length_end].decode('utf-8'))
                        
                        # Check if we have the full compressed data
                        if len(buffer) < length_end + 1 + length:
                            # We don't have the full compressed data yet
                            break
                            
                        # Extract the compressed data
                        compressed_data = buffer[length_end + 1:length_end + 1 + length]
                        
                        # Decompress
                        with io.BytesIO(compressed_data) as compressed_stream:
                            with gzip.GzipFile(fileobj=compressed_stream, mode='rb') as f:
                                decompressed_data = f.read().decode('utf-8')
                                
                        # Process the decompressed logs
                        logs = decompressed_data.splitlines()
                        for log in logs:
                            if log:  # Skip empty lines
                                print(f"Received log from {address}: {log}")
                                total_logs_received += 1
                        
                        # Remove the processed data from the buffer
                        buffer = buffer[length_end + 1 + length:]
                    except (ValueError, IOError) as e:
                        print(f"Error processing compressed data: {e}")
                        # Discard the buffer to avoid getting stuck
                        buffer = b""
                else:
                    # Handle normal logs (one per line)
                    log_end = buffer.find(b"\n")
                    if log_end == -1:
                        # We don't have a complete log yet
                        break
                        
                    log = buffer[:log_end].decode('utf-8')
                    if log and not log.startswith("COMPRESSED"):  # Skip empty lines and compressed headers
                        print(f"Received log from {address}: {log}")
                        total_logs_received += 1
                        
                    # Remove the processed log from the buffer
                    buffer = buffer[log_end + 1:]
    except Exception as e:
        print(f"Error handling client {address}: {e}")
    finally:
        client_socket.close()
        elapsed_time = time.time() - start_time
        print(f"Connection from {address} closed after {elapsed_time:.2f} seconds")
        print(f"Received {total_logs_received} logs from {address} ({total_logs_received/elapsed_time:.2f} logs/sec)")

def start_server(host, port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind((host, port))
        server.listen(5)
        print(f"Enhanced server listening on {host}:{port}")
        
        while True:
            client, address = server.accept()
            client_handler = threading.Thread(target=handle_client, args=(client, address))
            client_handler.daemon = True
            client_handler.start()
    except KeyboardInterrupt:
        print("Server shutting down")
    except Exception as e:
        print(f"Server error: {e}")
    finally:
        server.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Enhanced TCP Log Server')
    parser.add_argument('--host', default='0.0.0.0', help='Server host')
    parser.add_argument('--port', type=int, default=9000, help='Server port')
    args = parser.parse_args()
    
    start_server(args.host, args.port)
EOF

# Assignment: Dockerfile
cat > assignment/Dockerfile << 'EOF'
FROM python:3.10-slim

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ src/
COPY sample_logs.txt .

# Environment variables for configuration
ENV LOG_FILE=/app/sample_logs.txt
ENV SERVER_HOST=log-server
ENV SERVER_PORT=9000
ENV SHIPPING_MODE=continuous

# Run the enhanced log shipper
CMD python -m src.enhanced_main --log-file $LOG_FILE --server-host $SERVER_HOST --server-port $SERVER_PORT --compress --batch-size 5 $([ "$SHIPPING_MODE" = "batch" ] && echo "--batch")
EOF

# Assignment: Dockerfile.server
cat > assignment/Dockerfile.server << 'EOF'
FROM python:3.10-slim

WORKDIR /app

COPY enhanced_server.py .

EXPOSE 9000

CMD ["python", "enhanced_server.py", "--host", "0.0.0.0", "--port", "9000"]
EOF

# Assignment: docker-compose.yml
cat > assignment/docker-compose.yml << 'EOF'
version: '3'

services:
  log-server:
    build: 
      context: .
      dockerfile: Dockerfile.server
    ports:
      - "9000:9000"
    networks:
      - log-network

  log-client:
    build: .
    environment:
      - SERVER_HOST=log-server
      - SERVER_PORT=9000
      - SHIPPING_MODE=continuous
    volumes:
      # Mount a logs directory for real-time log generation
      - ./logs:/app/logs
    networks:
      - log-network
    depends_on:
      - log-server

networks:
  log-network:
    driver: bridge
EOF

# Assignment: tests/__init__.py
cat > assignment/tests/__init__.py << 'EOF'
# Assignment Test Package
EOF

# Assignment: tests/test_resilient_shipper.py
cat > assignment/tests/test_resilient_shipper.py << 'EOF'
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
EOF

# Assignment: tests/test_enhanced_shipper.py
cat > assignment/tests/test_enhanced_shipper.py << 'EOF'
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
EOF

echo "✅ Assignment files created"

#################################################
# CREATE README FILES
#################################################

echo "Creating README files..."

# Main Project README
cat > main_project/README.md << 'EOF'
# Log Shipping Client - Main Project

This is the basic implementation of a log shipping client that demonstrates core concepts.

## Features

- Read logs from files (batch and incremental)
- Ship logs to a TCP server over the network
- Basic error handling and retry logic
- Containerization support with Docker

## Running the Project

### Install Dependencies
```bash
pip install -r requirements.txt
```

### Start the Server
```bash
python server.py --port 9000
```

### Run the Client (Batch Mode)
```bash
python -m src.main --log-file sample_logs.txt --server-host localhost --server-port 9000 --batch
```

### Run the Client (Continuous Mode)
```bash
python -m src.main --log-file sample_logs.txt --server-host localhost --server-port 9000
```

### Run Tests
```bash
pytest tests/ -v
```

### With Coverage
```bash
pytest --cov=src tests/
```

### Using Docker
```bash
docker-compose up
```

## Project Structure

- `src/log_reader.py` - Reads logs from files
- `src/log_shipper.py` - Ships logs to TCP server
- `src/main.py` - Command-line interface
- `server.py` - TCP log server
- `tests/` - Unit and integration tests
EOF

# Assignment README
cat > assignment/README.md << 'EOF'
# Log Shipping Client - Assignment Solution

This is the enhanced implementation with resilience features, compression, and metrics.

## Features

### Resilient Shipper
- In-memory buffering for failed deliveries
- Disk-based persistence across restarts
- Exponential backoff for reconnection

### Enhanced Shipper
- Log compression with gzip
- Batch sending to reduce network overhead
- Heartbeat monitoring
- Comprehensive metrics collection

## Running the Project

### Install Dependencies
```bash
pip install -r requirements.txt
```

### Start the Enhanced Server
```bash
python enhanced_server.py --port 9000
```

### Run Resilient Client
```bash
python -m src.resilient_main --log-file sample_logs.txt --server-host localhost --server-port 9000
```

### Run Enhanced Client
```bash
python -m src.enhanced_main --log-file sample_logs.txt --server-host localhost --server-port 9000 --compress --batch-size 5 --metrics-interval 10
```

### Run Tests
```bash
pytest tests/ -v
```

### Using Docker
```bash
docker-compose up
```

## Testing Resilience

1. Start server and client
2. Stop server to test buffering
3. Add logs during server downtime
4. Restart server to see automatic reconnection

## Metrics

The enhanced shipper provides real-time metrics:
- Logs sent/failed
- Bytes sent
- Compression savings
- Connection statistics
- Buffer utilization
EOF

# Top-level README
cat > README.md << 'EOF'
# Log Shipping Project - Complete Implementation

This project contains both the basic log shipping implementation and the advanced assignment solution.

## Project Structure
```
log_shipping_project/
├── main_project/          # Basic log shipping client
└── assignment/            # Enhanced log shipping client with advanced features
```

## Getting Started

1. Navigate to either `main_project/` or `assignment/`
2. Follow the README in that directory
3. Start with `main_project/` to learn basics
4. Move to `assignment/` for advanced features

## Learning Path

1. **Main Project**: Understand core concepts
   - Log reading (batch and incremental)
   - Network communication with TCP
   - Basic error handling
   - Testing fundamentals

2. **Assignment**: Implement production features
   - Resilience with buffering and persistence
   - Compression for efficiency
   - Metrics for monitoring
   - Advanced testing strategies

## Quick Start

### Main Project
```bash
cd main_project
pip install -r requirements.txt
python server.py --port 9000
# In another terminal:
python -m src.main --log-file sample_logs.txt --server-host localhost --server-port 9000
```

### Assignment
```bash
cd assignment
pip install -r requirements.txt
python enhanced_server.py --port 9000
# In another terminal:
python -m src.enhanced_main --log-file sample_logs.txt --server-host localhost --server-port 9000 --compress
```
EOF

echo "✅ README files created"

#################################################
# FINAL SUMMARY
#################################################

echo ""
echo "================================================"
echo "✅ Project setup complete!"
echo "================================================"
echo ""
echo "Project location: $PROJECT_ROOT"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_ROOT/main_project"
echo "  2. pip install -r requirements.txt"
echo "  3. python server.py --port 9000"
echo "  4. (in another terminal) python -m src.main --log-file sample_logs.txt"
echo ""
echo "Or start with the assignment:"
echo "  1. cd $PROJECT_ROOT/assignment"
echo "  2. pip install -r requirements.txt"
echo "  3. python enhanced_server.py --port 9000"
echo "  4. (in another terminal) python -m src.enhanced_main --log-file sample_logs.txt"
echo ""
echo "================================================"