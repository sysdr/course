from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Dict, Any
import structlog
from deps import get_current_user
from shared import auth_service, audit_service

router = APIRouter()
logger = structlog.get_logger()


class LoginRequest(BaseModel):
    username: str
    password: str


@router.post("/login")
async def login(login_data: LoginRequest):
    """Authenticate user and return JWT token"""

    user = auth_service.authenticate_user(login_data.username, login_data.password)

    if not user:
        await audit_service.log_security_event(
            event_type="failed_login",
            user_id=login_data.username,
            description="Failed login attempt",
            severity="medium",
        )
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = auth_service.create_access_token(user)

    await audit_service.log_security_event(
        event_type="successful_login",
        user_id=user["user_id"],
        description="User logged in successfully",
        severity="low",
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_info": {
            "user_id": user["user_id"],
            "username": user["username"],
            "roles": user["roles"],
            "email": user["email"],
        },
    }


@router.get("/profile")
async def get_profile(current_user: Dict = Depends(get_current_user)):
    """Get current user profile"""
    return {
        "user_id": current_user["user_id"],
        "username": current_user["username"],
        "roles": current_user["roles"],
    }


@router.post("/logout")
async def logout(current_user: Dict = Depends(get_current_user)):
    """Logout user (invalidate token in production)"""

    await audit_service.log_security_event(
        event_type="user_logout",
        user_id=current_user["user_id"],
        description="User logged out",
        severity="low",
    )

    return {"message": "Logged out successfully"}
