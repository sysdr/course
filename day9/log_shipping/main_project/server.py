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