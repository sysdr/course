import time
import yaml
import threading
from typing import Dict, List
from consistent_hash import ConsistentHashRing
from storage_node import StorageNode

class ClusterCoordinator:
    """
    Coordinates the distributed storage cluster with consistent hashing.
    Manages node addition, removal, and rebalancing operations.
    """
    
    def __init__(self, config_path: str):
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        # Initialize consistent hash ring
        replica_count = self.config['cluster']['replica_count']
        self.hash_ring = ConsistentHashRing(replica_count)
        
        # Storage nodes
        self.nodes: Dict[str, StorageNode] = {}
        
        # Coordinator state
        self.is_running = False
        self.rebalance_lock = threading.Lock()
        
        print(f"Cluster coordinator initialized with {replica_count} virtual nodes per physical node")
    
    def start_cluster(self):
        """Start all storage nodes and build the hash ring."""
        print("🚀 Starting storage cluster...")
        
        # Initialize storage nodes
        for node_config in self.config['storage_nodes']:
            node = StorageNode(
                node_id=node_config['id'],
                data_dir=node_config['data_dir'],
                port=node_config['port']
            )
            
            # Create data directory
            import os
            os.makedirs(node_config['data_dir'], exist_ok=True)
            
            self.nodes[node_config['id']] = node
            
            # Add to hash ring
            affected_ranges = self.hash_ring.add_node(node_config['id'])
            node.set_hash_ring(self.hash_ring)
            
            print(f"✅ Started node {node_config['id']} at port {node_config['port']}")
            print(f"   Data directory: {node_config['data_dir']}")
            print(f"   Affected ranges: {len(affected_ranges)}")
        
        self.is_running = True
        print(f"\n🎉 Cluster started with {len(self.nodes)} nodes")
        self._print_cluster_status()
    
    def add_node(self, node_id: str, host: str, port: int, data_dir: str):
        """Dynamically add a new node to the cluster."""
        if node_id in self.nodes:
            print(f"❌ Node {node_id} already exists")
            return
        
        print(f"➕ Adding new node {node_id}...")
        
        # Create and start the new node
        new_node = StorageNode(node_id, data_dir, port)
        import os
        os.makedirs(data_dir, exist_ok=True)
        
        # Add to hash ring and get affected ranges
        affected_ranges = self.hash_ring.add_node(node_id)
        new_node.set_hash_ring(self.hash_ring)
        
        # Update hash ring for all existing nodes
        for node in self.nodes.values():
            node.set_hash_ring(self.hash_ring)
        
        self.nodes[node_id] = new_node
        
        print(f"✅ Node {node_id} added successfully")
        print(f"   Affected ranges: {len(affected_ranges)}")
        
        # Trigger rebalancing
        self._rebalance_cluster()
        
        self._print_cluster_status()
    
    def remove_node(self, node_id: str):
        """Remove a node from the cluster."""
        if node_id not in self.nodes:
            print(f"❌ Node {node_id} not found")
            return
        
        print(f"➖ Removing node {node_id}...")
        
        # Get data that needs to be redistributed
        node_to_remove = self.nodes[node_id]
        
        # Remove from hash ring
        affected_ranges = self.hash_ring.remove_node(node_id)
        
        # Update hash ring for remaining nodes
        for node in self.nodes.values():
            if node.node_id != node_id:
                node.set_hash_ring(self.hash_ring)
        
        # Redistribute data from removed node
        self._redistribute_node_data(node_to_remove)
        
        # Remove node
        del self.nodes[node_id]
        
        print(f"✅ Node {node_id} removed successfully")
        print(f"   Redistributed ranges: {len(affected_ranges)}")
        
        self._print_cluster_status()
    
    def _redistribute_node_data(self, removed_node: StorageNode):
        """Redistribute data from a removed node to appropriate nodes."""
        with self.rebalance_lock:
            print(f"🔄 Redistributing data from {removed_node.node_id}...")
            
            # Get all partitions from the removed node
            all_partitions = list(removed_node.partitions.keys())
            transferred_count = 0
            
            for partition_key in all_partitions:
                # Find new target node for this partition
                target_node_id = self.hash_ring.get_node(partition_key)
                
                if target_node_id and target_node_id in self.nodes:
                    target_node = self.nodes[target_node_id]
                    logs = removed_node.partitions[partition_key]
                    
                    # Transfer all logs in this partition
                    for log in logs:
                        if target_node.store_log(log):
                            transferred_count += 1
            
            print(f"✅ Redistributed {transferred_count} logs")
    
    def _rebalance_cluster(self):
        """Rebalance data across all nodes in the cluster."""
        with self.rebalance_lock:
            print("🔄 Rebalancing cluster...")
            rebalance_count = 0
            
            # Check each node's data and move misplaced partitions
            for node in list(self.nodes.values()):
                partitions_to_move = []
                
                # Find partitions that should move to other nodes
                for partition_key in list(node.partitions.keys()):
                    correct_node_id = self.hash_ring.get_node(partition_key)
                    
                    if correct_node_id != node.node_id and correct_node_id in self.nodes:
                        partitions_to_move.append(partition_key)
                
                # Move misplaced partitions
                for partition_key in partitions_to_move:
                    correct_node_id = self.hash_ring.get_node(partition_key)
                    target_node = self.nodes[correct_node_id]
                    
                    # Transfer partition
                    logs = node.partitions[partition_key]
                    for log in logs:
                        if target_node.store_log(log):
                            rebalance_count += 1
                    
                    # Remove from source node
                    del node.partitions[partition_key]
            
            print(f"✅ Rebalanced {rebalance_count} logs")
    
    def store_log(self, log_entry: dict) -> bool:
        """Store a log entry in the appropriate node."""
        if not self.nodes:
            return False
        
        # Add timestamp if not present
        if 'timestamp' not in log_entry:
            log_entry['timestamp'] = time.time()
        
        # Determine target node using consistent hashing
        partition_key = self._get_partition_key(log_entry)
        target_node_id = self.hash_ring.get_node(partition_key)
        
        if target_node_id in self.nodes:
            return self.nodes[target_node_id].store_log(log_entry)
        
        return False
    
    def _get_partition_key(self, log_entry: dict) -> str:
        """Generate partition key (same logic as storage nodes)."""
        from datetime import datetime
        
        timestamp = log_entry.get('timestamp', time.time())
        source = log_entry.get('source', 'unknown')
        
        hour = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d-%H')
        return f"{source}_{hour}"
    
    def query_logs(self, source: str = None, start_time: float = None, 
                   end_time: float = None) -> List[dict]:
        """Query logs across all nodes."""
        all_results = []
        
        for node in self.nodes.values():
            results = node.query_logs(source, start_time, end_time)
            all_results.extend(results)
        
        # Sort by timestamp
        all_results.sort(key=lambda x: x.get('timestamp', 0))
        return all_results
    
    def _print_cluster_status(self):
        """Print comprehensive cluster status."""
        print("\n📊 Cluster Status:")
        print("=" * 50)
        
        # Ring status
        ring_state = self.hash_ring.get_ring_state()
        print(f"Nodes: {len(ring_state['nodes'])}")
        print(f"Virtual nodes: {ring_state['virtual_nodes']}")
        print(f"Replica count: {ring_state['replica_count']}")
        
        # Load distribution
        print("\n📈 Load Distribution:")
        for node_id, percentage in ring_state['load_distribution'].items():
            print(f"  {node_id}: {percentage:.2f}%")
        
        # Node statistics
        print("\n💾 Node Statistics:")
        for node_id, node in self.nodes.items():
            stats = node.get_node_stats()
            print(f"  {node_id}:")
            print(f"    Partitions: {stats['partition_count']}")
            print(f"    Total logs: {stats['total_logs']}")
            print(f"    Disk usage: {stats['disk_usage_mb']:.2f} MB")
        
        print("=" * 50)
    
    def get_cluster_metrics(self) -> dict:
        """Get comprehensive cluster metrics."""
        total_logs = 0
        total_partitions = 0
        total_disk_usage = 0
        
        node_stats = {}
        for node_id, node in self.nodes.items():
            stats = node.get_node_stats()
            node_stats[node_id] = stats
            total_logs += stats['total_logs']
            total_partitions += stats['partition_count']
            total_disk_usage += stats['disk_usage_mb']
        
        return {
            'cluster_summary': {
                'total_nodes': len(self.nodes),
                'total_logs': total_logs,
                'total_partitions': total_partitions,
                'total_disk_usage_mb': total_disk_usage
            },
            'ring_state': self.hash_ring.get_ring_state(),
            'node_stats': node_stats
        }

# Test cluster coordinator
if __name__ == "__main__":
    coordinator = ClusterCoordinator("config/cluster.yaml")
    coordinator.start_cluster()
    
    # Test storing some logs
    test_logs = [
        {'id': 'log-1', 'source': 'web-server', 'level': 'INFO', 'message': 'User login'},
        {'id': 'log-2', 'source': 'database', 'level': 'ERROR', 'message': 'Connection timeout'},
        {'id': 'log-3', 'source': 'api-gateway', 'level': 'DEBUG', 'message': 'Request processed'},
        {'id': 'log-4', 'source': 'web-server', 'level': 'WARN', 'message': 'High memory usage'},
        {'id': 'log-5', 'source': 'database', 'level': 'INFO', 'message': 'Query executed'}
    ]
    
    print("\n📝 Storing test logs...")
    for log in test_logs:
        success = coordinator.store_log(log)
        print(f"  Log {log['id']}: {'✅ Stored' if success else '❌ Failed'}")
    
    # Test adding a new node
    print("\n➕ Testing node addition...")
    coordinator.add_node("node-4", "localhost", 8004, "./data/node4")
    
    # Query logs
    print("\n🔍 Querying all logs...")
    all_logs = coordinator.query_logs()
    print(f"Total logs found: {len(all_logs)}")
    
    print("\n📊 Final cluster metrics:")
    import json
    metrics = coordinator.get_cluster_metrics()
    print(json.dumps(metrics, indent=2))
