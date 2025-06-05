"""
Integration tests for the complete Avro log processing system
"""

import pytest
import requests
import time
import threading
import sys
import os
from pathlib import Path

# Add src to Python path
sys.path.append(str(Path(__file__).parent.parent.parent))

from src.web.app import app


class TestWebIntegration:
    """Test the web dashboard integration"""
    
    @pytest.fixture(scope="class")
    def client(self):
        """Create test client"""
        app.config['TESTING'] = True
        with app.test_client() as client:
            yield client
    
    def test_dashboard_loads(self, client):
        """Test that the main dashboard page loads"""
        response = client.get('/')
        assert response.status_code == 200
        assert b'Avro Schema Evolution Dashboard' in response.data
    
    def test_schema_info_api(self, client):
        """Test the schema information API endpoint"""
        response = client.get('/api/schema-info')
        assert response.status_code == 200
        
        data = response.get_json()
        assert data['status'] == 'success'
        assert 'available_schemas' in data['data']
        assert 'compatibility_matrix' in data['data']
    
    def test_compatibility_test_api(self, client):
        """Test the compatibility testing API"""
        test_data = {'schema_version': 'v2'}
        response = client.post('/api/test-compatibility', 
                              json=test_data,
                              content_type='application/json')
        
        assert response.status_code == 200
        data = response.get_json()
        assert data['status'] == 'success'
        assert 'sample_data' in data
        assert 'processing_summary' in data
    
    def test_sample_generation_api(self, client):
        """Test sample data generation for each version"""
        for version in ['v1', 'v2', 'v3']:
            response = client.get(f'/api/generate-sample/{version}')
            assert response.status_code == 200
            
            data = response.get_json()
            assert data['status'] == 'success'
            assert data['schema_version'] == version
            assert 'data' in data
            
            # Verify version-specific fields
            sample_data = data['data']
            if version == 'v1':
                assert 'request_id' not in sample_data
            elif version == 'v2':
                assert 'request_id' in sample_data
                assert 'duration_ms' not in sample_data
            elif version == 'v3':
                assert 'request_id' in sample_data
                assert 'duration_ms' in sample_data


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
