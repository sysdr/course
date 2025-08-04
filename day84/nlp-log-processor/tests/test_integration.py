import pytest
import requests
import json
import time
import subprocess
import os

class TestIntegration:
    
    @pytest.fixture(scope="class")
    def server_process(self):
        """Start the Flask server for integration testing"""
        env = os.environ.copy()
        env['FLASK_ENV'] = 'testing'
        
        process = subprocess.Popen(
            ['python', 'src/api/server.py'],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        # Wait for server to start
        time.sleep(5)
        
        yield process
        
        # Cleanup
        process.terminate()
        process.wait()
    
    def test_health_endpoint(self, server_process):
        """Test health check endpoint"""
        response = requests.get('http://localhost:5000/api/health')
        assert response.status_code == 200
        
        data = response.json()
        assert 'status' in data
        assert data['status'] == 'healthy'
    
    def test_analyze_endpoint(self, server_process):
        """Test single log analysis endpoint"""
        test_message = "ERROR: Database connection failed to server 192.168.1.100"
        
        response = requests.post(
            'http://localhost:5000/api/analyze',
            json={'message': test_message}
        )
        
        assert response.status_code == 200
        
        data = response.json()
        assert 'nlp_analysis' in data
        assert 'entities' in data['nlp_analysis']
        assert 'intent' in data['nlp_analysis']
        assert data['nlp_analysis']['intent'] == 'error'
    
    def test_process_endpoint(self, server_process):
        """Test batch processing endpoint"""
        test_logs = [
            {'message': 'INFO: User logged in successfully'},
            {'message': 'ERROR: Connection timeout'},
            {'message': 'WARNING: High memory usage'}
        ]
        
        response = requests.post(
            'http://localhost:5000/api/process',
            json={'logs': test_logs}
        )
        
        assert response.status_code == 200
        
        data = response.json()
        assert 'processed_logs' in data
        assert 'summary' in data
        assert len(data['processed_logs']) == 3
    
    def test_stats_endpoint(self, server_process):
        """Test statistics endpoint"""
        response = requests.get('http://localhost:5000/api/stats')
        assert response.status_code == 200
        
        data = response.json()
        assert 'processed_count' in data
        assert 'patterns_loaded' in data
