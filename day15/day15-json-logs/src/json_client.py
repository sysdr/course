import socket
import json
import time
import random
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
import threading
import uuid
import colorama
from colorama import Fore, Style

colorama.init()

class JSONLogClient:
    """
    A client for sending JSON-formatted logs to our log server.
    
    This client simulates real applications in a distributed system that
    generate structured log data. It's like a smart shipping department
    that properly packages and labels each item before sending it out.
    
    The client can:
    - Generate realistic sample log data
    - Send logs individually or in batches
    - Simulate different types of applications
    - Handle connection errors gracefully
    - Track sending statistics
    """
    
    def __init__(self, server_host: str = "localhost", server_port: int = 8080):
        """
        Initialize the JSON log client.
        
        Args:
            server_host: Hostname or IP of the log server
            server_port: Port number of the log server
        """
        self.server_host = server_host
        self.server_port = server_port
        self.socket = None
        self.is_connected = False
        
        # Statistics for monitoring client performance
        self.stats = {
            'logs_sent': 0,
            'bytes_sent': 0,
            'connection_errors': 0,
            'send_errors': 0,
            'start_time': datetime.utcnow()
        }
        
        # Sample data for generating realistic logs
        self.sample_services = [
            "user-service", "auth-service", "payment-service", 
            "notification-service", "analytics-service", "api-gateway"
        ]
        
        self.sample_messages = [
            "User login successful",
            "Processing payment request",
            "Sending notification email",
            "API request processed",
            "Database query executed",
            "Cache hit for user data",
            "Authentication token validated",
            "File upload completed",
            "Background job started",
            "Health check passed"
        ]
        
        self.sample_errors = [
            "Database connection timeout",
            "Invalid authentication token",
            "Payment processing failed",
            "External API unavailable",
            "Memory allocation failed",
            "Disk space critical",
            "Rate limit exceeded",
            "Invalid request format"
        ]
        
        print(f"{Fore.GREEN}JSON Log Client initialized for {server_host}:{server_port}{Style.RESET_ALL}")
    
    def connect(self) -> bool:
        """
        Establish connection to the log server.
        
        This method creates a TCP connection to our server. Think of it
        as establishing a dedicated phone line between the client and server.
        
        Returns:
            True if connection successful, False otherwise
        """
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.connect((self.server_host, self.server_port))
            self.is_connected = True
            
            print(f"{Fore.GREEN}✓ Connected to log server at {self.server_host}:{self.server_port}{Style.RESET_ALL}")
            return True
            
        except Exception as e:
            print(f"{Fore.RED}Failed to connect to server: {e}{Style.RESET_ALL}")
            self.stats['connection_errors'] += 1
            self.is_connected = False
            return False
    
    def disconnect(self) -> None:
        """
        Close the connection to the log server.
        
        This ensures we clean up network resources properly,
        like hanging up a phone call when finished.
        """
        if self.socket:
            try:
                self.socket.close()
            except:
                pass
            
        self.is_connected = False
        print(f"{Fore.BLUE}Disconnected from log server{Style.RESET_ALL}")
    
    def send_log(self, log_data: Dict[Any, Any]) -> bool:
        """
        Send a single JSON log entry to the server.
        
        This is the core method that takes structured log data,
        converts it to JSON format, and transmits it over the network.
        
        Args:
            log_data: Dictionary containing the log information
            
        Returns:
            True if log was sent successfully, False otherwise
        """
        if not self.is_connected:
            print(f"{Fore.YELLOW}Not connected to server. Call connect() first.{Style.RESET_ALL}")
            return False
        
        try:
            # Convert the log data to JSON string
            json_string = json.dumps(log_data)
            
            # Add newline delimiter (our server expects one log per line)
            message = json_string + '\n'
            
            # Send the message as bytes
            self.socket.send(message.encode('utf-8'))
            
            # Update statistics
            self.stats['logs_sent'] += 1
            self.stats['bytes_sent'] += len(message)
            
            return True
            
        except Exception as e:
            print(f"{Fore.RED}Error sending log: {e}{Style.RESET_ALL}")
            self.stats['send_errors'] += 1
            self.is_connected = False  # Connection likely broken
            return False
    
    def generate_sample_log(self, log_level: str = None, service_name: str = None) -> Dict[str, Any]:
        """
        Generate a realistic sample log entry.
        
        This method creates log data that mimics what real applications
        would generate. It's like having a template for creating proper
        shipping labels with all required information.
        
        Args:
            log_level: Specific log level to use (INFO, WARN, ERROR, etc.)
            service_name: Specific service name to use
            
        Returns:
            Dictionary containing structured log data
        """
        # Choose log level (weighted towards INFO for realism)
        if log_level is None:
            log_level = random.choices(
                ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'],
                weights=[10, 60, 20, 8, 2]  # Most logs are INFO level
            )[0]
        
        # Choose service name
        if service_name is None:
            service_name = random.choice(self.sample_services)
        
        # Choose appropriate message based on log level
        if log_level in ['ERROR', 'FATAL']:
            message = random.choice(self.sample_errors)
        else:
            message = random.choice(self.sample_messages)
        
        # Generate realistic timestamp (slightly randomized for testing)
        base_time = datetime.utcnow()
        time_offset = random.randint(-300, 0)  # Up to 5 minutes ago
        log_time = base_time + timedelta(seconds=time_offset)
        
        # Create the log entry with all required fields
        log_entry = {
            'timestamp': log_time.isoformat() + 'Z',
            'level': log_level,
            'service': service_name,
            'message': message,
            'request_id': f"req_{uuid.uuid4().hex[:16]}",
        }
        
        # Add optional fields sometimes (to test schema flexibility)
        if random.random() < 0.3:  # 30% chance of having user_id
            log_entry['user_id'] = str(uuid.uuid4())
        
        if random.random() < 0.4:  # 40% chance of having metadata
            log_entry['metadata'] = {
                'processing_time_ms': random.randint(1, 500),
                'memory_usage_mb': random.randint(10, 200),
                'thread_id': random.randint(1, 20)
            }
        
        return log_entry
    
    def send_batch_logs(self, count: int, delay_ms: int = 100) -> int:
        """
        Send multiple log entries with a delay between each.
        
        This simulates realistic application behavior where logs are
        generated continuously but not all at once. Think of it as
        a steady stream of packages being shipped throughout the day.
        
        Args:
            count: Number of logs to send
            delay_ms: Milliseconds to wait between sending logs
            
        Returns:
            Number of logs successfully sent
        """
        if not self.is_connected:
            print(f"{Fore.YELLOW}Not connected to server{Style.RESET_ALL}")
            return 0
        
        successful_sends = 0
        print(f"{Fore.BLUE}Sending {count} logs with {delay_ms}ms delay...{Style.RESET_ALL}")
        
        for i in range(count):
            # Generate a sample log
            log_data = self.generate_sample_log()
            
            # Try to send it
            if self.send_log(log_data):
                successful_sends += 1
                
                # Print progress every 10 logs
                if (i + 1) % 10 == 0:
                    print(f"{Fore.CYAN}Sent {i + 1}/{count} logs{Style.RESET_ALL}")
            else:
                print(f"{Fore.RED}Failed to send log {i + 1}{Style.RESET_ALL}")
                break  # Stop if we can't send
            
            # Wait before sending the next log
            if delay_ms > 0:
                time.sleep(delay_ms / 1000.0)
        
        print(f"{Fore.GREEN}✓ Successfully sent {successful_sends}/{count} logs{Style.RESET_ALL}")
        return successful_sends
    
    def simulate_application_traffic(self, duration_seconds: int = 60, logs_per_second: float = 2.0) -> None:
        """
        Simulate realistic application log traffic over time.
        
        This method generates logs at a steady rate, simulating how a real
        application would behave in production. It's like simulating the
        natural flow of customers through a store throughout the day.
        
        Args:
            duration_seconds: How long to run the simulation
            logs_per_second: Average rate of log generation
        """
        if not self.is_connected:
            print(f"{Fore.YELLOW}Not connected to server{Style.RESET_ALL}")
            return
        
        print(f"{Fore.BLUE}Simulating application traffic for {duration_seconds} seconds at {logs_per_second} logs/sec{Style.RESET_ALL}")
        
        start_time = time.time()
        logs_sent = 0
        
        while time.time() - start_time < duration_seconds:
            # Calculate when the next log should be sent
            next_log_time = start_time + (logs_sent / logs_per_second)
            current_time = time.time()
            
            if current_time >= next_log_time:
                # Time to send another log
                log_data = self.generate_sample_log()
                
                if self.send_log(log_data):
                    logs_sent += 1
                    
                    # Print status every 20 logs
                    if logs_sent % 20 == 0:
                        elapsed = current_time - start_time
                        rate = logs_sent / elapsed
                        print(f"{Fore.CYAN}Traffic simulation: {logs_sent} logs sent, {rate:.1f} logs/sec{Style.RESET_ALL}")
                else:
                    print(f"{Fore.RED}Connection lost during simulation{Style.RESET_ALL}")
                    break
            else:
                # Wait a bit before checking again
                time.sleep(0.01)  # 10ms sleep to avoid busy waiting
        
        elapsed_time = time.time() - start_time
        actual_rate = logs_sent / elapsed_time
        print(f"{Fore.GREEN}✓ Simulation complete: {logs_sent} logs in {elapsed_time:.1f}s ({actual_rate:.1f} logs/sec){Style.RESET_ALL}")
    
    def get_stats(self) -> Dict[str, Any]:
        """
        Get client statistics for performance monitoring.
        
        This provides insights into how well the client is performing,
        similar to checking the efficiency metrics of a shipping department.
        """
        current_time = datetime.utcnow()
        uptime_seconds = (current_time - self.stats['start_time']).total_seconds()
        
        logs_per_second = self.stats['logs_sent'] / max(uptime_seconds, 1)
        
        return {
            **self.stats,
            'uptime_seconds': round(uptime_seconds, 2),
            'logs_per_second': round(logs_per_second, 2),
            'is_connected': self.is_connected,
            'server_address': f"{self.server_host}:{self.server_port}"
        }


# Demonstration and testing functions
def run_client_demo():
    """
    Demonstrate basic client usage.
    
    This function shows students how to use the client in practice.
    """
    client = JSONLogClient()
    
    try:
        # Connect to the server
        if not client.connect():
            return
        
        print(f"{Fore.GREEN}Running client demonstration...{Style.RESET_ALL}")
        
        # Send a few individual logs
        print(f"{Fore.BLUE}Sending individual logs...{Style.RESET_ALL}")
        for i in range(5):
            log_data = client.generate_sample_log()
            client.send_log(log_data)
            time.sleep(0.5)
        
        # Send a batch of logs
        print(f"{Fore.BLUE}Sending batch of logs...{Style.RESET_ALL}")
        client.send_batch_logs(10, delay_ms=200)
        
        # Simulate realistic traffic
        print(f"{Fore.BLUE}Simulating realistic application traffic...{Style.RESET_ALL}")
        client.simulate_application_traffic(duration_seconds=15, logs_per_second=3.0)
        
        # Show statistics
        stats = client.get_stats()
        print(f"{Fore.GREEN}Client Statistics:{Style.RESET_ALL}")
        print(f"  Logs sent: {stats['logs_sent']}")
        print(f"  Bytes sent: {stats['bytes_sent']}")
        print(f"  Average rate: {stats['logs_per_second']:.2f} logs/sec")
        
    except KeyboardInterrupt:
        print(f"\n{Fore.YELLOW}Client demo interrupted{Style.RESET_ALL}")
    finally:
        client.disconnect()


if __name__ == "__main__":
    run_client_demo()