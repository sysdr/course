import threading
import time
import requests
from .storage_node import StorageNode
from .replication_manager import ReplicationManager

class ClusterManager:
    def __init__(self, cluster_config):
        self.config = cluster_config
        self.nodes = {}
        self.primary_node_id = None
        self.replication_manager = None
        self.health_check_interval = 30
        self.monitoring = False
        
    def initialize_cluster(self):
        """Initialize all nodes in the cluster"""
        print("Initializing cluster...")
        
        # Create storage nodes
        for node_config in self.config['nodes']:
            node = StorageNode(
                node_config['id'],
                node_config['port'],
                node_config['storage_path']
            )
            self.nodes[node_config['id']] = node
            print(f"Created node {node_config['id']} on port {node_config['port']}")
        
        # Set primary node (first node in config)
        self.primary_node_id = self.config['nodes'][0]['id']
        print(f"Primary node: {self.primary_node_id}")
        
        # Setup replication
        self._setup_replication()
        
        # Start health monitoring
        self._start_health_monitoring()
        
        print("Cluster initialization complete")
    
    def start_all_nodes(self):
        """Start all nodes in separate threads"""
        threads = []
        for node_id, node in self.nodes.items():
            thread = threading.Thread(target=node.start_server, daemon=True)
            thread.start()
            threads.append(thread)
            time.sleep(1)  # Stagger startup
        
        return threads
    
    def write_log(self, log_data):
        """Write log with replication"""
        if not self.primary_node_id or self.primary_node_id not in self.nodes:
            raise Exception("No healthy primary node available")
        
        primary_node = self.nodes[self.primary_node_id]
        
        # Write to primary node
        file_path = primary_node.write_log_data(log_data)
        print(f"Written to primary node: {file_path}")
        
        # Trigger async replication
        if self.replication_manager:
            # Get the file data for replication
            file_data = primary_node.read_log_data(file_path)
            
            # Start replication in background thread
            replication_thread = threading.Thread(
                target=self._replicate_async,
                args=(file_path, file_data),
                daemon=True
            )
            replication_thread.start()
        
        return file_path
    
    def _setup_replication(self):
        """Setup replication between nodes"""
        if len(self.nodes) > 1:
            # Get target nodes (all except primary)
            target_nodes = [
                {
                    'host': 'localhost',
                    'port': self.config['nodes'][i]['port'],
                    'id': self.config['nodes'][i]['id']
                }
                for i, node_config in enumerate(self.config['nodes'])
                if node_config['id'] != self.primary_node_id
            ]
            
            primary_node = self.nodes[self.primary_node_id]
            self.replication_manager = ReplicationManager(
                primary_node, 
                target_nodes,
                replication_factor=min(2, len(target_nodes))
            )
            print(f"Replication setup: {len(target_nodes)} targets, factor: {self.replication_manager.replication_factor}")
    
    def _replicate_async(self, file_path, file_data):
        """Async replication wrapper"""
        if self.replication_manager:
            success = self.replication_manager.replicate_file_sync(file_path, file_data)
            if success:
                print(f"Replication completed for {file_path}")
            else:
                print(f"Replication failed for {file_path}")
    
    def _start_health_monitoring(self):
        """Start health monitoring for all nodes"""
        self.monitoring = True
        monitor_thread = threading.Thread(target=self._health_monitor_loop, daemon=True)
        monitor_thread.start()
        print("Health monitoring started")
    
    def _health_monitor_loop(self):
        """Health monitoring loop"""
        while self.monitoring:
            for node_id, node in self.nodes.items():
                try:
                    response = requests.get(
                        f"http://localhost:{node.port}/health",
                        timeout=5
                    )
                    if response.status_code == 200:
                        node.is_healthy = True
                    else:
                        node.is_healthy = False
                        print(f"Node {node_id} health check failed: HTTP {response.status_code}")
                except Exception as e:
                    node.is_healthy = False
                    print(f"Node {node_id} health check failed: {e}")
            
            time.sleep(self.health_check_interval)
    
    def get_cluster_status(self):
        """Get overall cluster status"""
        status = {
            'primary_node': self.primary_node_id,
            'total_nodes': len(self.nodes),
            'healthy_nodes': sum(1 for node in self.nodes.values() if node.is_healthy),
            'nodes': {}
        }
        
        for node_id, node in self.nodes.items():
            status['nodes'][node_id] = {
                'healthy': node.is_healthy,
                'port': node.port,
                'stats': node.stats
            }
        
        if self.replication_manager:
            status['replication_stats'] = self.replication_manager.get_stats()
        
        return status
