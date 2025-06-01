import argparse
import logging
import signal
import sys
import time
import random

# Import from local module
try:
    from log_shipper import LogShipper
except ImportError:
    from src.log_shipper import LogShipper

def generate_log_entry():
    """Generate a sample log entry with typical fields."""
    log_levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
    services = ['api', 'auth', 'database', 'frontend', 'cache']
    actions = ['request', 'response', 'process', 'compute', 'validate']
    
    return {
        'timestamp': time.time(),
        'level': random.choice(log_levels),
        'service': random.choice(services),
        'action': random.choice(actions),
        'duration_ms': random.randint(1, 1000),
        'status': 200 if random.random() > 0.1 else 500,
        'message': f"Processing request {random.randint(1000, 9999)}",
        'user_id': f"user_{random.randint(1, 1000)}",
        'request_id': f"{random.randint(10000, 99999)}-{random.randint(10000, 99999)}"
    }

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Log Shipper Client')
    parser.add_argument('--server', default='localhost', help='Server hostname')
    parser.add_argument('--port', type=int, default=5000, help='Server port')
    parser.add_argument('--batch-size', type=int, default=100, help='Batch size')
    parser.add_argument('--batch-interval', type=int, default=5, help='Batch interval in seconds')
    parser.add_argument('--compression', choices=['none', 'gzip', 'zlib'], default='gzip', help='Compression algorithm')
    parser.add_argument('--level', type=int, default=6, help='Compression level (1-9)')
    parser.add_argument('--rate', type=float, default=10.0, help='Logs per second to generate')
    args = parser.parse_args()
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Create the log shipper
    shipper = LogShipper(
        server_host=args.server,
        server_port=args.port,
        batch_size=args.batch_size,
        batch_interval=args.batch_interval,
        compression_enabled=(args.compression != 'none'),
        compression_algorithm=args.compression if args.compression != 'none' else 'gzip',
        compression_level=args.level
    )
    
    # Handle shutdown gracefully
    def signal_handler(sig, frame):
        logging.info("Shutting down...")
        shipper.shutdown()
        sys.exit(0)
        
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Generate and ship logs
    count = 0
    start_time = time.time()
    last_stats_time = start_time
    
    try:
        while True:
            # Generate and ship a log entry
            log_entry = generate_log_entry()
            shipper.ship_log(log_entry)
            count += 1
            
            # Print stats every 1000 logs
            if count % 1000 == 0:
                current_time = time.time()
                elapsed = current_time - last_stats_time
                rate = 1000 / elapsed if elapsed > 0 else 0
                
                stats = shipper.get_stats()
                logging.info(f"Shipped {count} logs ({rate:.1f}/sec). Stats: {stats}")
                
                last_stats_time = current_time
                
            # Control the rate
            sleep_time = 1.0 / args.rate
            time.sleep(sleep_time)
            
    except KeyboardInterrupt:
        logging.info("Shutting down...")
    finally:
        shipper.shutdown()
        final_stats = shipper.get_stats()
        
        # Calculate overall statistics
        total_time = time.time() - start_time
        avg_rate = count / total_time if total_time > 0 else 0
        
        logging.info(f"Run complete. Shipped {count} logs in {total_time:.1f} seconds ({avg_rate:.1f}/sec)")
        logging.info(f"Final stats: {final_stats}")

if __name__ == "__main__":
    main()
