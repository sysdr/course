#!/usr/bin/env python3
import sys
import os
import time
import signal

# Add src to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from storage.cluster_manager import ClusterManager
from config.cluster_config import DEFAULT_CONFIG

def signal_handler(sig, frame):
    print('\nShutting down cluster...')
    sys.exit(0)

def main():
    print("Starting Distributed Log Storage Cluster")
    print("========================================")
    
    # Initialize cluster
    cluster = ClusterManager(DEFAULT_CONFIG)
    cluster.initialize_cluster()
    
    # Start all nodes
    print("Starting cluster nodes...")
    node_threads = cluster.start_all_nodes()
    
    # Wait for nodes to start
    time.sleep(3)
    
    # Print cluster status
    status = cluster.get_cluster_status()
    print(f"\nCluster Status:")
    print(f"Primary Node: {status['primary_node']}")
    print(f"Total Nodes: {status['total_nodes']}")
    print(f"Healthy Nodes: {status['healthy_nodes']}")
    
    for node_id, node_info in status['nodes'].items():
        health_status = "🟢 HEALTHY" if node_info['healthy'] else "🔴 UNHEALTHY"
        print(f"  {node_id}: {health_status} (Port: {node_info['port']})")
    
    print(f"\nCluster is running. Access nodes at:")
    for node_config in DEFAULT_CONFIG['nodes']:
        print(f"  http://localhost:{node_config['port']}/health")
    
    print(f"\nPress Ctrl+C to stop the cluster")
    
    # Setup signal handler
    signal.signal(signal.SIGINT, signal_handler)
    
    # Keep main thread alive
    try:
        while True:
            time.sleep(10)
            # Print periodic status update
            status = cluster.get_cluster_status()
            print(f"\n[{time.strftime('%H:%M:%S')}] Healthy nodes: {status['healthy_nodes']}/{status['total_nodes']}")
    except KeyboardInterrupt:
        print("\nShutting down cluster...")

if __name__ == "__main__":
    main()
