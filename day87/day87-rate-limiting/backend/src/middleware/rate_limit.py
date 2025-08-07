from fastapi import Request, Response, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
import time
import json
import structlog

logger = structlog.get_logger()

class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, rate_limiter, quota_manager, metrics):
        super().__init__(app)
        self.rate_limiter = rate_limiter
        self.quota_manager = quota_manager
        self.metrics = metrics
    
    async def dispatch(self, request: Request, call_next):
        # Extract user ID (in production, from JWT/auth)
        user_id = request.headers.get("X-User-ID", "anonymous")
        user_tier = request.headers.get("X-User-Tier", "free")
        
        # Skip rate limiting for health checks
        if request.url.path in ["/health", "/metrics"]:
            return await call_next(request)
        
        # Calculate request weight based on complexity
        weight = await self._calculate_request_weight(request)
        
        # Check rate limits
        rate_limiter = self.rate_limiter()
        allowed, rate_status = await rate_limiter.is_allowed(user_id, weight)
        
        if not allowed:
            logger.warning("Rate limit exceeded", user_id=user_id, weight=weight)
            response = Response(
                content=json.dumps({
                    "error": "Rate limit exceeded",
                    "details": rate_status,
                    "retry_after": rate_status["retry_after"]
                }),
                status_code=429,
                media_type="application/json"
            )
            response.headers["X-RateLimit-Remaining"] = str(rate_status["requests_remaining"])
            response.headers["X-RateLimit-Reset"] = str(rate_status["reset_time"])
            response.headers["Retry-After"] = str(rate_status["retry_after"])
            return response
        
        # Check quotas for GraphQL requests
        if "/graphql" in request.url.path:
            quota_manager = self.quota_manager()
            from quota.quota_manager import QuotaType
            
            quota_allowed, quota_status = await quota_manager.check_quota(
                user_id, QuotaType.REQUESTS, weight, user_tier
            )
            
            if not quota_allowed:
                logger.warning("Quota exceeded", user_id=user_id, quota_status=quota_status)
                return Response(
                    content=json.dumps({
                        "error": "Quota exceeded",
                        "details": quota_status,
                        "upgrade_url": "/pricing"
                    }),
                    status_code=402,  # Payment Required
                    media_type="application/json"
                )
        
        # Process request
        start_time = time.time()
        response = await call_next(request)
        duration = time.time() - start_time
        
        # Add rate limit headers
        response.headers["X-RateLimit-Remaining"] = str(rate_status["requests_remaining"])
        response.headers["X-RateLimit-Reset"] = str(rate_status["reset_time"])
        response.headers["X-Request-Weight"] = str(weight)
        
        # Record metrics
        metrics = self.metrics()
        await metrics.record_request(user_id, weight, duration, response.status_code)
        
        return response
    
    async def _calculate_request_weight(self, request: Request) -> int:
        """Calculate request complexity weight"""
        base_weight = 1
        
        # GraphQL requests need parsing for complexity
        if "/graphql" in request.url.path and request.method == "POST":
            try:
                body = await request.body()
                if body:
                    query_data = json.loads(body)
                    query = query_data.get("query", "")
                    
                    # Simple complexity analysis
                    weight = base_weight
                    weight += query.count("searchLogs") * 5  # Search operations are expensive
                    weight += query.count("{") * 2  # Nested fields
                    weight += len(query.split()) // 10  # Query length
                    
                    return min(weight, 50)  # Cap at 50x
            except:
                pass
        
        return base_weight
