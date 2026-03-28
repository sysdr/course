import os
import jwt
import bcrypt
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Dict, Any
import structlog
from dotenv import load_dotenv

logger = structlog.get_logger()

_backend_root = Path(__file__).resolve().parents[2]
load_dotenv(_backend_root / "config" / ".env", override=False)
load_dotenv(_backend_root / ".env", override=False)


class AuthService:
    """Authentication service handling JWT tokens"""

    def __init__(self):
        self.secret_key = os.environ.get("JWT_SECRET_KEY", "").strip()
        if not self.secret_key:
            raise RuntimeError(
                "JWT_SECRET_KEY is not set. Copy backend/config/.env.example to "
                "backend/config/.env or export JWT_SECRET_KEY (see README)."
            )
        self.algorithm = "HS256"
        self.access_token_expire_minutes = 60
        self.users = {  # Demo users - in production, use database
            "admin": {
                "user_id": "admin",
                "username": "admin",
                "password_hash": bcrypt.hashpw("admin123".encode(), bcrypt.gensalt()),
                "roles": ["administrator"],
                "email": "admin@company.com",
            },
            "developer": {
                "user_id": "dev001",
                "username": "developer",
                "password_hash": bcrypt.hashpw("dev123".encode(), bcrypt.gensalt()),
                "roles": ["developer"],
                "email": "dev@company.com",
            },
            "analyst": {
                "user_id": "analyst001",
                "username": "analyst",
                "password_hash": bcrypt.hashpw("analyst123".encode(), bcrypt.gensalt()),
                "roles": ["analyst"],
                "email": "analyst@company.com",
            },
        }

    def authenticate_user(self, username: str, password: str) -> Optional[Dict[str, Any]]:
        """Authenticate user credentials"""
        user = self.users.get(username)
        if not user:
            return None

        if bcrypt.checkpw(password.encode(), user["password_hash"]):
            logger.info("User authenticated successfully", username=username)
            return user

        logger.warning("Authentication failed", username=username)
        return None

    def create_access_token(self, user_data: Dict[str, Any]) -> str:
        """Create JWT access token"""
        payload = {
            "user_id": user_data["user_id"],
            "username": user_data["username"],
            "roles": user_data["roles"],
            "exp": datetime.utcnow() + timedelta(minutes=self.access_token_expire_minutes),
            "iat": datetime.utcnow(),
        }

        token = jwt.encode(payload, self.secret_key, algorithm=self.algorithm)
        logger.info("Access token created", user_id=user_data["user_id"])
        return token

    def verify_token(self, token: str) -> Dict[str, Any]:
        """Verify and decode JWT token"""
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=[self.algorithm])
            return payload
        except jwt.ExpiredSignatureError:
            raise Exception("Token has expired")
        except jwt.InvalidTokenError:
            raise Exception("Invalid token")
