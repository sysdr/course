import os
import json
import time
import threading
from typing import Dict, List, Optional
from consistent_hash import ConsistentHashRing
from datetime import datetime

class StorageNode:
    """
    A storage node that participates in consistent hashing cluster.
    Integrates with the partitioning system from Day 23.
    """
    
    def __init__(self, node_id: str, data_dir: str, port: int):
        self.node_id = node_id
        self.data_dir = data_dir
        self.port = port
        
        # Ensure data directory exists
        os.makedirs(data_dir, exist_ok=True)
        
        # Storage for log entries organized by partition
        self.partitions: Dict[str, List[dict]] = {}
        
        # Consistent hash ring (will be set by cluster coordinator)
        self.hash_ring: Optional[ConsistentHashRing] = None
        
        # Metrics
        self.metrics = {
            'logs_stored': 0,
            'logs_retrieved': 0,
            'rebalance_operations': 0,
            'disk_usage_bytes': 0
        }
        
        # Thread-safe lock for operations
        self.lock = threading.RLock()
    
    def set_hash_ring(self, hash_ring: ConsistentHashRing):
        """Set the consistent hash ring for this node."""
        with self.lock:
            self.hash_ring = hash_ring
    
    def _get_partition_key(self, log_entry: dict) -> str:
        """Generate partition key based on source and time (from Day 23)."""
        timestamp = log_entry.get('timestamp', time.time())
        source = log_entry.get('source', 'unknown')
        
        # Create hourly partitions
        hour = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d-%H')
        return f"{source}_{hour}"
    
    def should_store_locally(self, log_entry: dict) -> bool:
        """Check if this node should store the given log entry."""
        if not self.hash_ring:
            return True  # Default to storing locally if no ring
        
        partition_key = self._get_partition_key(log_entry)
        target_node = self.hash_ring.get_node(partition_key)
        return target_node == self.node_id
    
    def store_log(self, log_entry: dict) -> bool:
        """Store a log entry if it belongs to this node."""
        if not self.should_store_locally(log_entry):
            return False  # Should be stored on different node
        
        with self.lock:
            partition_key = self._get_partition_key(log_entry)
            
            if partition_key not in self.partitions:
                self.partitions[partition_key] = []
            
            # Add metadata
            log_entry['stored_at'] = time.time()
            log_entry['node_id'] = self.node_id
            
            self.partitions[partition_key].append(log_entry)
            self.metrics['logs_stored'] += 1
            
            # Persist to disk
            self._persist_partition(partition_key)
            
            return True
    
    def _persist_partition(self, partition_key: str):
        """Persist a partition to disk."""
        partition_file = os.path.join(self.data_dir, f"{partition_key}.json")
        
        with open(partition_file, 'w') as f:
            json.dump(self.partitions[partition_key], f, indent=2)
        
        # Update disk usage
        self.metrics['disk_usage_bytes'] = self._calculate_disk_usage()
    
    def _calculate_disk_usage(self) -> int:
        """Calculate total disk usage for this node."""
        total_size = 0
        for root, dirs, files in os.walk(self.data_dir):
            for file in files:
                file_path = os.path.join(root, file)
                total_size += os.path.getsize(file_path)
        return total_size
    
    def query_logs(self, source: str = None, start_time: float = None, 
                   end_time: float = None) -> List[dict]:
        """Query logs with optional filtering."""
        with self.lock:
            results = []
            
            for partition_key, logs in self.partitions.items():
                # Check if partition matches source filter
                if source and not partition_key.startswith(source):
                    continue
                
                for log in logs:
                    # Apply time filters
                    log_time = log.get('timestamp', 0)
                    
                    if start_time and log_time < start_time:
                        continue
                    if end_time and log_time > end_time:
                        continue
                    
                    results.append(log)
            
            self.metrics['logs_retrieved'] += len(results)
            return results
    
    def get_partitions_in_range(self, start_hash: int, end_hash: int) -> Dict[str, List[dict]]:
        """Get all partitions whose keys hash to the given range."""
        if not self.hash_ring:
            return {}
        
        matching_partitions = {}
        
        for partition_key, logs in self.partitions.items():
            key_hash = self.hash_ring._hash(partition_key)
            
            # Check if hash falls in range (handling wrap-around)
            if start_hash <= end_hash:
                if start_hash <= key_hash < end_hash:
                    matching_partitions[partition_key] = logs
            else:
                # Wrap-around case
                if key_hash >= start_hash or key_hash < end_hash:
                    matching_partitions[partition_key] = logs
        
        return matching_partitions
    
    def transfer_partitions(self, target_node: 'StorageNode', partition_keys: List[str]):
        """Transfer specific partitions to another node."""
        with self.lock:
            transferred_count = 0
            
            for partition_key in partition_keys:
                if partition_key in self.partitions:
                    logs = self.partitions[partition_key]
                    
                    # Transfer each log to target node
                    for log in logs:
                        if target_node.store_log(log):
                            transferred_count += 1
                    
                    # Remove from this node
                    del self.partitions[partition_key]
                    
                    # Remove partition file
                    partition_file = os.path.join(self.data_dir, f"{partition_key}.json")
                    if os.path.exists(partition_file):
                        os.remove(partition_file)
            
            self.metrics['rebalance_operations'] += 1
            print(f"Transferred {transferred_count} logs to {target_node.node_id}")
    
    def get_node_stats(self) -> dict:
        """Get comprehensive node statistics."""
        with self.lock:
            partition_count = len(self.partitions)
            total_logs = sum(len(logs) for logs in self.partitions.values())
            
            return {
                'node_id': self.node_id,
                'partition_count': partition_count,
                'total_logs': total_logs,
                'metrics': self.metrics,
                'disk_usage_mb': self.metrics['disk_usage_bytes'] / (1024 * 1024),
                'partitions': list(self.partitions.keys())
            }

# Test storage node
if __name__ == "__main__":
    # Create test node
    node = StorageNode("test-node", "./test_data", 8001)
    
    # Create test logs
    test_logs = [
        {'id': 'log-1', 'source': 'web-server', 'level': 'INFO', 'message': 'User login', 'timestamp': time.time()},
        {'id': 'log-2', 'source': 'database', 'level': 'ERROR', 'message': 'Connection timeout', 'timestamp': time.time()},
        {'id': 'log-3', 'source': 'web-server', 'level': 'DEBUG', 'message': 'Request processed', 'timestamp': time.time()}
    ]
    
    # Store logs
    for log in test_logs:
        node.store_log(log)
    
    print(f"Node stats: {json.dumps(node.get_node_stats(), indent=2)}")
