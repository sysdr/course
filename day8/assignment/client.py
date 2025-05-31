import socket
import json
import sys
import time

def send_log(host='localhost', port=9000, log_message=None):
    """Send a log message to the TCP server.
    
    Args:
        host (str): Server hostname
        port (int): Server port
        log_message (str): Log message to send, or None to use a default
    """
    # Create a socket
    client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    
    try:
        # Connect to the server
        client_socket.connect((host, port))
        print(f"Connected to {host}:{port}")
        
        # Create a log message if none provided
        if log_message is None:
            log_data = {
                "timestamp": time.time(),
                "level": "INFO",
                "message": "This is a test log message",
                "source": "test_client"
            }
            log_message = json.dumps(log_data)
        
        # Send the log message
        client_socket.sendall(log_message.encode('utf-8') + b'\n')
        print(f"Sent: {log_message}")
        
        # Wait for acknowledgment
        response = client_socket.recv(1024)
        print(f"Received: {response.decode('utf-8')}")
        
    finally:
        # Close the socket
        client_socket.close()

if __name__ == "__main__":
    # Use command line arguments if provided
    host = 'localhost'
    port = 9000
    message = None
    
    if len(sys.argv) > 1:
        host = sys.argv[1]
    if len(sys.argv) > 2:
        port = int(sys.argv[2])
    if len(sys.argv) > 3:
        message = sys.argv[3]
    
    send_log(host, port, message)