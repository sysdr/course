from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import structlog
from shared import auth_service

logger = structlog.get_logger()
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    try:
        token = credentials.credentials
        return auth_service.verify_token(token)
    except Exception as e:
        logger.error("Token validation failed", error=str(e))
        raise HTTPException(status_code=401, detail="Invalid authentication token")
