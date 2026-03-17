#!/usr/bin/env python3
"""Start a single storage node (for Docker or standalone). Uses env: NODE_ID, NODE_PORT, STORAGE_PATH."""
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from storage.storage_node import StorageNode


def main():
    node_id = os.environ.get('NODE_ID', 'storage_node_1')
    port = int(os.environ.get('NODE_PORT', '5001'))
    storage_path = os.environ.get('STORAGE_PATH', os.path.join('logs', 'node1'))

    os.makedirs(storage_path, exist_ok=True)
    node = StorageNode(node_id, port, storage_path)
    node.start_server()


if __name__ == "__main__":
    main()
