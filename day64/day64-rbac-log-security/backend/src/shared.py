"""Application-wide singletons so audit logs and auth state stay consistent."""
from datetime import datetime
from auth.auth_service import AuthService
from rbac.rbac_engine import RBACEngine
from audit.audit_service import AuditService

auth_service = AuthService()
rbac_engine = RBACEngine()
audit_service = AuditService()


def _seed_demo_audit_trail() -> None:
    """Pre-populate sample access rows so admin metrics are non-zero before demo traffic."""
    now = datetime.utcnow().isoformat()
    audit_service.audit_logs.extend(
        [
            {
                "timestamp": now,
                "user_id": "admin",
                "resource": "http://demo/api/logs/search",
                "action": "GET",
                "status_code": 200,
                "duration_ms": 14.2,
                "client_ip": "127.0.0.1",
                "metadata": {"demo": True},
                "event_type": "access_log",
            },
            {
                "timestamp": now,
                "user_id": "dev001",
                "resource": "http://demo/api/logs/search",
                "action": "GET",
                "status_code": 200,
                "duration_ms": 9.8,
                "client_ip": "127.0.0.1",
                "metadata": {"demo": True},
                "event_type": "access_log",
            },
            {
                "timestamp": now,
                "user_id": "anonymous",
                "resource": "http://demo/api/auth/login",
                "action": "POST",
                "status_code": 401,
                "duration_ms": 3.1,
                "client_ip": "127.0.0.1",
                "metadata": {"demo": True},
                "event_type": "access_log",
            },
        ]
    )


_seed_demo_audit_trail()
