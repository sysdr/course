#!/usr/bin/env python3
import sys
import os
import time
import requests
import json

# Add src to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from storage.cluster_manager import ClusterManager
from config.cluster_config import DEFAULT_CONFIG

def test_cluster_functionality():
    """Test cluster write, read, and replication"""
    print("Testing Cluster Functionality")
    print("=============================")
    
    base_url = f"http://localhost:{DEFAULT_CONFIG['nodes'][0]['port']}"
    
    # Test 1: Health checks
    print("\n1. Testing node health...")
    for node_config in DEFAULT_CONFIG['nodes']:
        try:
            response = requests.get(f"http://localhost:{node_config['port']}/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                print(f"   ✅ Node {node_config['id']}: {data['status']}")
            else:
                print(f"   ❌ Node {node_config['id']}: HTTP {response.status_code}")
        except Exception as e:
            print(f"   ❌ Node {node_config['id']}: {e}")
    
    # Test 2: Write logs
    print("\n2. Testing log writes...")
    test_logs = [
        {"message": "Test log entry 1", "level": "info", "source": "test_app"},
        {"message": "Error occurred", "level": "error", "source": "test_app"},
        {"message": "Debug information", "level": "debug", "source": "test_app"}
    ]
    
    written_files = []
    for i, log_data in enumerate(test_logs):
        try:
            response = requests.post(f"{base_url}/write", json=log_data, timeout=5)
            if response.status_code == 200:
                result = response.json()
                if result['success']:
                    written_files.append(result['file_path'])
                    print(f"   ✅ Log {i+1} written: {result['file_path']}")
                else:
                    print(f"   ❌ Log {i+1} write failed: {result.get('error', 'Unknown error')}")
            else:
                print(f"   ❌ Log {i+1} write failed: HTTP {response.status_code}")
        except Exception as e:
            print(f"   ❌ Log {i+1} write failed: {e}")
    
    # Wait for replication
    print("\n3. Waiting for replication...")
    time.sleep(3)
    
    # Test 3: Read logs from different nodes
    print("\n4. Testing log reads from different nodes...")
    for file_path in written_files[:2]:  # Test first 2 files
        for node_config in DEFAULT_CONFIG['nodes']:
            try:
                response = requests.get(
                    f"http://localhost:{node_config['port']}/read/{file_path}",
                    timeout=5
                )
                if response.status_code == 200:
                    result = response.json()
                    if result['success']:
                        print(f"   ✅ {node_config['id']}: Read {file_path}")
                    else:
                        print(f"   ❌ {node_config['id']}: Read failed - {result.get('error')}")
                else:
                    print(f"   ❌ {node_config['id']}: HTTP {response.status_code}")
            except Exception as e:
                print(f"   ❌ {node_config['id']}: {e}")
    
    # Test 4: Get statistics
    print("\n5. Cluster statistics...")
    for node_config in DEFAULT_CONFIG['nodes']:
        try:
            response = requests.get(f"http://localhost:{node_config['port']}/stats", timeout=5)
            if response.status_code == 200:
                stats = response.json()
                node_stats = stats['stats']
                print(f"   📊 {node_config['id']}: Writes={node_stats['writes']}, "
                      f"Reads={node_stats['reads']}, "
                      f"Replications={node_stats['replications_received']}")
            else:
                print(f"   ❌ {node_config['id']}: Could not get stats")
        except Exception as e:
            print(f"   ❌ {node_config['id']}: {e}")
    
    print("\n✅ Cluster functionality test completed!")

if __name__ == "__main__":
    # Wait a moment for cluster to be ready
    print("Waiting for cluster to be ready...")
    time.sleep(2)
    
    test_cluster_functionality()
