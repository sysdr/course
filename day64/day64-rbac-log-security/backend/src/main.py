import sys
import time
from pathlib import Path

# Running as python src/main.py from backend/: ensure src/ is on path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import structlog
from shared import auth_service, audit_service
from api.log_api import router as log_router
from api.auth_api import router as auth_router
from api.admin_api import router as admin_router

logger = structlog.get_logger()

app = FastAPI(
    title="Log Processing RBAC System",
    description="Role-Based Access Control for Distributed Log Processing",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/auth", tags=["Authentication"])
app.include_router(log_router, prefix="/api/logs", tags=["Logs"])
app.include_router(admin_router, prefix="/api/admin", tags=["Administration"])


@app.middleware("http")
async def audit_middleware(request: Request, call_next):
    start_time = time.time()
    user_id = "anonymous"
    authorization = request.headers.get("Authorization")
    if authorization:
        try:
            token = authorization.replace("Bearer ", "")
            payload = auth_service.verify_token(token)
            user_id = payload.get("user_id", "unknown")
        except Exception:
            pass

    response = await call_next(request)

    await audit_service.log_access(
        user_id=user_id,
        resource=str(request.url),
        action=request.method,
        status_code=response.status_code,
        duration=time.time() - start_time,
        client_ip=request.client.host if request.client else "unknown",
    )

    return response


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "rbac-log-system"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
