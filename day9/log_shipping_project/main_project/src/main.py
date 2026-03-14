import argparse
import signal
import sys
from src.log_reader import LogReader
from src.log_shipper import LogShipper

def parse_args():
    parser = argparse.ArgumentParser(description='Ship logs to a remote TCP server')
    parser.add_argument('--log-file', required=True, help='Path to the log file to ship')
    parser.add_argument('--server-host', default='localhost', help='Host of the TCP log server')
    parser.add_argument('--server-port', type=int, default=9000, help='Port of the TCP log server')
    parser.add_argument('--batch', action='store_true', help='Ship logs in batch mode instead of continuous')
    return parser.parse_args()

def main():
    args = parse_args()
    
    log_reader = LogReader(args.log_file)
    shipper = LogShipper(args.server_host, args.server_port, log_reader)
    
    # Set up graceful shutdown
    def handle_shutdown(sig, frame):
        print("\nShutting down log shipper...")
        shipper.close()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)
    
    try:
        if args.batch:
            log_count = shipper.ship_logs_batch()
            print(f"Shipped {log_count} logs in batch mode")
        else:
            print(f"Starting continuous log shipping from {args.log_file} to {args.server_host}:{args.server_port}")
            print("Press Ctrl+C to stop")
            shipper.ship_logs_continuously()
    except Exception as e:
        print(f"Error during log shipping: {e}")
    finally:
        shipper.close()

if __name__ == "__main__":
    main()
