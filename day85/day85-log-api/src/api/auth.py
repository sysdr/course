from fastapi import HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials
import time
from typing import Dict, Any
from collections import defaultdict, deque

class RateLimiter:
    def __init__(self):
        self.requests = defaultdict(deque)  # user -> timestamps
        self.limits = {
            "developer": 1000,    # requests per hour
            "operations": 5000,
            "security": 10000,
            "default": 100
        }
    
    async def check_rate_limit(self, request: Request) -> Dict[str, Any]:
        """Check if request is within rate limits"""
        # Extract user from request (simplified)
        user_id = getattr(request.state, "user_id", "anonymous")
        user_role = getattr(request.state, "user_role", "default")
        
        current_time = time.time()
        hour_ago = current_time - 3600  # 1 hour
        
        # Clean old requests
        user_requests = self.requests[user_id]
        while user_requests and user_requests[0] < hour_ago:
            user_requests.popleft()
        
        # Check limit
        limit = self.limits.get(user_role, self.limits["default"])
        if len(user_requests) >= limit:
            raise HTTPException(
                status_code=429,
                detail={
                    "error": "Rate limit exceeded",
                    "limit": limit,
                    "retry_after": 3600
                }
            )
        
        # Add current request
        user_requests.append(current_time)
        
        return {
            "requests_remaining": limit - len(user_requests),
            "reset_time": hour_ago + 3600
        }

async def get_current_user(credentials: HTTPAuthorizationCredentials = None) -> Dict[str, Any]:
    """Extract current user from JWT token"""
    if not credentials:
        # For demo, allow anonymous access with limited permissions
        return {
            "username": "anonymous",
            "role": "default",
            "permissions": ["read"]
        }
    
    # Simple token parsing (in production, use proper JWT verification)
    token = credentials.credentials
    if token.startswith("token_"):
        parts = token.split("_")
        if len(parts) >= 2:
            username = parts[1]
            roles = {
                "developer": {"role": "developer", "permissions": ["read", "search"]},
                "operator": {"role": "operations", "permissions": ["read", "search", "stats"]},
                "security": {"role": "security", "permissions": ["read", "search", "stats", "admin"]}
            }
            user_info = roles.get(username, {"role": "default", "permissions": ["read"]})
            return {
                "username": username,
                **user_info
            }
    
    raise HTTPException(status_code=401, detail="Invalid token")
