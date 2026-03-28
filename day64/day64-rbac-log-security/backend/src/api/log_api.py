from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional, Dict, Any
import json
from datetime import datetime, timedelta
import structlog
from deps import get_current_user
from shared import rbac_engine, audit_service

router = APIRouter()
logger = structlog.get_logger()

# Mock log data for demonstration
SAMPLE_LOGS = [
    {
        "id": "log_001",
        "timestamp": "2025-01-15T10:30:00Z",
        "level": "INFO",
        "service": "application.auth",
        "message": "User login successful",
        "user_id": "user123",
        "ip_address": "192.168.1.100"
    },
    {
        "id": "log_002", 
        "timestamp": "2025-01-15T10:31:00Z",
        "level": "ERROR",
        "service": "application.payment",
        "message": "Payment processing failed",
        "transaction_id": "tx_456",
        "amount": 99.99
    },
    {
        "id": "log_003",
        "timestamp": "2025-01-15T10:32:00Z", 
        "level": "INFO",
        "service": "infrastructure.network",
        "message": "Network latency spike detected",
        "latency_ms": 150
    },
    {
        "id": "log_004",
        "timestamp": "2025-01-15T10:33:00Z",
        "level": "WARN",
        "service": "business.metrics",
        "message": "Daily active users below threshold",
        "current_dau": 8500,
        "threshold": 10000
    },
    {
        "id": "log_005",
        "timestamp": "2025-01-15T10:34:00Z",
        "level": "INFO",
        "service": "analytics.dashboard",
        "message": "Report generation completed",
        "report_id": "rpt_789"
    }
]

@router.get("/search")
async def search_logs(
    service: Optional[str] = Query(None, description="Filter by service"),
    level: Optional[str] = Query(None, description="Filter by log level"),
    start_time: Optional[str] = Query(None, description="Start timestamp"),
    end_time: Optional[str] = Query(None, description="End timestamp"),
    limit: int = Query(100, le=1000, description="Maximum results"),
    current_user: Dict = Depends(get_current_user),
):
    """Search logs with RBAC enforcement"""
    roles = current_user["roles"]
    if service:
        rbac_resource = service
    elif "administrator" in roles:
        rbac_resource = "*"
    elif "developer" in roles:
        rbac_resource = "application"
    elif "analyst" in roles:
        rbac_resource = "business"
    elif "support" in roles:
        rbac_resource = "support"
    else:
        rbac_resource = "application"

    permission_check = rbac_engine.check_permission(
        user_roles=current_user["roles"],
        resource=rbac_resource,
        action="read",
    )
    
    if not permission_check["allowed"]:
        raise HTTPException(
            status_code=403,
            detail=f"Access denied: {permission_check['reason']}"
        )
    
    # Apply filters based on user permissions and restrictions
    filtered_logs = SAMPLE_LOGS.copy()
    
    # Apply service filter
    if service:
        filtered_logs = [log for log in filtered_logs if log["service"].startswith(service)]
    
    # Apply level filter
    if level:
        filtered_logs = [log for log in filtered_logs if log["level"] == level]
    
    # Apply time range filter
    if start_time:
        start_dt = datetime.fromisoformat(start_time.replace('Z', '+00:00'))
        filtered_logs = [
            log for log in filtered_logs 
            if datetime.fromisoformat(log["timestamp"].replace('Z', '+00:00')) >= start_dt
        ]
    
    # Apply role-based restrictions
    restrictions = permission_check["restrictions"]
    if "mask_sensitive_fields" in restrictions:
        filtered_logs = _mask_sensitive_data(filtered_logs)
    
    if "aggregated_data_only" in restrictions:
        filtered_logs = _aggregate_logs(filtered_logs)
    
    # Apply limit
    filtered_logs = filtered_logs[:limit]
    
    # Log the access for audit
    await audit_service.log_access(
        user_id=current_user["user_id"],
        resource=f"logs.search.{service or 'all'}",
        action="read",
        status_code=200,
        duration=0.05,  # Mock duration
        client_ip="127.0.0.1",  # Mock IP
        metadata={
            "results_count": len(filtered_logs),
            "filters": {"service": service, "level": level},
            "restrictions_applied": restrictions
        }
    )
    
    return {
        "logs": filtered_logs,
        "count": len(filtered_logs),
        "restrictions_applied": restrictions,
        "message": "Search completed successfully"
    }

@router.get("/export")
async def export_logs(
    format: str = Query("json", description="Export format: json, csv"),
    service: Optional[str] = Query(None, description="Service filter"),
    current_user: Dict = Depends(get_current_user),
):
    """Export logs with permission checking"""
    roles = current_user["roles"]
    if service:
        rbac_resource = service
    elif "administrator" in roles:
        rbac_resource = "*"
    elif "developer" in roles:
        rbac_resource = "application"
    elif "analyst" in roles:
        rbac_resource = "analytics"
    elif "support" in roles:
        rbac_resource = "support"
    else:
        rbac_resource = "application"

    permission_check = rbac_engine.check_permission(
        user_roles=current_user["roles"],
        resource=rbac_resource,
        action="export",
    )
    
    if not permission_check["allowed"]:
        raise HTTPException(
            status_code=403,
            detail=f"Export denied: {permission_check['reason']}"
        )
    
    # Filter logs by service if specified
    export_logs = SAMPLE_LOGS.copy()
    if service:
        export_logs = [log for log in export_logs if log["service"].startswith(service)]
    
    # Apply restrictions
    restrictions = permission_check["restrictions"]
    if "mask_sensitive_fields" in restrictions:
        export_logs = _mask_sensitive_data(export_logs)
    
    # Log the export for audit
    await audit_service.log_security_event(
        event_type="data_export",
        user_id=current_user["user_id"],
        description=f"User exported {len(export_logs)} log entries",
        severity="medium",
        metadata={
            "export_format": format,
            "service_filter": service,
            "record_count": len(export_logs)
        }
    )
    
    return {
        "export_data": export_logs,
        "format": format,
        "record_count": len(export_logs),
        "exported_at": datetime.utcnow().isoformat()
    }

@router.get("/accessible-resources")
async def get_accessible_resources(current_user: Dict = Depends(get_current_user)):
    """Get list of resources accessible to current user"""
    
    accessible = rbac_engine.get_accessible_resources(current_user["roles"])
    
    return {
        "user_id": current_user["user_id"],
        "roles": current_user["roles"],
        "accessible_resources": accessible
    }

def _mask_sensitive_data(logs: List[Dict]) -> List[Dict]:
    """Mask sensitive fields in logs"""
    masked_logs = []
    
    for log in logs:
        masked_log = log.copy()
        
        # Mask PII fields
        if "user_id" in masked_log:
            masked_log["user_id"] = "user_***"
        if "ip_address" in masked_log:
            masked_log["ip_address"] = "xxx.xxx.xxx.xxx"
        if "transaction_id" in masked_log:
            masked_log["transaction_id"] = "tx_***"
            
        masked_logs.append(masked_log)
    
    return masked_logs

def _aggregate_logs(logs: List[Dict]) -> List[Dict]:
    """Return aggregated view of logs"""
    service_counts = {}
    level_counts = {}
    
    for log in logs:
        service = log["service"]
        level = log["level"]
        
        service_counts[service] = service_counts.get(service, 0) + 1
        level_counts[level] = level_counts.get(level, 0) + 1
    
    return [
        {
            "aggregation_type": "service_summary",
            "data": service_counts,
            "generated_at": datetime.utcnow().isoformat()
        },
        {
            "aggregation_type": "level_summary", 
            "data": level_counts,
            "generated_at": datetime.utcnow().isoformat()
        }
    ]
