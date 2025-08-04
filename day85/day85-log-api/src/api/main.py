from fastapi import FastAPI, HTTPException, Depends, Query, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import StreamingResponse
import json
import asyncio
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
import sqlite3
import os
from .models import LogEntry, LogQuery, LogStats, APIResponse
from .services import LogService, AuthService
from .auth import get_current_user, RateLimiter

app = FastAPI(
    title="Distributed Log Platform API",
    description="Production-ready RESTful API for distributed log processing",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
log_service = LogService()
auth_service = AuthService()
rate_limiter = RateLimiter()
security = HTTPBearer()

def get_log_service():
    """Get log service instance (allows test injection)"""
    return getattr(app.state, 'log_service', log_service)

def get_auth_service():
    """Get auth service instance (allows test injection)"""
    return getattr(app.state, 'auth_service', auth_service)

@app.on_event("startup")
async def startup_event():
    """Initialize database and services"""
    await log_service.initialize()
    await auth_service.initialize()
    print("🚀 Log Platform API started successfully")

@app.get("/")
async def root():
    return {"message": "Distributed Log Platform API", "version": "1.0.0"}

@app.get("/api/v1/logs", response_model=APIResponse)
async def get_logs(
    page: int = Query(1, ge=1),
    size: int = Query(100, ge=1, le=1000),
    level: Optional[str] = Query(None),
    service: Optional[str] = Query(None),
    time_from: Optional[datetime] = Query(None),
    time_to: Optional[datetime] = Query(None),
    current_user: dict = Depends(get_current_user),
    _: dict = Depends(rate_limiter.check_rate_limit)
):
    """Retrieve logs with filtering and pagination"""
    try:
        log_svc = get_log_service()
        filters = {
            "level": level,
            "service": service, 
            "time_from": time_from,
            "time_to": time_to
        }
        result = await log_svc.get_logs(page, size, filters)
        return APIResponse(
            success=True,
            data=result["logs"],
            metadata={
                "total_count": result["total"],
                "page": page,
                "size": size,
                "has_next": result["has_next"]
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/logs/search", response_model=APIResponse)
async def search_logs(
    query_text: str = Body(..., embed=True, min_length=1),
    page: int = Body(1, embed=True, ge=1),
    size: int = Body(100, embed=True, ge=1, le=1000),
    filters: Optional[Dict[str, Any]] = Body({}, embed=True),
    time_from: Optional[datetime] = Body(None, embed=True),
    time_to: Optional[datetime] = Body(None, embed=True),
    aggregations: Optional[Dict[str, bool]] = Body({}, embed=True),
    current_user: dict = Depends(get_current_user),
    _: dict = Depends(rate_limiter.check_rate_limit)
):
    """Advanced log search with complex queries"""
    try:
        log_svc = get_log_service()
        # Create LogQuery object from individual parameters
        search_query = LogQuery(
            query=query_text,
            page=page,
            size=size,
            filters=filters,
            time_from=time_from,
            time_to=time_to,
            aggregations=aggregations
        )
        result = await log_svc.search_logs(search_query)
        return APIResponse(
            success=True,
            data=result["logs"],
            metadata={
                "total_matches": result["total"],
                "query_time_ms": result["query_time"],
                "aggregations": result.get("aggregations", {})
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/logs/stream")
async def stream_logs(
    level: Optional[str] = Query(None),
    service: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user)
):
    """Real-time log streaming using Server-Sent Events"""
    async def generate_events():
        try:
            log_svc = get_log_service()
            async for log_entry in log_svc.stream_logs(level, service):
                yield f"data: {json.dumps(log_entry)}\n\n"
                await asyncio.sleep(0.1)  # Prevent overwhelming clients
        except Exception as e:
            yield f"event: error\ndata: {json.dumps({'error': str(e)})}\n\n"
    
    return StreamingResponse(
        generate_events(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*"
        }
    )

@app.get("/api/v1/logs/stats", response_model=APIResponse)
async def get_log_stats(
    time_range: str = Query("24h", pattern="^(1h|24h|7d|30d)$"),
    current_user: dict = Depends(get_current_user),
    _: dict = Depends(rate_limiter.check_rate_limit)
):
    """Get log statistics and aggregations"""
    try:
        log_svc = get_log_service()
        stats = await log_svc.get_stats(time_range)
        return APIResponse(
            success=True,
            data=stats,
            metadata={"time_range": time_range, "generated_at": datetime.now()}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/auth/login")
async def login(credentials: dict = Body(...)):
    """Authenticate user and return JWT token"""
    try:
        auth_svc = get_auth_service()
        token = await auth_svc.authenticate(
            credentials["username"], 
            credentials["password"]
        )
        return {"access_token": token, "token_type": "bearer"}
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid credentials")

@app.get("/api/v1/health")
async def health_check():
    """API health check endpoint"""
    log_svc = get_log_service()
    auth_svc = get_auth_service()
    return {
        "status": "healthy",
        "timestamp": datetime.now(),
        "services": {
            "database": await log_svc.health_check(),
            "auth": await auth_svc.health_check()
        }
    }
