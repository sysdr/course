from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import strawberry
from strawberry.fastapi import GraphQLRouter
import redis.asyncio as redis
import structlog
import asyncio
from contextlib import asynccontextmanager

from rate_limiter.sliding_window import SlidingWindowLimiter
from quota.quota_manager import QuotaManager
from middleware.rate_limit import RateLimitMiddleware
from utils.metrics import MetricsCollector

logger = structlog.get_logger()

# Global instances
redis_client = None
rate_limiter = None
quota_manager = None
metrics = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global redis_client, rate_limiter, quota_manager, metrics
    
    # Startup
    redis_client = redis.from_url("redis://localhost:6379", decode_responses=True)
    rate_limiter = SlidingWindowLimiter(redis_client)
    quota_manager = QuotaManager(redis_client)
    metrics = MetricsCollector()
    
    logger.info("Rate limiting system initialized")
    yield
    
    # Shutdown
    await redis_client.close()

app = FastAPI(title="Log Processing API - Day 87", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# GraphQL Schema
@strawberry.type
class LogEntry:
    timestamp: str
    level: str
    service: str
    message: str
    
@strawberry.type
class QuotaInfo:
    current_usage: int
    limit: int
    reset_time: int
    burst_available: int

@strawberry.type
class RateLimitInfo:
    requests_remaining: int
    reset_time: int
    retry_after: int

@strawberry.type
class Query:
    @strawberry.field
    async def search_logs(self, query: str, limit: int = 100) -> list[LogEntry]:
        # Simulate log search
        return [
            LogEntry(
                timestamp="2025-08-05T10:30:00Z",
                level="ERROR",
                service="auth-service",
                message=f"Sample log matching: {query}"
            )
        ]
    
    @strawberry.field
    async def get_quota_info(self, user_id: str) -> QuotaInfo:
        quota_info = await quota_manager.get_quota_status(user_id)
        return QuotaInfo(**quota_info)
    
    @strawberry.field
    async def get_rate_limit_info(self, user_id: str) -> RateLimitInfo:
        limit_info = await rate_limiter.get_limit_status(user_id)
        return RateLimitInfo(**limit_info)

schema = strawberry.Schema(query=Query)
graphql_app = GraphQLRouter(schema)

# Add rate limiting middleware
app.add_middleware(RateLimitMiddleware, 
                  rate_limiter=lambda: rate_limiter,
                  quota_manager=lambda: quota_manager,
                  metrics=lambda: metrics)

app.include_router(graphql_app, prefix="/graphql")

@app.get("/health")
async def health_check():
    return {"status": "healthy", "feature": "rate_limiting"}

@app.get("/metrics")
async def get_metrics():
    return await metrics.get_all_metrics()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
