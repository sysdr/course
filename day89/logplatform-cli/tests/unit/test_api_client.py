import pytest
import responses
from logplatform_cli.utils.api_client import APIClient
from logplatform_cli.utils.exceptions import APIError, AuthenticationError

class TestAPIClient:
    
    @responses.activate
    def test_authentication_success(self):
        """Test successful authentication"""
        responses.add(
            responses.POST,
            'http://test.example.com/auth/login',
            json={'access_token': 'test_token', 'expires_at': '2025-12-31T23:59:59Z'},
            status=200
        )
        
        client = APIClient('http://test.example.com')
        result = client.authenticate('testuser', 'testpass')
        
        assert result['access_token'] == 'test_token'
        assert client.token == 'test_token'
    
    @responses.activate
    def test_authentication_failure(self):
        """Test authentication failure"""
        responses.add(
            responses.POST,
            'http://test.example.com/auth/login',
            json={'error': 'Invalid credentials'},
            status=401
        )
        
        client = APIClient('http://test.example.com')
        
        with pytest.raises(AuthenticationError):
            client.authenticate('testuser', 'wrongpass')
    
    @responses.activate
    def test_search_logs(self):
        """Test log search"""
        responses.add(
            responses.GET,
            'http://test.example.com/logs/search',
            json={
                'logs': [
                    {'id': 1, 'message': 'Test log', 'level': 'INFO'},
                    {'id': 2, 'message': 'Error log', 'level': 'ERROR'}
                ],
                'total': 2
            },
            status=200
        )
        
        client = APIClient('http://test.example.com', 'test_token')
        result = client.search_logs({'query': 'test'})
        
        assert len(result['logs']) == 2
        assert result['total'] == 2
