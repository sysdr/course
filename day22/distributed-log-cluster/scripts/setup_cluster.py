#!/usr/bin/env python3
"""Setup and start cluster with configurable number of nodes (article: setup_cluster.py)."""
import sys
import os
import argparse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from storage.cluster_manager import ClusterManager
from config.cluster_config import get_cluster_config


def main():
    parser = argparse.ArgumentParser(description='Start distributed log cluster')
    parser.add_argument('--nodes', type=int, default=3, help='Number of nodes')
    parser.add_argument('--base-port', type=int, default=5001, help='Base port for nodes')
    args = parser.parse_args()

    print(f"Starting cluster with {args.nodes} nodes...")
    config = get_cluster_config(num_nodes=args.nodes, base_port=args.base_port)
    cluster = ClusterManager(config)
    cluster.initialize_cluster()
    cluster.start_all_nodes()

    print(f"Replication factor: {config['replication_factor']}")
    print(f"Primary node: {config['nodes'][0]['id']}")
    for node_config in config['nodes']:
        print(f"Node {node_config['id']} started on port {node_config['port']}")
    print("Cluster initialization complete")

    import time
    import signal

    def shutdown(sig, frame):
        print("\nShutting down...")
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    try:
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
