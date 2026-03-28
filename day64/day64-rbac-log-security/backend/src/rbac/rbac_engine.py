from typing import Dict, List, Any, Optional
import re
import structlog
from datetime import datetime

logger = structlog.get_logger()

class RBACEngine:
    """Role-Based Access Control engine for log access"""
    
    def __init__(self):
        self.role_policies = {
            "administrator": {
                "permissions": [
                    "logs:read:*",
                    "logs:write:*", 
                    "logs:delete:*",
                    "logs:export:*",
                    "system:admin:*"
                ],
                "restrictions": []
            },
            "developer": {
                "permissions": [
                    "logs:read:application.*",
                    "logs:read:infrastructure.*",
                    "logs:export:application.*"
                ],
                "restrictions": [
                    "!logs:read:*.pii",
                    "!logs:read:*.financial",
                    "time_restricted:business_hours"
                ]
            },
            "analyst": {
                "permissions": [
                    "logs:read:business.*",
                    "logs:read:analytics.*",
                    "logs:export:analytics.*"
                ],
                "restrictions": [
                    "!logs:read:*.raw",
                    "aggregated_only:true"
                ]
            },
            "support": {
                "permissions": [
                    "logs:read:support.*",
                    "logs:read:customer.interactions"
                ],
                "restrictions": [
                    "data_masking:required",
                    "time_limited:4_hours"
                ]
            }
        }
        
        self.resource_classifications = {
            "application.auth": {"sensitivity": "high", "pii": True},
            "application.payment": {"sensitivity": "critical", "financial": True},
            "infrastructure.network": {"sensitivity": "medium"},
            "business.metrics": {"sensitivity": "low", "aggregated": True},
            "support.tickets": {"sensitivity": "medium", "customer_data": True}
        }
    
    def check_permission(self, user_roles: List[str], resource: str, action: str, 
                        context: Optional[Dict] = None) -> Dict[str, Any]:
        """Check if user has permission to perform action on resource"""
        context = context or {}
        
        # Get all permissions for user roles
        user_permissions = []
        user_restrictions = []
        
        for role in user_roles:
            role_policy = self.role_policies.get(role, {})
            user_permissions.extend(role_policy.get("permissions", []))
            user_restrictions.extend(role_policy.get("restrictions", []))
        
        # Check if action is permitted (policies use logs:<action>:<resource> patterns)
        permission_pattern = f"logs:{action}:{resource}"
        allowed = self._match_permissions(permission_pattern, user_permissions)
        
        if not allowed:
            logger.warning("Access denied - no matching permission", 
                         user_roles=user_roles, resource=resource, action=action)
            return {
                "allowed": False,
                "reason": "No matching permission found",
                "restrictions": []
            }
        
        # Check restrictions
        restrictions_applied = []
        for restriction in user_restrictions:
            if restriction.startswith("!"):
                # Denial rule
                deny_pattern = restriction[1:]
                if self._match_pattern(permission_pattern, deny_pattern):
                    logger.warning("Access denied - restriction matched",
                                 restriction=restriction, resource=resource)
                    return {
                        "allowed": False,
                        "reason": f"Restriction applied: {restriction}",
                        "restrictions": []
                    }
            else:
                # Context restriction
                restrictions_applied.append(restriction)
        
        # Apply context restrictions
        final_restrictions = self._apply_context_restrictions(
            restrictions_applied, context)
        
        logger.info("Access granted", user_roles=user_roles, resource=resource, 
                   action=action, restrictions=final_restrictions)
        
        return {
            "allowed": True,
            "reason": "Permission granted",
            "restrictions": final_restrictions
        }
    
    def _match_permissions(self, permission_pattern: str, user_permissions: List[str]) -> bool:
        """Check if permission pattern matches any user permissions"""
        for permission in user_permissions:
            if self._match_pattern(permission_pattern, permission):
                return True
        return False
    
    def _match_pattern(self, target: str, pattern: str) -> bool:
        """Match target against wildcard pattern"""
        # Convert wildcard pattern to regex
        regex_pattern = pattern.replace("*", ".*").replace("?", ".")
        return bool(re.match(f"^{regex_pattern}$", target))
    
    def _apply_context_restrictions(self, restrictions: List[str], 
                                  context: Dict) -> List[str]:
        """Apply context-based restrictions"""
        applied = []
        current_time = datetime.utcnow()
        
        for restriction in restrictions:
            if restriction == "time_restricted:business_hours":
                if not (9 <= current_time.hour <= 17):
                    applied.append("outside_business_hours")
            elif restriction == "data_masking:required":
                applied.append("mask_sensitive_fields")
            elif restriction.startswith("time_limited:"):
                duration = restriction.split(":")[1]
                applied.append(f"session_expires:{duration}")
            elif restriction == "aggregated_only:true":
                applied.append("aggregated_data_only")
                
        return applied
    
    def get_accessible_resources(self, user_roles: List[str]) -> List[str]:
        """Get list of resources accessible to user roles"""
        accessible = []
        
        for resource in self.resource_classifications.keys():
            for action in ["read", "write", "export"]:
                result = self.check_permission(user_roles, resource, action)
                if result["allowed"]:
                    accessible.append(f"{action}:{resource}")
        
        return accessible
