#!/usr/bin/env python3
"""
UDP Log Collector Server with Priority-Based Handling

This server listens for log messages sent over UDP and processes them.
Implements priority handling for ERROR logs and acknowledgment system.
"""

import socket
import json
import argparse
import time
import os
import threading
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
        
        # Directory for storing received logs
        self.log_dir = os.path.join(os.getcwd(), "logs")
        os.makedirs(self.log_dir, exist_ok=True)
        
        # Current log file
        self.current_date = datetime.now().strftime("%Y-%m-%d")
        self.log_file = os.path.join(self.log_dir, f"udp_logs_{self.current_date}.log")
        
        # Buffer for non-ERROR logs
        self.log_buffer = []
        self.buffer_size = 100  # Flush after this many logs
        self.buffer_timeout = 5  # Flush after this many seconds
        self.last_flush_time = time.time()
        
        # Special storage for ERROR logs
        self.error_logs = []
        
        # Log level statistics
        self.level_counts = {}
        
    def setup_socket(self):
        """Create and bind the UDP socket."""
        try:
            # Create UDP socket (SOCK_DGRAM for UDP)
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            
            # Set socket options
            # Allow reuse of address/port
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            
            # Optional: Increase receive buffer size for high throughput
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8388608)  # 8MB buffer
            
            # Bind socket to address and port
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
            
        # Write all logs in buffer to file
        with open(self.log_file, 'a') as f:
            f.write('\n'.join(self.log_buffer) + '\n')
            
        # Clear the buffer
        self.log_buffer.clear()
        self.last_flush_time = time.time()
        
    def process_log(self, data, addr):
        """Process a received log message."""
        try:
            # Decode the received bytes to a string
            log_str = data.decode('utf-8')
            
            # Check if it's an ERROR log
            is_error = False
            try:
                log_data = json.loads(log_str)
                
                # Update level counts for statistics
                level = log_data.get('level', 'UNKNOWN')
                self.level_counts[level] = self.level_counts.get(level, 0) + 1
                
                # Add source information
                log_data['source_ip'] = addr[0]
                log_data['source_port'] = addr[1]
                log_str = json.dumps(log_data)
                
                if level == 'ERROR':
                    is_error = True
                    # Store ERROR logs separately
                    self.error_logs.append(log_data)
                    # Keep only the last 100 ERROR logs
                    if len(self.error_logs) > 100:
                        self.error_logs.pop(0)
                        
                    # Send acknowledgment for ERROR logs
                    if self.socket:
                        ack_message = json.dumps({
                            'ack': True,
                            'sequence': log_data.get('sequence'),
                            'timestamp': datetime.now().isoformat()
                        }).encode('utf-8')
                        self.socket.sendto(ack_message, addr)
                
            except json.JSONDecodeError:
                # If not JSON, just append source info
                log_str = f"{log_str.strip()} [from: {addr[0]}:{addr[1]}]"
            
            # Check if we need to roll over to a new log file
            current_date = datetime.now().strftime("%Y-%m-%d")
            if current_date != self.current_date:
                self.current_date = current_date
                self.log_file = os.path.join(self.log_dir, f"udp_logs_{self.current_date}.log")
            
            # Process ERROR logs immediately, buffer others
            if is_error:
                with open(self.log_file, 'a') as f:
                    f.write(f"{log_str}\n")
            else:
                self.log_buffer.append(log_str)
                
                # Flush if buffer is full or timeout reached
                if (len(self.log_buffer) >= self.buffer_size or
                        time.time() - self.last_flush_time >= self.buffer_timeout):
                    self.flush_buffer()
            
            # Update statistics
            self.log_count += 1
            if self.log_count % 1000 == 0:
                elapsed = time.time() - self.start_time
                rate = self.log_count / elapsed if elapsed > 0 else 0
                print(f"Processed {self.log_count} logs ({rate:.2f} logs/second)")
                
        except Exception as e:
            print(f"Error processing log: {e}")
    
    def run(self):
        """Run the server's main loop to receive and process logs."""
        if not self.setup_socket():
            return
        
        print("Server started. Press Ctrl+C to stop.")
        
        try:
            while True:
                # Receive data from the socket
                data, addr = self.socket.recvfrom(self.buffer_size)
                
                # Process the received log
                self.process_log(data, addr)
                
        except KeyboardInterrupt:
            print("\nShutting down server...")
        finally:
            # Flush any remaining logs
            self.flush_buffer()
            
            if self.socket:
                self.socket.close()
            print(f"Server stopped. Processed {self.log_count} logs.")
            
    def get_stats(self):
        """Get server statistics for the dashboard."""
        if self.start_time:
            elapsed = time.time() - self.start_time
            rate = self.log_count / elapsed if elapsed > 0 else 0
        else:
            rate = 0
            
        return {
            'log_count': self.log_count,
            'current_rate': rate,
            'level_distribution': self.level_counts,
            'error_logs': self.error_logs[-10:]  # Last 10 error logs
        }


def main():
    """Parse command line arguments and start the server."""
    parser = argparse.ArgumentParser(description='UDP Log Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=9999, help='Port to listen on')
    parser.add_argument('--buffer', type=int, default=8192, help='UDP buffer size')
    parser.add_argument('--dashboard', action='store_true', help='Start dashboard server')
    parser.add_argument('--dashboard-port', type=int, default=8080, help='Dashboard port')
    args = parser.parse_args()
    
    server = UDPLogServer(args.host, args.port, args.buffer)
    
    # Start dashboard if requested
    if args.dashboard:
        try:
            from dashboard import start_dashboard_thread
            dashboard_thread = start_dashboard_thread(server, args.dashboard_port)
        except ImportError:
            print("Dashboard module not found. Running without dashboard.")
    
    server.run()


if __name__ == "__main__":
    main()