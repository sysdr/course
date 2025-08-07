import requests
import json
from typing import Dict, List, Any, Optional
from urllib.parse import urljoin, urlparse

from .exceptions import APIError, AuthenticationError

class APIClient:
    """API client for LogPlatform server communication"""
    
    def __init__(self, base_url: str, token: Optional[str] = None):
        self.base_url = base_url.rstrip('/')
        self.token = token
        self.session = requests.Session()
        
        if token:
            self.session.headers.update({'Authorization': f'Bearer {token}'})
    
    def _request(self, method: str, endpoint: str, **kwargs) -> Dict[str, Any]:
        """Make HTTP request to API"""
        url = urljoin(self.base_url + '/', endpoint.lstrip('/'))
        
        try:
            response = self.session.request(method, url, **kwargs)
            
            if response.status_code == 401:
                raise AuthenticationError("Authentication required or token expired")
            elif response.status_code >= 400:
                try:
                    error_data = response.json()
                    raise APIError(f"API error: {error_data.get('message', 'Unknown error')}")
                except ValueError:
                    raise APIError(f"HTTP {response.status_code}: {response.text}")
            
            return response.json() if response.content else {}
            
        except requests.exceptions.ConnectionError:
            raise APIError(f"Failed to connect to {self.base_url}")
        except requests.exceptions.Timeout:
            raise APIError("Request timeout")
        except requests.exceptions.RequestException as e:
            raise APIError(f"Request failed: {e}")
    
    def authenticate(self, username: str, password: str) -> Dict[str, Any]:
        """Authenticate with username/password"""
        data = {
            'username': username,
            'password': password
        }
        
        try:
            result = self._request('POST', '/auth/login', json=data)
            if 'access_token' in result:
                self.token = result['access_token']
                self.session.headers.update({'Authorization': f'Bearer {self.token}'})
            return result
        except APIError as e:
            raise AuthenticationError(str(e))
    
    def search_logs(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Search logs with filters"""
        return self._request('GET', '/logs/search', params=params)
    
    def export_logs(self, params: Dict[str, Any], format: str) -> str:
        """Export logs in specified format"""
        params['format'] = format
        response = self.session.get(
            urljoin(self.base_url + '/', 'logs/export'),
            params=params
        )
        return response.text
    
    def get_alerts(self, status: str = 'all') -> List[Dict[str, Any]]:
        """Get alerts by status"""
        params = {'status': status} if status != 'all' else {}
        result = self._request('GET', '/alerts', params=params)
        return result.get('alerts', [])
    
    def create_alert(self, alert_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new alert"""
        return self._request('POST', '/alerts', json=alert_data)
    
    def delete_alert(self, alert_id: int) -> None:
        """Delete an alert"""
        self._request('DELETE', f'/alerts/{alert_id}')
    
    def get_health_status(self) -> Dict[str, Any]:
        """Get platform health status"""
        return self._request('GET', '/admin/health')
    
    def get_platform_stats(self) -> Dict[str, Any]:
        """Get platform statistics"""
        return self._request('GET', '/admin/stats')
    
    def get_users(self) -> List[Dict[str, Any]]:
        """Get platform users"""
        result = self._request('GET', '/admin/users')
        return result.get('users', [])
