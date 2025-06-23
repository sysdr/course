from datetime import datetime
from enum import Enum
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field


class UpdateType(str, Enum):
    CREATE = "CREATE"
    UPDATE = "UPDATE"
    DELETE = "DELETE"


class UserProfile(BaseModel):
    user_id: str = Field(..., description="Unique user identifier")
    email: str = Field(..., description="User email address")
    first_name: str = Field(..., description="User first name")
    last_name: str = Field(..., description="User last name")
    age: Optional[int] = Field(None, description="User age")
    preferences: Optional[str] = Field(None, description="User preferences JSON")
    last_updated: datetime = Field(default_factory=datetime.now)
    version: int = Field(default=1, description="Profile version for optimistic locking")
    deleted: bool = Field(default=False, description="Soft delete flag")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
    
    def increment_version(self) -> 'UserProfile':
        """Increment version and update timestamp"""
        self.version += 1
        self.last_updated = datetime.now()
        return self
    
    def mark_deleted(self) -> 'UserProfile':
        """Mark profile as deleted and increment version"""
        self.deleted = True
        return self.increment_version()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary with serialized datetime"""
        return self.dict()


class StateUpdate(BaseModel):
    event_id: str = Field(..., description="Unique event identifier")
    user_id: str = Field(..., description="User ID this update relates to")
    update_type: UpdateType = Field(..., description="Type of update")
    profile: Optional[UserProfile] = Field(None, description="Profile data")
    timestamp: datetime = Field(default_factory=datetime.now)
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return self.dict()
