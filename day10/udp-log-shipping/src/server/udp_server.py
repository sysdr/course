#!/usr/bin/env python3
"""
UDP Log Collector Server

Listens for log messages sent over UDP and writes them to disk.
Batches logs before writing to reduce disk I/O.
"""

import socket
import json
import argparse
import time
import os
import tempfile
from datetime import datetime


class UDPLogServer:
    def __init__(self, host="0.0.0.0", port=9999, buffer_size=8192):
        """Initialize the UDP Log Server."""
        self.host = host
        self.port = port
        self.buffer_size = buffer_size
        self.socket = None
        self.log_count = 0
        self.start_time = None

        self.log_dir = os.path.join(os.getcwd(), "logs")
        os.makedirs(self.log_dir, exist_ok=True)
        self.current_date = datetime.now().strftime("%Y-%m-%d")
        self.log_file = os.path.join(self.log_dir, f"udp_logs_{self.current_date}.log")

        self.log_buffer = []
        self.buffer_size = 100  # Flush after this many logs
        self.buffer_timeout = 5  # Flush after this many seconds
        self.last_flush_time = time.time()

    def setup_socket(self):
        """Create and bind the UDP socket."""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.socket.bind((self.host, self.port))
            print(f"UDP Log Server listening on {self.host}:{self.port}")
            self.start_time = time.time()
            return True
        except Exception as e:
            print(f"Error setting up socket: {e}")
            return False

    def flush_buffer(self):
        """Write buffered logs to disk."""
        if not self.log_buffer:
            return
        try:
            with open(self.log_file, 'a') as f:
                f.write('\n'.join(self.log_buffer) + '\n')
        except OSError:
            self.log_file = os.path.join(tempfile.gettempdir(), f"udp_logs_{self.current_date}.log")
            with open(self.log_file, 'a') as f:
                f.write('\n'.join(self.log_buffer) + '\n')
        self.log_buffer.clear()
        self.last_flush_time = time.time()

    def process_log(self, data, addr):
        """Process a received log message."""
        try:
            log_str = data.decode('utf-8')
            try:
                log_data = json.loads(log_str)
                log_data['source_ip'] = addr[0]
                log_data['source_port'] = addr[1]
                log_str = json.dumps(log_data)
            except json.JSONDecodeError:
                log_str = f"{log_str.strip()} [from: {addr[0]}:{addr[1]}]"

            current_date = datetime.now().strftime("%Y-%m-%d")
            if current_date != self.current_date:
                self.current_date = current_date
                self.log_file = os.path.join(self.log_dir, f"udp_logs_{self.current_date}.log")

            self.log_buffer.append(log_str)
            if (len(self.log_buffer) >= self.buffer_size or
                    time.time() - self.last_flush_time >= self.buffer_timeout):
                self.flush_buffer()

            self.log_count += 1
        except Exception as e:
            print(f"Error processing log: {e}")

    def run(self):
        """Run the server's main loop."""
        if not self.setup_socket():
            return
        print("Server started. Press Ctrl+C to stop.")
        try:
            while True:
                data, addr = self.socket.recvfrom(8192)
                self.process_log(data, addr)
        except KeyboardInterrupt:
            print("\nShutting down server...")
        finally:
            self.flush_buffer()
            if self.socket:
                self.socket.close()
            print(f"Server stopped. Processed {self.log_count} logs.")


def main():
    parser = argparse.ArgumentParser(description='UDP Log Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=9999, help='Port to listen on')
    args = parser.parse_args()
    server = UDPLogServer(args.host, args.port)
    server.run()


if __name__ == "__main__":
    main()
