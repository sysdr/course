from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any, List
from datetime import datetime
import structlog
from deps import get_current_user
from shared import auth_service, rbac_engine, audit_service

router = APIRouter()
logger = structlog.get_logger()

@router.get("/audit-summary")
async def get_audit_summary(
    hours: int = 24,
    current_user: Dict = Depends(get_current_user),
):
    """Get audit summary - admin only"""
    
    if "administrator" not in current_user["roles"]:
        raise HTTPException(status_code=403, detail="Administrator role required")
    
    summary = audit_service.get_audit_summary(hours)
    
    return {
        "audit_summary": summary,
        "generated_by": current_user["user_id"],
        "generated_at": datetime.utcnow().isoformat(),
    }

@router.get("/security-events")
async def get_security_events(
    limit: int = 50,
    current_user: Dict = Depends(get_current_user),
):
    """Get recent security events - admin only"""
    
    if "administrator" not in current_user["roles"]:
        raise HTTPException(status_code=403, detail="Administrator role required")
    
    events = audit_service.security_events[-limit:]
    
    return {
        "security_events": events,
        "count": len(events),
        "retrieved_by": current_user["user_id"]
    }

@router.get("/rbac-policies")
async def get_rbac_policies(current_user: Dict = Depends(get_current_user)):
    """Get RBAC policies - admin only"""
    
    if "administrator" not in current_user["roles"]:
        raise HTTPException(status_code=403, detail="Administrator role required")
    
    return {
        "role_policies": rbac_engine.role_policies,
        "resource_classifications": rbac_engine.resource_classifications
    }

@router.get("/system-status")
async def get_system_status(current_user: Dict = Depends(get_current_user)):
    """Get system status and health metrics"""
    
    if "administrator" not in current_user["roles"]:
        raise HTTPException(status_code=403, detail="Administrator role required")
    
    return {
        "status": "healthy",
        "active_users": len(auth_service.users),
        "audit_logs_count": len(audit_service.audit_logs),
        "security_events_count": len(audit_service.security_events),
        "uptime": "24h 15m",
        "version": "1.0.0",
    }
