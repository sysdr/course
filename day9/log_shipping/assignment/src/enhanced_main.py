import argparse
import signal
import sys
import threading
import time
from src.log_reader import LogReader
from src.enhanced_shipper import EnhancedLogShipper

def parse_args():
    parser = argparse.ArgumentParser(description='Ship logs to a remote TCP server with advanced features')
    parser.add_argument('--log-file', required=True, help='Path to the log file to ship')
    parser.add_argument('--server-host', default='localhost', help='Host of the TCP log server')
    parser.add_argument('--server-port', type=int, default=9000, help='Port of the TCP log server')
    parser.add_argument('--batch', action='store_true', help='Ship logs in batch mode instead of continuous')
    parser.add_argument('--buffer-size', type=int, default=1000, help='Maximum logs to keep in memory buffer')
    parser.add_argument('--persistence-file', default='undelivered_logs.json', 
                        help='File to store undelivered logs between restarts')
    parser.add_argument('--compress', action='store_true', default=True, help='Compress logs before sending')
    parser.add_argument('--no-compress', action='store_false', dest='compress', help='Disable log compression')
    parser.add_argument('--batch-size', type=int, default=10, help='Number of logs to batch together')
    parser.add_argument('--heartbeat-interval', type=int, default=30, 
                        help='Seconds between server heartbeat checks (0 to disable)')
    parser.add_argument('--metrics-interval', type=int, default=60, 
                        help='Seconds between metrics reports (0 to disable)')
    return parser.parse_args()

def main():
    args = parse_args()
    
    log_reader = LogReader(args.log_file)
    shipper = EnhancedLogShipper(
        args.server_host, 
        args.server_port, 
        log_reader,
        buffer_size=args.buffer_size,
        persistence_file=args.persistence_file,
        compress_logs=args.compress,
        batch_size=args.batch_size,
        heartbeat_interval=args.heartbeat_interval
    )
    
    # Set up metrics reporting
    stop_metrics = threading.Event()
    
    def metrics_reporter():
        while not stop_metrics.is_set():
            shipper.print_metrics()
            time.sleep(args.metrics_interval)
    
    if args.metrics_interval > 0:
        metrics_thread = threading.Thread(target=metrics_reporter)
        metrics_thread.daemon = True
        metrics_thread.start()
    
    # Set up graceful shutdown
    def handle_shutdown(sig, frame):
        print("\nShutting down log shipper...")
        stop_metrics.set()
        shipper.close()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)
    
    try:
        if args.batch:
            log_count = shipper.ship_logs_batch()
            print(f"Shipped {log_count} logs in batch mode")
            shipper.print_metrics()
        else:
            print(f"Starting continuous log shipping from {args.log_file} to {args.server_host}:{args.server_port}")
            print(f"Compression: {'Enabled' if args.compress else 'Disabled'}, Batch Size: {args.batch_size}")
            print("Press Ctrl+C to stop")
            shipper.ship_logs_continuously()
    except Exception as e:
        print(f"Error during log shipping: {e}")
    finally:
        stop_metrics.set()
        shipper.close()

if __name__ == "__main__":
    main()