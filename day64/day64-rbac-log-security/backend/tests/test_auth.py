import pytest
from src.auth.auth_service import AuthService
from src.rbac.rbac_engine import RBACEngine

def test_user_authentication():
    auth_service = AuthService()
    
    # Test valid credentials
    user = auth_service.authenticate_user("admin", "admin123")
    assert user is not None
    assert user["username"] == "admin"
    assert "administrator" in user["roles"]
    
    # Test invalid credentials
    user = auth_service.authenticate_user("admin", "wrong_password")
    assert user is None

def test_jwt_token_creation():
    auth_service = AuthService()
    user_data = {
        "user_id": "test_user",
        "username": "test",
        "roles": ["developer"]
    }
    
    token = auth_service.create_access_token(user_data)
    assert token is not None
    
    # Verify token
    payload = auth_service.verify_token(token)
    assert payload["user_id"] == "test_user"
    assert payload["username"] == "test"

def test_rbac_permissions():
    rbac_engine = RBACEngine()
    
    # Test administrator permissions
    result = rbac_engine.check_permission(
        user_roles=["administrator"],
        resource="logs.sensitive",
        action="read"
    )
    assert result["allowed"] == True
    
    # Test developer restrictions
    result = rbac_engine.check_permission(
        user_roles=["developer"],
        resource="logs.financial",
        action="read"
    )
    assert result["allowed"] == False
