#!/usr/bin/env python3
"""
Load testing script for UDP log shipping system
"""

import sys
import os
import time
import threading
import argparse
import statistics

# Add the src directory to the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from client.udp_client import UDPLogClient


def client_worker(server_host, server_port, app_name, count, interval, results):
    """Worker function for client threads."""
    client = UDPLogClient(server_host, server_port, app_name)
    
    start_time = time.time()
    client.generate_sample_logs(count, interval)
    elapsed = time.time() - start_time
    
    # Store results
    results.append({
        'app_name': app_name,
        'count': client.sent_count,
        'elapsed': elapsed,
        'rate': client.sent_count / elapsed if elapsed > 0 else 0,
        'ack_count': len(client.error_acks)
    })
    
    client.close()


def run_load_test(server_host, server_port, total_logs, rate, num_clients=1):
    """Run a load test with the specified parameters."""
    print(f"Starting load test with {num_clients} clients")
    print(f"Target: {total_logs} total logs at {rate} logs/second")
    
    # Calculate logs per client and interval
    logs_per_client = total_logs // num_clients
    interval = 1.0 / (rate / num_clients) if rate > 0 else 0
    
    # Create and start client threads
    threads = []
    results = []
    start_time = time.time()
    
    for i in range(num_clients):
        app_name = f"load-test-{i}"
        thread = threading.Thread(
            target=client_worker,
            args=(server_host, server_port, app_name, logs_per_client, interval, results)
        )
        thread.start()
        threads.append(thread)
        
    # Wait for all threads to complete
    for thread in threads:
        thread.join()
        
    # Calculate overall results
    total_elapsed = time.time() - start_time
    total_sent = sum(r['count'] for r in results)
    rates = [r['rate'] for r in results]
    
    print("\nLoad Test Results:")
    print("-----------------")
    print(f"Total logs sent: {total_sent}")
    print(f"Total time: {total_elapsed:.2f} seconds")
    print(f"Overall rate: {total_sent / total_elapsed:.2f} logs/second")
    print(f"Target rate: {rate} logs/second")
    print(f"Client rates: min={min(rates):.2f}, max={max(rates):.2f}, avg={statistics.mean(rates):.2f}, median={statistics.median(rates):.2f}")
    print(f"Total acknowledgments received: {sum(r['ack_count'] for r in results)}")
    
    # Determine if the test met its target
    success = total_sent / total_elapsed >= rate * 0.9  # Within 90% of target
    print(f"\nTarget achieved: {'YES' if success else 'NO'}")
    
    return success


def main():
    """Parse command line arguments and run the load test."""
    parser = argparse.ArgumentParser(description='UDP Log Shipping Load Test')
    parser.add_argument('--server', default='127.0.0.1', help='Log server host')
    parser.add_argument('--port', type=int, default=9999, help='Log server port')
    parser.add_argument('--logs', type=int, default=10000, help='Total number of logs to send')
    parser.add_argument('--rate', type=int, default=1000, help='Target logs per second')
    parser.add_argument('--clients', type=int, default=4, help='Number of client threads')
    args = parser.parse_args()
    
    success = run_load_test(args.server, args.port, args.logs, args.rate, args.clients)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()