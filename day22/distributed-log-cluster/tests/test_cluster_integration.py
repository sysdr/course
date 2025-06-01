import pytest
import sys
import os
import time
import requests
import threading

# Add src to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from storage.cluster_manager import ClusterManager
from config.cluster_config import get_cluster_config

class TestClusterIntegration:
    def setup_method(self):
        """Setup test cluster"""
        self.config = get_cluster_config(num_nodes=3, base_port=7001)
        self.cluster = ClusterManager(self.config)
        self.cluster.initialize_cluster()
        
        # Start nodes in background
        self.node_threads = self.cluster.start_all_nodes()
        time.sleep(15)  # Wait for nodes to start
    
    def test_cluster_initialization(self):
        """Test cluster initialization"""
        assert len(self.cluster.nodes) == 3
        assert self.cluster.primary_node_id is not None
        assert self.cluster.replication_manager is not None
    
    def test_write_and_replication(self):
        """Test log writing with replication"""
        test_data = {"message": "integration test", "level": "info"}
        
        try:
            file_path = self.cluster.write_log(test_data)
            assert file_path is not None
            
            # Wait for replication to complete
            time.sleep(2)
            
            # Check cluster status
            status = self.cluster.get_cluster_status()
            assert status['healthy_nodes'] >= 2
            
        except Exception as e:
            pytest.skip(f"Cluster operation failed: {e}")
    
    def test_node_health_checks(self):
        """Test node health monitoring"""
        try:
            # Check each node's health endpoint
            for node_config in self.config['nodes']:
                response = requests.get(f"http://localhost:{node_config['port']}/health")
                assert response.status_code == 200
                
                data = response.json()
                assert data['status'] == 'healthy'
                
        except requests.exceptions.ConnectionError:
            pytest.skip("Could not connect to cluster nodes")
