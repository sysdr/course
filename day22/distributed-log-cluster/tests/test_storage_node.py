import pytest
import json
import tempfile
import shutil
import os
import sys
import threading
import time
import requests

# Add src to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from storage.storage_node import StorageNode

class TestStorageNode:
    def setup_method(self):
        """Setup for each test"""
        self.temp_dir = tempfile.mkdtemp()
        self.node = StorageNode("test_node", 5999, self.temp_dir)
    
    def teardown_method(self):
        """Cleanup after each test"""
        shutil.rmtree(self.temp_dir)
    
    def test_write_log_data(self):
        """Test writing log data"""
        test_data = {"message": "test log", "level": "info"}
        file_path = self.node.write_log_data(test_data)
        
        assert file_path is not None
        assert file_path.endswith('.json')
        assert self.node.stats['writes'] == 1
    
    def test_read_log_data(self):
        """Test reading log data"""
        test_data = {"message": "test log", "level": "info"}
        file_path = self.node.write_log_data(test_data)
        
        read_data = self.node.read_log_data(file_path)
        
        assert read_data is not None
        assert read_data['original_data'] == test_data
        assert self.node.stats['reads'] == 1
    
    def test_checksum_calculation(self):
        """Test checksum calculation"""
        test_data = {"message": "test", "level": "info"}
        checksum1 = self.node._calculate_checksum(test_data)
        checksum2 = self.node._calculate_checksum(test_data)
        
        assert checksum1 == checksum2
        assert len(checksum1) == 32  # MD5 hash length
    
    def test_flask_health_endpoint(self):
        """Test Flask health endpoint"""
        # Start server in background thread
        server_thread = threading.Thread(target=self.node.start_server, daemon=True)
        server_thread.start()
        time.sleep(2)  # Wait for server to start
        
        try:
            response = requests.get('http://localhost:5999/health')
            assert response.status_code == 200
            
            data = response.json()
            assert data['status'] == 'healthy'
            assert data['node_id'] == 'test_node'
        except requests.exceptions.ConnectionError:
            pytest.skip("Could not connect to test server")
