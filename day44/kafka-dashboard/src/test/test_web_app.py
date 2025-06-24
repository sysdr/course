import pytest
import json
from src.main.web_app import app

class TestWebApp:
    def setup_method(self):
        self.app = app.test_client()
        self.app.testing = True
        
    def test_index_route(self):
        """Test dashboard index page"""
        response = self.app.get('/')
        assert response.status_code == 200
        assert b'Real-time Log Dashboard' in response.data
        
    def test_metrics_api(self):
        """Test metrics API endpoint"""
        response = self.app.get('/api/metrics')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert isinstance(data, dict)
        
    def test_historical_api(self):
        """Test historical data API endpoint"""
        response = self.app.get('/api/historical')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'timestamps' in data
        assert 'error_rates' in data
