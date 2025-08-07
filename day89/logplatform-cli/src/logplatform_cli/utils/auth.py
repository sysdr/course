import keyring
from .api_client import APIClient
from .exceptions import AuthenticationError

def get_authenticated_client(config) -> APIClient:
    """Get authenticated API client"""
    username = config.get('username')
    server_url = config.get('server_url')
    
    if not username:
        raise AuthenticationError("Not logged in. Run 'logplatform auth login' first.")
    
    if not server_url:
        raise AuthenticationError("Server URL not configured. Run 'logplatform config init' first.")
    
    try:
        token = keyring.get_password("logplatform-cli", username)
        if not token:
            raise AuthenticationError("No valid token found. Please login again.")
        
        return APIClient(server_url, token)
    except Exception as e:
        raise AuthenticationError(f"Failed to get authentication token: {e}")
