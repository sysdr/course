#!/usr/bin/env python3
import sys
import os

# Add the project root to Python path
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, project_root)

from src.partition_server import PartitionServer

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python run_partition_server.py <partition_id> <port>")
        sys.exit(1)
    
    partition_id = sys.argv[1]
    port = int(sys.argv[2])
    
    server = PartitionServer(partition_id, port)
    server.run()
