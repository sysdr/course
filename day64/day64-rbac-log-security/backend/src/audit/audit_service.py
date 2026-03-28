import asyncio
import json
from datetime import datetime
from typing import Dict, Any, Optional
import structlog

logger = structlog.get_logger()

class AuditService:
    """Audit service for logging access attempts and security events"""
    
    def __init__(self):
        self.audit_logs = []  # In production, use persistent storage
        self.security_events = []
        
    async def log_access(self, user_id: str, resource: str, action: str,
                        status_code: int, duration: float, client_ip: str,
                        metadata: Optional[Dict] = None):
        """Log access attempt with full context"""
        audit_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "user_id": user_id,
            "resource": resource,
            "action": action,
            "status_code": status_code,
            "duration_ms": round(duration * 1000, 2),
            "client_ip": client_ip,
            "metadata": metadata or {},
            "event_type": "access_log"
        }
        
        self.audit_logs.append(audit_entry)
        logger.info("Access logged", **audit_entry)
        
        # Check for security anomalies
        await self._analyze_security_patterns(audit_entry)
    
    async def log_security_event(self, event_type: str, user_id: str, 
                                description: str, severity: str = "medium",
                                metadata: Optional[Dict] = None):
        """Log security event for compliance and monitoring"""
        security_event = {
            "timestamp": datetime.utcnow().isoformat(),
            "event_type": event_type,
            "user_id": user_id,
            "description": description,
            "severity": severity,
            "metadata": metadata or {},
            "investigated": False
        }
        
        self.security_events.append(security_event)
        logger.warning("Security event logged", **security_event)
        
        # Trigger alerts for high severity events
        if severity in ["high", "critical"]:
            await self._trigger_security_alert(security_event)
    
    async def _analyze_security_patterns(self, audit_entry: Dict):
        """Analyze access patterns for security anomalies"""
        user_id = audit_entry["user_id"]
        
        # Count failed attempts in last 5 minutes
        recent_failures = [
            log for log in self.audit_logs[-100:]  # Check last 100 entries
            if (log["user_id"] == user_id and 
                log["status_code"] >= 400 and
                (datetime.utcnow() - datetime.fromisoformat(log["timestamp"])).seconds < 300)
        ]
        
        if len(recent_failures) >= 5:
            await self.log_security_event(
                event_type="multiple_failed_attempts",
                user_id=user_id,
                description=f"User has {len(recent_failures)} failed attempts in last 5 minutes",
                severity="medium",
                metadata={"failed_attempts_count": len(recent_failures)}
            )
        
        # Check for unusual access patterns
        if audit_entry["status_code"] == 200:
            user_accesses = [
                log for log in self.audit_logs[-50:]
                if log["user_id"] == user_id and log["status_code"] == 200
            ]
            
            if len(user_accesses) >= 10:  # Rapid access pattern
                await self.log_security_event(
                    event_type="rapid_access_pattern",
                    user_id=user_id,
                    description="Unusually high access frequency detected",
                    severity="low",
                    metadata={"access_count": len(user_accesses)}
                )
    
    async def _trigger_security_alert(self, security_event: Dict):
        """Trigger security alert for high-severity events"""
        logger.critical("SECURITY ALERT", **security_event)
        # In production: send to SIEM, notify security team, etc.
    
    def get_audit_summary(self, hours: int = 24) -> Dict[str, Any]:
        """Get audit summary for specified time period"""
        cutoff = datetime.utcnow().timestamp() - (hours * 3600)
        
        recent_logs = [
            log for log in self.audit_logs
            if datetime.fromisoformat(log["timestamp"]).timestamp() > cutoff
        ]
        
        successful_accesses = len([log for log in recent_logs if log["status_code"] < 400])
        failed_accesses = len([log for log in recent_logs if log["status_code"] >= 400])
        
        unique_users = len(set(log["user_id"] for log in recent_logs))
        
        return {
            "period_hours": hours,
            "total_accesses": len(recent_logs),
            "successful_accesses": successful_accesses,
            "failed_accesses": failed_accesses,
            "unique_users": unique_users,
            "security_events": len(self.security_events),
            "success_rate": round(successful_accesses / max(len(recent_logs), 1) * 100, 2)
        }
