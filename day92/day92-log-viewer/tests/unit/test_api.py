import pytest
import json
from backend.app import create_app, db
from backend.app.models import LogEntry

@pytest.fixture
def app():
    app = create_app({'TESTING': True, 'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:'})
    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()

@pytest.fixture
def client(app):
    return app.test_client()

def test_health_endpoint(client):
    """Test health check endpoint"""
    response = client.get('/api/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'

def test_get_logs_empty(client):
    """Test getting logs when database is empty"""
    response = client.get('/api/logs')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['logs'] == []
    assert data['pagination']['total'] == 0

def test_init_sample_data(client):
    """Test initializing sample data"""
    response = client.post('/api/logs/init')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'count' in data
    assert data['count'] > 0

def test_get_logs_with_data(client):
    """Test getting logs after initializing data"""
    # First initialize data
    client.post('/api/logs/init')
    
    # Then get logs
    response = client.get('/api/logs')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert len(data['logs']) > 0
    assert data['pagination']['total'] > 0

def test_log_filtering(client):
    """Test log filtering functionality"""
    # Initialize data
    client.post('/api/logs/init')
    
    # Filter by level
    response = client.get('/api/logs?level=ERROR')
    assert response.status_code == 200
    data = json.loads(response.data)
    
    # All returned logs should be ERROR level
    for log in data['logs']:
        assert log['level'] == 'ERROR'

def test_get_stats(client):
    """Test getting log statistics"""
    # Initialize data
    client.post('/api/logs/init')
    
    response = client.get('/api/logs/stats')
    assert response.status_code == 200
    data = json.loads(response.data)
    
    assert 'total_logs' in data
    assert 'level_stats' in data
    assert 'service_stats' in data
    assert data['total_logs'] > 0
