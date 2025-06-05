import socket
import threading
import json
from datetime import datetime
from typing import Dict, Any, List
import colorama
from colorama import Fore, Style

from json_processor import JSONLogProcessor

colorama.init()

class JSONLogServer:
    """
    A TCP server that receives JSON logs over the network and processes them.
    
    This server acts as the front door to our distributed log processing system.
    It's like a sophisticated reception desk that not only welcomes visitors
    but also verifies their credentials and routes them to the right destination.
    
    The server integrates with our JSONLogProcessor to provide:
    - Network communication (TCP socket handling)
    - JSON log processing and validation
    - Real-time statistics and monitoring
    - Graceful connection management
    """
    
    def __init__(self, host: str = "localhost", port: int = 8080):
        """
        Initialize the JSON log server.
        
        Args:
            host: IP address to bind to ('0.0.0.0' for all interfaces)
            port: Port number to listen on
        """
        self.host = host
        self.port = port
        self.server_socket = None
        self.is_running = False
        
        # Initialize our JSON processing engine
        self.processor = JSONLogProcessor(max_workers=4)
        
        # Connection tracking for monitoring
        self.active_connections = []
        self.connection_stats = {
            'total_connections': 0,
            'active_connections': 0,
            'bytes_received': 0,
            'start_time': datetime.utcnow()
        }
        
        # Set up default output and error handlers
        self._setup_default_handlers()
        
        print(f"{Fore.GREEN}JSON Log Server initialized on {host}:{port}{Style.RESET_ALL}")
    
    def _setup_default_handlers(self) -> None:
        """
        Set up default handlers for processed logs and errors.
        
        These handlers demonstrate what happens after logs are validated.
        In a real system, you might save to databases, send to metrics
        systems, or forward to other services.
        """
        def console_output_handler(log_data: Dict[Any, Any]) -> None:
            """Handle successfully processed logs by printing to console."""
            timestamp = log_data.get('timestamp', 'unknown')
            service = log_data.get('service', 'unknown')
            level = log_data.get('level', 'INFO')
            message = log_data.get('message', '')
            
            # Color-code based on log level for better visibility
            color = Fore.WHITE
            if level == 'ERROR' or level == 'FATAL':
                color = Fore.RED
            elif level == 'WARN':
                color = Fore.YELLOW
            elif level == 'DEBUG':
                color = Fore.CYAN
            
            print(f"{color}[{timestamp}] {service} {level}: {message}{Style.RESET_ALL}")
        
        def console_error_handler(log_data: Dict[Any, Any], error_message: str) -> None:
            """Handle validation errors by printing to console."""
            print(f"{Fore.RED}VALIDATION ERROR: {error_message}{Style.RESET_ALL}")
            print(f"{Fore.RED}Raw data: {json.dumps(log_data, indent=2)}{Style.RESET_ALL}")
        
        # Register our default handlers
        self.processor.add_output_handler(console_output_handler)
        self.processor.add_error_handler(console_error_handler)
    
    def add_custom_handler(self, handler_func, is_error_handler: bool = False) -> None:
        """
        Add a custom handler for processed logs or errors.
        
        This allows you to extend the server's functionality easily.
        For example, you could add handlers that:
        - Save logs to a database
        - Send metrics to monitoring systems
        - Forward logs to other services
        - Trigger alerts for error conditions
        """
        if is_error_handler:
            self.processor.add_error_handler(handler_func)
        else:
            self.processor.add_output_handler(handler_func)
    
    def start(self) -> None:
        """
        Start the server and begin accepting connections.
        
        This method sets up the TCP socket, starts the JSON processor,
        and begins the main server loop. Think of this as opening the
        doors to our log processing facility.
        """
        try:
            # Create and configure the server socket
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            
            # Enable address reuse to avoid "Address already in use" errors
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            
            # Bind to the specified address and port
            self.server_socket.bind((self.host, self.port))
            
            # Start listening for connections (backlog of 5)
            self.server_socket.listen(5)
            
            # Start the JSON processor
            self.processor.start()
            
            self.is_running = True
            print(f"{Fore.GREEN}✓ JSON Log Server listening on {self.host}:{self.port}{Style.RESET_ALL}")
            
            # Main server loop - accept and handle connections
            while self.is_running:
                try:
                    # Accept a new client connection
                    client_socket, client_address = self.server_socket.accept()
                    
                    # Update connection statistics
                    self.connection_stats['total_connections'] += 1
                    self.connection_stats['active_connections'] += 1
                    
                    print(f"{Fore.BLUE}New connection from {client_address}{Style.RESET_ALL}")
                    
                    # Handle the client in a separate thread to support multiple concurrent connections
                    client_thread = threading.Thread(
                        target=self._handle_client,
                        args=(client_socket, client_address),
                        daemon=True
                    )
                    client_thread.start()
                    
                except socket.error as e:
                    if self.is_running:  # Only log errors if we're supposed to be running
                        print(f"{Fore.RED}Socket error: {e}{Style.RESET_ALL}")
                    break
                    
        except Exception as e:
            print(f"{Fore.RED}Failed to start server: {e}{Style.RESET_ALL}")
        finally:
            self.stop()
    
    def _handle_client(self, client_socket: socket.socket, client_address: tuple) -> None:
        """
        Handle communication with a single client connection.
        
        This method runs in its own thread for each connected client.
        It reads JSON log data from the client and submits it to our
        processor for validation and handling.
        
        Think of each thread as a dedicated customer service representative
        handling one client at a time.
        """
        buffer = ""  # Buffer to accumulate partial messages
        
        try:
            while self.is_running:
                # Receive data from the client
                data = client_socket.recv(4096)
                
                if not data:
                    # Client closed the connection
                    break
                
                # Update statistics
                self.connection_stats['bytes_received'] += len(data)
                
                # Decode the received bytes to string
                buffer += data.decode('utf-8', errors='ignore')
                
                # Process complete JSON messages
                # We expect each JSON log to be on a separate line
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    line = line.strip()
                    
                    if line:  # Skip empty lines
                        # Submit the log line to our processor
                        success = self.processor.submit_log(line)
                        
                        if not success:
                            # If we couldn't queue the log, we might be overloaded
                            print(f"{Fore.YELLOW}Warning: Could not process log from {client_address}{Style.RESET_ALL}")
                            
        except socket.error as e:
            print(f"{Fore.YELLOW}Client {client_address} disconnected: {e}{Style.RESET_ALL}")
        except Exception as e:
            print(f"{Fore.RED}Error handling client {client_address}: {e}{Style.RESET_ALL}")
        finally:
            # Clean up the client connection
            try:
                client_socket.close()
            except:
                pass
            
            # Update connection statistics
            self.connection_stats['active_connections'] -= 1
            print(f"{Fore.BLUE}Client {client_address} disconnected{Style.RESET_ALL}")
    
    def stop(self) -> None:
        """
        Gracefully shutdown the server.
        
        This method ensures all components are properly stopped:
        1. Stop accepting new connections
        2. Close existing connections
        3. Stop the JSON processor
        4. Clean up resources
        """
        print(f"{Fore.YELLOW}Stopping JSON Log Server...{Style.RESET_ALL}")
        
        self.is_running = False
        
        # Close the server socket to stop accepting new connections
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
        
        # Stop the JSON processor
        self.processor.stop()
        
        print(f"{Fore.GREEN}✓ JSON Log Server stopped{Style.RESET_ALL}")
    
    def get_stats(self) -> Dict[str, Any]:
        """
        Get comprehensive server and processing statistics.
        
        This provides a complete picture of system performance,
        similar to a dashboard showing all vital metrics.
        """
        # Get processing statistics from our JSON processor
        processor_stats = self.processor.get_stats()
        
        # Calculate uptime and connection rates
        current_time = datetime.utcnow()
        uptime_seconds = (current_time - self.connection_stats['start_time']).total_seconds()
        connections_per_minute = (self.connection_stats['total_connections'] / max(uptime_seconds, 1)) * 60
        
        return {
            'server_stats': {
                **self.connection_stats,
                'uptime_seconds': round(uptime_seconds, 2),
                'connections_per_minute': round(connections_per_minute, 2),
                'server_address': f"{self.host}:{self.port}",
                'is_running': self.is_running
            },
            **processor_stats
        }


# Example usage and testing function
def run_server_demo():
    """
    Demonstration of how to run the JSON log server.
    
    This function shows the basic usage pattern that students
    will use in their implementations.
    """
    server = JSONLogServer(host="localhost", port=8080)
    
    try:
        print(f"{Fore.GREEN}Starting JSON Log Server demo...{Style.RESET_ALL}")
        print(f"{Fore.CYAN}Send JSON logs to localhost:8080{Style.RESET_ALL}")
        print(f"{Fore.CYAN}Press Ctrl+C to stop{Style.RESET_ALL}")
        
        server.start()
        
    except KeyboardInterrupt:
        print(f"\n{Fore.YELLOW}Received shutdown signal{Style.RESET_ALL}")
    finally:
        server.stop()


if __name__ == "__main__":
    run_server_demo()