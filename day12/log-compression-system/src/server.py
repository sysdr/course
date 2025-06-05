import argparse
import logging
import signal
import sys
import time

# Import from local module
try:
    from log_receiver import LogReceiver
except ImportError:
    from src.log_receiver import LogReceiver

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Log Receiver Server')
    parser.add_argument('--host', default='0.0.0.0', help='Bind address')
    parser.add_argument('--port', type=int, default=5000, help='Port to listen on')
    args = parser.parse_args()
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Create and start the receiver
    receiver = LogReceiver(host=args.host, port=args.port)
    receiver.start()
    
    # Handle shutdown gracefully
    def signal_handler(sig, frame):
        logging.info("Shutting down...")
        receiver.stop()
        sys.exit(0)
        
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Print stats periodically
    try:
        while True:
            time.sleep(10)
            stats = receiver.get_stats()
            logging.info(f"Receiver stats: {stats}")
    except KeyboardInterrupt:
        logging.info("Shutting down...")
        receiver.stop()

if __name__ == "__main__":
    main()
