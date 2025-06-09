#!/usr/bin/env python3
"""
UDP Log Shipping Client

This client sends log messages over UDP to a central log collector.
UDP provides high throughput with minimal overhead.
"""

import socket
import json
import time
import random
import argparse
import os
from datetime import datetime


class UDPLogClient:
    def __init__(self, server_host="127.0.0.1", server_port=9999, app_name="test-app"):
        """Initialize the UDP Log Client.
        
        Args:
            server_host (str): Host address of the log server
            server_port (int): Port the log server is listening on
            app_name (str): Name of this application (for log identification)
        """
        self.server_host = server_host
        self.server_port = server_port
        self.app_name = app_name
        self.socket = None
        self.sent_count = 0
        
    def setup_socket(self):
        """Create the UDP socket."""
        try:
            # Create UDP socket
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            
            # Optional: Set socket options for better performance
            # self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 8388608)  # 8MB buffer
            
            return True
        except Exception as e:
            print(f"Error setting up socket: {e}")
            return False
    
    def send_log(self, message, level="INFO"):
        """Send a log message to the server.
        
        Args:
            message (str): The log message to send
            level (str): Log level (INFO, WARNING, ERROR, etc.)
            
        Returns:
            bool: True if sent successfully, False otherwise
        """
        try:
            if not self.socket:
                if not self.setup_socket():
                    return False
            
            # Create a log entry in JSON format
            log_entry = {
                "timestamp": datetime.now().isoformat(),
                "app": self.app_name,
                "level": level,
                "message": message,
                "host": socket.gethostname()
            }
            
            # Convert to JSON string and encode to bytes
            log_bytes = json.dumps(log_entry).encode('utf-8')
            
            # Send the log message
            self.socket.sendto(log_bytes, (self.server_host, self.server_port))
            
            self.sent_count += 1
            return True
            
        except Exception as e:
            print(f"Error sending log: {e}")
            return False
    
    def close(self):
        """Close the socket connection."""
        if self.socket:
            self.socket.close()
            self.socket = None
            
    def generate_sample_logs(self, count=1000, interval=0.001):
        """Generate and send sample logs.
        
        Args:
            count (int): Number of logs to generate
            interval (float): Interval between logs in seconds
        """
        log_levels = ["INFO", "WARNING", "ERROR", "DEBUG"]
        actions = ["login", "logout", "view_page", "click_button", "purchase", 
                  "add_to_cart", "remove_from_cart", "search", "update_profile"]
        
        start_time = time.time()
        print(f"Generating {count} sample logs...")
        
        try:
            for i in range(count):
                # Generate a random log message
                level = random.choice(log_levels)
                action = random.choice(actions)
                user_id = random.randint(1000, 9999)
                duration = random.randint(10, 1000)
                
                message = f"User {user_id} performed {action} in {duration}ms"
                
                # Send the log
                self.send_log(message, level)
                
                # Report progress
                if (i+1) % 100 == 0:
                    elapsed = time.time() - start_time
                    rate = (i+1) / elapsed if elapsed > 0 else 0
                    print(f"Sent {i+1} logs ({rate:.2f} logs/second)")
                
                # Wait for the specified interval
                if interval > 0:
                    time.sleep(interval)
                    
        except KeyboardInterrupt:
            print("\nStopping log generation...")
        
        elapsed = time.time() - start_time
        rate = count / elapsed if elapsed > 0 else 0
        print(f"Sent {count} logs in {elapsed:.2f} seconds ({rate:.2f} logs/second)")


def main():
    """Parse command line arguments and start the client."""
    parser = argparse.ArgumentParser(description='UDP Log Client')
    parser.add_argument('--server', default='127.0.0.1', help='Log server host')
    parser.add_argument('--port', type=int, default=9999, help='Log server port')
    parser.add_argument('--app', default='test-app', help='Application name')
    parser.add_argument('--count', type=int, default=1000, help='Number of logs to generate')
    parser.add_argument('--interval', type=float, default=0.001, help='Interval between logs (seconds)')
    args = parser.parse_args()
    
    client = UDPLogClient(args.server, args.port, args.app)
    client.generate_sample_logs(args.count, args.interval)
    client.close()


if __name__ == "__main__":
    main()