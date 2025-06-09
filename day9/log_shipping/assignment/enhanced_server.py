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