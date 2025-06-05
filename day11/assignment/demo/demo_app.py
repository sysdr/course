# assignment/demo/demo_app.py
import time
import random
import threading
import argparse
import json
import logging
from typing import Dict, Any

# Add parent directory to import path
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from enhanced_log_shipper.enhanced_batch_client import EnhancedBatchLogClient

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("DemoApp")

class LogGenerator:
    """Generates random logs at a configurable rate."""
    
    def __init__(self, client: EnhancedBatchLogClient, logs_per_second: float = 10.0):
        """Initialize the log generator.
        
        Args:
            client: The batch log client to send logs to
            logs_per_second: How many logs to generate per second
        """
        self.client = client
        self.logs_per_second = logs_per_second
        self.running = False
        self.thread = None
        self.log_count = 0
        
        # Generate some random service names
        self.services = [
            "api-gateway", "user-service", "payment-processor", 
            "inventory-manager", "notification-service"
        ]
        
        # Generate some random log levels with weights
        self.log_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        self.level_weights = [0.4, 0.4, 0.1, 0.07, 0.03]
        
    def start(self):
        """Start generating logs."""
        if self.running:
            return
            
        self.running = True
        self.thread = threading.Thread(target=self._generate_logs)
        self.thread.daemon = True
        self.thread.start()
        logger.info(f"Log generator started (generating {self.logs_per_second} logs/second)")
        
    def stop(self):
        """Stop generating logs."""
        self.running = False
        if self.thread:
            self.thread.join(timeout=1.0)
        logger.info(f"Log generator stopped (generated {self.log_count} logs total)")
    
    def _generate_logs(self):
        """Generate random logs and send to the client."""
        interval = 1.0 / self.logs_per_second
        
        while self.running:
            start_time = time.time()
            
            # Generate a random log
            log = self._create_random_log()
            self.client.send_log(log)
            self.log_count += 1
            
            # Calculate sleep time to maintain desired rate
            elapsed = time.time() - start_time
            sleep_time = max(0, interval - elapsed)
            time.sleep(sleep_time)
    
    def _create_random_log(self) -> Dict[str, Any]:
        """Create a random log message."""
        service = random.choice(self.services)
        level = random.choices(self.log_levels, weights=self.level_weights)[0]
        
        # Create different message types based on level
        if level == "DEBUG":
            message = f"Processing request #{random.randint(1000, 9999)}"
            data_size = random.randint(10, 50)
        elif level == "INFO":
            message = f"Successfully completed operation in {random.randint(10, 500)}ms"
            data_size = random.randint(50, 200)
        elif level == "WARNING":
            message = f"Slow response time: {random.randint(500, 2000)}ms"
            data_size = random.randint(200, 500)
        elif level == "ERROR":
            message = f"Failed to process request: error code {random.randint(400, 599)}"
            data_size = random.randint(500, 1000)
        else:  # CRITICAL
            message = f"Service unavailable: dependency {random.choice(self.services)} is down"
            data_size = random.randint(1000, 2000)
        
        # Add a random payload to show compression benefits
        random_data = ''.join(random.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ') for _ in range(data_size))
        
        return {
            "timestamp": time.time(),
            "service": service,
            "level": level,
            "message": message,
            "request_id": f"{random.randint(100000, 999999)}",
            "metadata": {
                "host": f"server-{random.randint(1, 10)}",
                "cluster": f"cluster-{random.randint(1, 3)}",
                "data": random_data
            }
        }

def print_metrics_periodically(client: EnhancedBatchLogClient, interval: float = 5.0):
    """Print metrics at regular intervals."""
    while True:
        time.sleep(interval)
        
        metrics = client.get_metrics()
        
        print("\n--- Current Metrics ---")
        print(f"Logs sent: {metrics['total_logs_sent']}")
        print(f"Batches sent: {metrics['total_batches_sent']}")
        print(f"Avg batch size: {metrics.get('avg_batch_size', 0):.2f} logs")
        print(f"Avg transmission time: {metrics.get('avg_transmission_time', 0) * 1000:.2f} ms")
        print(f"Compression savings: {metrics.get('avg_space_saving', 0) * 100:.2f}%")
        print(f"Retries: {metrics['total_retries']}")
        print(f"Failures: {metrics['total_failures']}")
        print("----------------------\n")

def update_config_periodically(client: EnhancedBatchLogClient, interval: float = 30.0):
    """Periodically update client configuration to demonstrate dynamic config."""
    time.sleep(interval)  # Initial delay
    
    # Update batch size
    logger.info("Changing batch size from 100 to 50")
    client.batch_size = 50
    
    time.sleep(interval)
    
    # Update batch interval
    logger.info("Changing batch interval from 5.0s to 2.0s")
    client.batch_interval = 2.0

def main():
    """Main demo application."""
    parser = argparse.ArgumentParser(description='Enhanced Batch Log Client Demo')
    parser.add_argument('--batch-size', type=int, default=100, help='Initial batch size')
    parser.add_argument('--batch-interval', type=float, default=5.0, help='Initial batch interval (seconds)')
    parser.add_argument('--logs-per-second', type=float, default=10.0, help='Logs to generate per second')
    parser.add_argument('--run-time', type=int, default=120, help='Run time in seconds (0 for indefinite)')
    parser.add_argument('--server-host', type=str, default='localhost', help='Log server hostname or IP')
    parser.add_argument('--server-port', type=int, default=9999, help='Log server port')
    parser.add_argument('--no-compression', action='store_true', help='Disable compression')
    
    args = parser.parse_args()
    
    # Create the enhanced batch client
    client = EnhancedBatchLogClient(
        server_host=args.server_host,
        server_port=args.server_port,
        batch_size=args.batch_size,
        batch_interval=args.batch_interval,
        enable_compression=not args.no_compression
    )
    client.start()
    
    # Create and start the log generator
    generator = LogGenerator(client, logs_per_second=args.logs_per_second)
    generator.start()
    
    # Start metrics reporting thread
    metrics_thread = threading.Thread(
        target=print_metrics_periodically, 
        args=(client, 5.0),
        daemon=True
    )
    metrics_thread.start()
    
    # Start config update thread
    config_thread = threading.Thread(
        target=update_config_periodically,
        args=(client, 30.0),
        daemon=True
    )
    config_thread.start()
    
    try:
        if args.run_time > 0:
            logger.info(f"Demo will run for {args.run_time} seconds...")
            time.sleep(args.run_time)
        else:
            logger.info("Demo running indefinitely. Press Ctrl+C to stop.")
            while True:
                time.sleep(1)
                
    except KeyboardInterrupt:
        logger.info("Shutdown requested...")
    finally:
        # Stop the generator and client
        generator.stop()
        client.stop()
        
        # Print final metrics
        final_metrics = client.get_metrics()
        print("\n--- Final Metrics ---")
        for key, value in final_metrics.items():
            if isinstance(value, list):
                continue  # Skip list metrics for brevity
            elif isinstance(value, float):
                print(f"  {key}: {value:.4f}")
            else:
                print(f"  {key}: {value}")

if __name__ == "__main__":
    main()