#!/bin/bash

# Day 134: Feature Flag Status Logging - Complete Implementation Script
# Module 5: Integration and Ecosystem | Week 19: Application Integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Day 134: Feature Flag Status Logging Implementation${NC}"
echo -e "${BLUE}================================================================${NC}"

# Create project structure
echo -e "${YELLOW}📁 Creating project structure...${NC}"
mkdir -p feature-flag-logging/{backend/{app,tests,config,logs},frontend/{src,public,build},docker,scripts}
cd feature-flag-logging

# Create backend directory structure
mkdir -p backend/{app/{api,core,models,services,utils},tests/{unit,integration},config,logs}
mkdir -p frontend/{src/{components,pages,services,utils,hooks},public}

# Create Python requirements with Python 3.11 compatible versions
echo -e "${YELLOW}📦 Creating requirements.txt with latest May 2025 libraries...${NC}"
cat > backend/requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn==0.30.0
redis==5.0.4
pydantic==2.7.1
python-jose==3.3.0
python-multipart==0.0.9
passlib==1.7.4
bcrypt==4.1.3
sqlalchemy==2.0.30
alembic==1.13.1
psycopg2-binary==2.9.9
pytest==8.2.1
pytest-asyncio==0.23.7
httpx==0.27.0
aioredis==2.0.1
structlog==24.1.0
python-json-logger==2.0.7
websockets==12.0
sse-starlette==2.1.0
pika==1.3.2
celery==5.3.6
EOF

# Create package.json for React frontend
echo -e "${YELLOW}📦 Creating package.json for React frontend...${NC}"
cat > frontend/package.json << 'EOF'
{
  "name": "feature-flag-dashboard",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.23.1",
    "axios": "^1.7.2",
    "react-query": "^3.39.3",
    "recharts": "^2.12.7",
    "react-hot-toast": "^2.4.1",
    "lucide-react": "^0.379.0",
    "date-fns": "^3.6.0",
    "clsx": "^2.1.1",
    "tailwindcss": "^3.4.3"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.0",
    "vite": "^5.2.11",
    "eslint": "^8.57.0",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.38"
  },
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "lint": "eslint src --ext js,jsx --report-unused-disable-directives --max-warnings 0"
  }
}
EOF

# Create Python backend models
echo -e "${YELLOW}📝 Creating backend models...${NC}"
cat > backend/app/models/__init__.py << 'EOF'
from .feature_flag import FeatureFlag
from .flag_log import FlagLog
from .user import User

__all__ = ["FeatureFlag", "FlagLog", "User"]
EOF

cat > backend/app/models/feature_flag.py << 'EOF'
from sqlalchemy import Column, String, Boolean, DateTime, Text, JSON
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime
import uuid

Base = declarative_base()

class FeatureFlag(Base):
    __tablename__ = "feature_flags"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, unique=True, nullable=False, index=True)
    description = Column(Text)
    enabled = Column(Boolean, default=False)
    rollout_percentage = Column(String, default="0")
    target_groups = Column(JSON, default=list)
    metadata = Column(JSON, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = Column(String)
    updated_by = Column(String)
    
    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "enabled": self.enabled,
            "rollout_percentage": self.rollout_percentage,
            "target_groups": self.target_groups,
            "metadata": self.metadata,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "created_by": self.created_by,
            "updated_by": self.updated_by
        }
EOF

cat > backend/app/models/flag_log.py << 'EOF'
from sqlalchemy import Column, String, Boolean, DateTime, Text, JSON, Integer
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime
import uuid

Base = declarative_base()

class FlagLog(Base):
    __tablename__ = "flag_logs"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    flag_id = Column(String, nullable=False, index=True)
    flag_name = Column(String, nullable=False, index=True)
    event_type = Column(String, nullable=False)  # 'create', 'update', 'delete', 'evaluate'
    previous_state = Column(JSON)
    new_state = Column(JSON)
    user_id = Column(String)
    user_agent = Column(String)
    ip_address = Column(String)
    context = Column(JSON, default=dict)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    
    def to_dict(self):
        return {
            "id": self.id,
            "flag_id": self.flag_id,
            "flag_name": self.flag_name,
            "event_type": self.event_type,
            "previous_state": self.previous_state,
            "new_state": self.new_state,
            "user_id": self.user_id,
            "user_agent": self.user_agent,
            "ip_address": self.ip_address,
            "context": self.context,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None
        }
EOF

cat > backend/app/models/user.py << 'EOF'
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime
import uuid

Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    username = Column(String, unique=True, nullable=False, index=True)
    email = Column(String, unique=True, nullable=False, index=True)
    full_name = Column(String)
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "full_name": self.full_name,
            "is_active": self.is_active,
            "is_admin": self.is_admin,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
EOF

# Create database configuration
echo -e "${YELLOW}🗄️ Creating database configuration...${NC}"
cat > backend/app/core/database.py << 'EOF'
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from app.models.feature_flag import Base as FlagBase
from app.models.flag_log import Base as LogBase
from app.models.user import Base as UserBase
import os

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/featureflags")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def create_tables():
    FlagBase.metadata.create_all(bind=engine)
    LogBase.metadata.create_all(bind=engine)
    UserBase.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

# Create Redis configuration
cat > backend/app/core/redis_client.py << 'EOF'
import redis
import json
import os
from typing import Optional, Any

class RedisClient:
    def __init__(self):
        self.redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
        self.client = redis.from_url(self.redis_url, decode_responses=True)
    
    async def get_flag(self, flag_name: str) -> Optional[dict]:
        """Get feature flag from cache"""
        try:
            data = self.client.get(f"flag:{flag_name}")
            return json.loads(data) if data else None
        except Exception:
            return None
    
    async def set_flag(self, flag_name: str, flag_data: dict, ttl: int = 300):
        """Cache feature flag data"""
        try:
            self.client.setex(f"flag:{flag_name}", ttl, json.dumps(flag_data))
        except Exception:
            pass
    
    async def invalidate_flag(self, flag_name: str):
        """Remove flag from cache"""
        try:
            self.client.delete(f"flag:{flag_name}")
        except Exception:
            pass
    
    async def increment_evaluation_count(self, flag_name: str, user_context: str = "anonymous"):
        """Track flag evaluation metrics"""
        try:
            key = f"flag_eval:{flag_name}:{user_context}"
            self.client.incr(key)
            self.client.expire(key, 86400)  # 24 hours
        except Exception:
            pass

redis_client = RedisClient()
EOF

# Create logging service
cat > backend/app/services/logging_service.py << 'EOF'
import json
import pika
import structlog
from datetime import datetime
from typing import Dict, Any, Optional
from app.models.flag_log import FlagLog
from sqlalchemy.orm import Session

logger = structlog.get_logger()

class FlagLoggingService:
    def __init__(self):
        self.setup_rabbitmq()
    
    def setup_rabbitmq(self):
        """Setup RabbitMQ connection for distributed logging"""
        try:
            connection = pika.BlockingConnection(
                pika.ConnectionParameters('localhost')
            )
            self.channel = connection.channel()
            self.channel.exchange_declare(
                exchange='feature_flags',
                exchange_type='topic',
                durable=True
            )
        except Exception as e:
            logger.warning("RabbitMQ not available, falling back to database only", error=str(e))
            self.channel = None
    
    async def log_flag_event(
        self, 
        db: Session,
        flag_id: str,
        flag_name: str,
        event_type: str,
        previous_state: Optional[Dict] = None,
        new_state: Optional[Dict] = None,
        user_id: Optional[str] = None,
        user_agent: Optional[str] = None,
        ip_address: Optional[str] = None,
        context: Optional[Dict] = None
    ):
        """Log feature flag event to database and message queue"""
        
        # Create database log entry
        log_entry = FlagLog(
            flag_id=flag_id,
            flag_name=flag_name,
            event_type=event_type,
            previous_state=previous_state,
            new_state=new_state,
            user_id=user_id,
            user_agent=user_agent,
            ip_address=ip_address,
            context=context or {}
        )
        
        db.add(log_entry)
        db.commit()
        
        # Send to message queue for distributed processing
        if self.channel:
            try:
                message = {
                    "event_id": log_entry.id,
                    "timestamp": log_entry.timestamp.isoformat(),
                    "flag_name": flag_name,
                    "event_type": event_type,
                    "previous_state": previous_state,
                    "new_state": new_state,
                    "user_id": user_id,
                    "context": context or {}
                }
                
                routing_key = f"flags.{event_type}.{flag_name}"
                
                self.channel.basic_publish(
                    exchange='feature_flags',
                    routing_key=routing_key,
                    body=json.dumps(message),
                    properties=pika.BasicProperties(
                        delivery_mode=2,  # Make message persistent
                        content_type='application/json'
                    )
                )
            except Exception as e:
                logger.error("Failed to send flag event to queue", error=str(e))
        
        return log_entry
    
    async def log_flag_evaluation(
        self,
        db: Session,
        flag_name: str,
        result: bool,
        user_context: Dict,
        evaluation_context: Dict
    ):
        """Log flag evaluation for analytics"""
        await self.log_flag_event(
            db=db,
            flag_id=evaluation_context.get("flag_id", "unknown"),
            flag_name=flag_name,
            event_type="evaluate",
            new_state={"result": result, "user_context": user_context},
            context=evaluation_context
        )

logging_service = FlagLoggingService()
EOF

# Create feature flag service
cat > backend/app/services/feature_flag_service.py << 'EOF'
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from app.models.feature_flag import FeatureFlag
from app.services.logging_service import logging_service
from app.core.redis_client import redis_client
import json
import random

class FeatureFlagService:
    async def create_flag(
        self, 
        db: Session, 
        name: str, 
        description: str = None,
        enabled: bool = False,
        rollout_percentage: str = "0",
        target_groups: List[str] = None,
        metadata: Dict = None,
        created_by: str = None
    ) -> FeatureFlag:
        """Create new feature flag"""
        
        flag = FeatureFlag(
            name=name,
            description=description,
            enabled=enabled,
            rollout_percentage=rollout_percentage,
            target_groups=target_groups or [],
            metadata=metadata or {},
            created_by=created_by
        )
        
        db.add(flag)
        db.commit()
        db.refresh(flag)
        
        # Log creation event
        await logging_service.log_flag_event(
            db=db,
            flag_id=flag.id,
            flag_name=flag.name,
            event_type="create",
            new_state=flag.to_dict(),
            user_id=created_by
        )
        
        # Cache the flag
        await redis_client.set_flag(flag.name, flag.to_dict())
        
        return flag
    
    async def update_flag(
        self,
        db: Session,
        flag_id: str,
        updates: Dict[str, Any],
        updated_by: str = None
    ) -> Optional[FeatureFlag]:
        """Update existing feature flag"""
        
        flag = db.query(FeatureFlag).filter(FeatureFlag.id == flag_id).first()
        if not flag:
            return None
        
        # Capture previous state
        previous_state = flag.to_dict()
        
        # Apply updates
        for key, value in updates.items():
            if hasattr(flag, key):
                setattr(flag, key, value)
        
        if updated_by:
            flag.updated_by = updated_by
        
        db.commit()
        db.refresh(flag)
        
        # Log update event
        await logging_service.log_flag_event(
            db=db,
            flag_id=flag.id,
            flag_name=flag.name,
            event_type="update",
            previous_state=previous_state,
            new_state=flag.to_dict(),
            user_id=updated_by
        )
        
        # Update cache
        await redis_client.set_flag(flag.name, flag.to_dict())
        
        return flag
    
    async def evaluate_flag(
        self,
        db: Session,
        flag_name: str,
        user_context: Dict[str, Any],
        default_value: bool = False
    ) -> bool:
        """Evaluate feature flag for given user context"""
        
        # Try cache first
        cached_flag = await redis_client.get_flag(flag_name)
        
        if cached_flag:
            flag_data = cached_flag
        else:
            # Fallback to database
            flag = db.query(FeatureFlag).filter(FeatureFlag.name == flag_name).first()
            if not flag:
                return default_value
            flag_data = flag.to_dict()
            # Cache for next time
            await redis_client.set_flag(flag_name, flag_data)
        
        # Basic evaluation logic
        if not flag_data.get("enabled", False):
            result = False
        else:
            rollout_percentage = int(flag_data.get("rollout_percentage", "0"))
            if rollout_percentage >= 100:
                result = True
            elif rollout_percentage <= 0:
                result = False
            else:
                # Simple percentage-based rollout
                user_hash = hash(user_context.get("user_id", "anonymous")) % 100
                result = user_hash < rollout_percentage
        
        # Log evaluation
        await logging_service.log_flag_evaluation(
            db=db,
            flag_name=flag_name,
            result=result,
            user_context=user_context,
            evaluation_context={
                "flag_id": flag_data.get("id", "unknown"),
                "rollout_percentage": flag_data.get("rollout_percentage", "0")
            }
        )
        
        # Update metrics
        await redis_client.increment_evaluation_count(flag_name, user_context.get("user_id", "anonymous"))
        
        return result
    
    async def get_all_flags(self, db: Session) -> List[FeatureFlag]:
        """Get all feature flags"""
        return db.query(FeatureFlag).all()
    
    async def delete_flag(self, db: Session, flag_id: str, deleted_by: str = None) -> bool:
        """Delete feature flag"""
        flag = db.query(FeatureFlag).filter(FeatureFlag.id == flag_id).first()
        if not flag:
            return False
        
        # Log deletion
        await logging_service.log_flag_event(
            db=db,
            flag_id=flag.id,
            flag_name=flag.name,
            event_type="delete",
            previous_state=flag.to_dict(),
            user_id=deleted_by
        )
        
        # Remove from cache
        await redis_client.invalidate_flag(flag.name)
        
        # Delete from database
        db.delete(flag)
        db.commit()
        
        return True

flag_service = FeatureFlagService()
EOF

# Create API endpoints
mkdir -p backend/app/api
cat > backend/app/api/__init__.py << 'EOF'
# API package initialization
EOF

cat > backend/app/api/flags.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from app.core.database import get_db
from app.services.feature_flag_service import flag_service
from app.models.flag_log import FlagLog
from pydantic import BaseModel

router = APIRouter()

class FlagCreate(BaseModel):
    name: str
    description: str = None
    enabled: bool = False
    rollout_percentage: str = "0"
    target_groups: List[str] = []
    metadata: Dict[str, Any] = {}

class FlagUpdate(BaseModel):
    description: str = None
    enabled: bool = None
    rollout_percentage: str = None
    target_groups: List[str] = None
    metadata: Dict[str, Any] = None

class FlagEvaluation(BaseModel):
    flag_name: str
    user_context: Dict[str, Any]
    default_value: bool = False

@router.post("/flags")
async def create_flag(flag_data: FlagCreate, db: Session = Depends(get_db)):
    """Create a new feature flag"""
    try:
        flag = await flag_service.create_flag(
            db=db,
            name=flag_data.name,
            description=flag_data.description,
            enabled=flag_data.enabled,
            rollout_percentage=flag_data.rollout_percentage,
            target_groups=flag_data.target_groups,
            metadata=flag_data.metadata,
            created_by="api_user"  # In real app, get from auth
        )
        return flag.to_dict()
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/flags")
async def get_flags(db: Session = Depends(get_db)):
    """Get all feature flags"""
    flags = await flag_service.get_all_flags(db)
    return [flag.to_dict() for flag in flags]

@router.put("/flags/{flag_id}")
async def update_flag(flag_id: str, flag_updates: FlagUpdate, db: Session = Depends(get_db)):
    """Update feature flag"""
    updates = flag_updates.dict(exclude_unset=True)
    flag = await flag_service.update_flag(
        db=db,
        flag_id=flag_id,
        updates=updates,
        updated_by="api_user"
    )
    if not flag:
        raise HTTPException(status_code=404, detail="Flag not found")
    return flag.to_dict()

@router.delete("/flags/{flag_id}")
async def delete_flag(flag_id: str, db: Session = Depends(get_db)):
    """Delete feature flag"""
    success = await flag_service.delete_flag(db, flag_id, "api_user")
    if not success:
        raise HTTPException(status_code=404, detail="Flag not found")
    return {"message": "Flag deleted successfully"}

@router.post("/flags/evaluate")
async def evaluate_flag(evaluation: FlagEvaluation, db: Session = Depends(get_db)):
    """Evaluate feature flag for user context"""
    result = await flag_service.evaluate_flag(
        db=db,
        flag_name=evaluation.flag_name,
        user_context=evaluation.user_context,
        default_value=evaluation.default_value
    )
    return {"flag_name": evaluation.flag_name, "enabled": result}

@router.get("/flags/{flag_name}/logs")
async def get_flag_logs(flag_name: str, db: Session = Depends(get_db)):
    """Get logs for specific flag"""
    logs = db.query(FlagLog).filter(FlagLog.flag_name == flag_name).order_by(FlagLog.timestamp.desc()).limit(100).all()
    return [log.to_dict() for log in logs]

@router.get("/logs/recent")
async def get_recent_logs(db: Session = Depends(get_db)):
    """Get recent flag activity logs"""
    logs = db.query(FlagLog).order_by(FlagLog.timestamp.desc()).limit(50).all()
    return [log.to_dict() for log in logs]
EOF

# Create main FastAPI application
cat > backend/app/main.py << 'EOF'
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import os
import json
from app.api.flags import router as flags_router
from app.core.database import create_tables
import structlog

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
)

app = FastAPI(title="Feature Flag Logging System", version="1.0.0")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(flags_router, prefix="/api/v1")

@app.on_event("startup")
async def startup_event():
    """Initialize database tables"""
    create_tables()

@app.get("/")
async def root():
    return {"message": "Feature Flag Logging System", "status": "active"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "feature-flag-logging"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Create React frontend components
echo -e "${YELLOW}⚛️ Creating React frontend components...${NC}"
cat > frontend/src/App.jsx << 'EOF'
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from 'react-query';
import { Toaster } from 'react-hot-toast';
import Dashboard from './pages/Dashboard';
import FlagManagement from './pages/FlagManagement';
import AuditLogs from './pages/AuditLogs';
import Navigation from './components/Navigation';
import './index.css';

const queryClient = new QueryClient();

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Router>
        <div className="min-h-screen bg-gray-50">
          <Navigation />
          <main className="container mx-auto px-4 py-8">
            <Routes>
              <Route path="/" element={<Dashboard />} />
              <Route path="/flags" element={<FlagManagement />} />
              <Route path="/logs" element={<AuditLogs />} />
            </Routes>
          </main>
          <Toaster position="top-right" />
        </div>
      </Router>
    </QueryClientProvider>
  );
}

export default App;
EOF

cat > frontend/src/components/Navigation.jsx << 'EOF'
import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Flag, BarChart3, FileText } from 'lucide-react';

const Navigation = () => {
  const location = useLocation();

  const navItems = [
    { path: '/', name: 'Dashboard', icon: BarChart3 },
    { path: '/flags', name: 'Feature Flags', icon: Flag },
    { path: '/logs', name: 'Audit Logs', icon: FileText },
  ];

  return (
    <nav className="bg-white shadow-sm border-b">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center space-x-8">
            <div className="flex items-center space-x-2">
              <Flag className="w-8 h-8 text-blue-600" />
              <span className="text-xl font-bold text-gray-900">FeatureFlag Logger</span>
            </div>
            <div className="flex space-x-6">
              {navItems.map((item) => {
                const Icon = item.icon;
                const isActive = location.pathname === item.path;
                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    className={`flex items-center space-x-2 px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                      isActive
                        ? 'text-blue-600 bg-blue-50'
                        : 'text-gray-700 hover:text-blue-600 hover:bg-gray-50'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{item.name}</span>
                  </Link>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navigation;
EOF

cat > frontend/src/pages/Dashboard.jsx << 'EOF'
import React, { useState, useEffect } from 'react';
import { useQuery } from 'react-query';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line, PieChart, Pie, Cell } from 'recharts';
import { Activity, Flag, Users, TrendingUp } from 'lucide-react';
import api from '../services/api';

const StatCard = ({ title, value, icon: Icon, change, color = "blue" }) => {
  const colorClasses = {
    blue: "text-blue-600 bg-blue-50",
    green: "text-green-600 bg-green-50",
    yellow: "text-yellow-600 bg-yellow-50",
    red: "text-red-600 bg-red-50"
  };

  return (
    <div className="bg-white p-6 rounded-lg shadow-sm border">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className="text-3xl font-bold text-gray-900">{value}</p>
          {change && (
            <p className={`text-sm ${change > 0 ? 'text-green-600' : 'text-red-600'}`}>
              {change > 0 ? '+' : ''}{change}% from last hour
            </p>
          )}
        </div>
        <div className={`p-3 rounded-full ${colorClasses[color]}`}>
          <Icon className="w-6 h-6" />
        </div>
      </div>
    </div>
  );
};

const Dashboard = () => {
  const [stats, setStats] = useState({
    totalFlags: 0,
    activeFlags: 0,
    totalEvaluations: 0,
    recentChanges: 0
  });

  const { data: flags = [] } = useQuery('flags', api.getFlags);
  const { data: recentLogs = [] } = useQuery('recentLogs', api.getRecentLogs, {
    refetchInterval: 5000
  });

  useEffect(() => {
    if (flags.length > 0) {
      setStats({
        totalFlags: flags.length,
        activeFlags: flags.filter(f => f.enabled).length,
        totalEvaluations: recentLogs.filter(l => l.event_type === 'evaluate').length,
        recentChanges: recentLogs.filter(l => l.event_type === 'update').length
      });
    }
  }, [flags, recentLogs]);

  // Prepare chart data
  const flagStatusData = [
    { name: 'Enabled', value: stats.activeFlags, color: '#10b981' },
    { name: 'Disabled', value: stats.totalFlags - stats.activeFlags, color: '#ef4444' }
  ];

  const activityData = recentLogs.slice(0, 10).map((log, index) => ({
    name: `${log.event_type}`,
    value: index + 1,
    time: new Date(log.timestamp).toLocaleTimeString()
  }));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Feature Flag Dashboard</h1>
        <p className="text-gray-600">Monitor your feature flags and their activity in real-time</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Flags"
          value={stats.totalFlags}
          icon={Flag}
          change={5}
          color="blue"
        />
        <StatCard
          title="Active Flags"
          value={stats.activeFlags}
          icon={Activity}
          change={2}
          color="green"
        />
        <StatCard
          title="Evaluations (1h)"
          value={stats.totalEvaluations}
          icon={TrendingUp}
          change={12}
          color="yellow"
        />
        <StatCard
          title="Recent Changes"
          value={stats.recentChanges}
          icon={Users}
          change={-1}
          color="red"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Flag Status Distribution</h2>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={flagStatusData}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={100}
                dataKey="value"
                label={({name, value}) => `${name}: ${value}`}
              >
                {flagStatusData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Recent Activity</h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={activityData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis />
              <Tooltip />
              <Bar dataKey="value" fill="#3b82f6" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Recent Activity Table */}
      <div className="bg-white rounded-lg shadow-sm border">
        <div className="p-6 border-b">
          <h2 className="text-lg font-semibold text-gray-900">Recent Flag Activity</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Flag Name
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Event
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Time
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  User
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {recentLogs.slice(0, 5).map((log) => (
                <tr key={log.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {log.flag_name}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 py-1 text-xs rounded-full ${
                      log.event_type === 'create' ? 'bg-green-100 text-green-800' :
                      log.event_type === 'update' ? 'bg-blue-100 text-blue-800' :
                      log.event_type === 'delete' ? 'bg-red-100 text-red-800' :
                      'bg-gray-100 text-gray-800'
                    }`}>
                      {log.event_type}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {new Date(log.timestamp).toLocaleString()}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {log.user_id || 'System'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
EOF

cat > frontend/src/pages/FlagManagement.jsx << 'EOF'
import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import { Plus, Edit2, Trash2, ToggleLeft, ToggleRight, Save, X } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '../services/api';

const FlagCard = ({ flag, onEdit, onDelete, onToggle }) => {
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <div className="bg-white p-6 rounded-lg shadow-sm border hover:shadow-md transition-shadow">
      <div className="flex items-center justify-between">
        <div className="flex-1">
          <div className="flex items-center space-x-3">
            <h3 className="text-lg font-semibold text-gray-900">{flag.name}</h3>
            <button
              onClick={() => onToggle(flag.id, !flag.enabled)}
              className={`flex items-center space-x-1 px-3 py-1 rounded-full text-sm font-medium ${
                flag.enabled
                  ? 'bg-green-100 text-green-800 hover:bg-green-200'
                  : 'bg-gray-100 text-gray-800 hover:bg-gray-200'
              }`}
            >
              {flag.enabled ? <ToggleRight className="w-4 h-4" /> : <ToggleLeft className="w-4 h-4" />}
              <span>{flag.enabled ? 'Enabled' : 'Disabled'}</span>
            </button>
          </div>
          {flag.description && (
            <p className="text-gray-600 mt-1">{flag.description}</p>
          )}
          <div className="flex items-center space-x-4 mt-2 text-sm text-gray-500">
            <span>Rollout: {flag.rollout_percentage}%</span>
            <span>Created: {new Date(flag.created_at).toLocaleDateString()}</span>
            {flag.updated_at !== flag.created_at && (
              <span>Updated: {new Date(flag.updated_at).toLocaleDateString()}</span>
            )}
          </div>
        </div>
        <div className="flex items-center space-x-2">
          <button
            onClick={() => onEdit(flag)}
            className="p-2 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded-full"
          >
            <Edit2 className="w-4 h-4" />
          </button>
          <button
            onClick={() => onDelete(flag.id)}
            className="p-2 text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-full"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>
      
      {flag.target_groups && flag.target_groups.length > 0 && (
        <div className="mt-3">
          <div className="flex flex-wrap gap-2">
            {flag.target_groups.map((group) => (
              <span key={group} className="px-2 py-1 bg-blue-100 text-blue-800 rounded text-xs">
                {group}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

const FlagForm = ({ flag, onSubmit, onCancel }) => {
  const [formData, setFormData] = useState({
    name: flag?.name || '',
    description: flag?.description || '',
    enabled: flag?.enabled || false,
    rollout_percentage: flag?.rollout_percentage || '0',
    target_groups: flag?.target_groups?.join(', ') || '',
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    const data = {
      ...formData,
      target_groups: formData.target_groups ? formData.target_groups.split(',').map(s => s.trim()) : []
    };
    onSubmit(data);
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg p-6 w-full max-w-md">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">
          {flag ? 'Edit Feature Flag' : 'Create Feature Flag'}
        </h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700">Name</label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              required
              disabled={!!flag}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700">Description</label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              rows={3}
            />
          </div>
          <div className="flex items-center">
            <input
              type="checkbox"
              id="enabled"
              checked={formData.enabled}
              onChange={(e) => setFormData({ ...formData, enabled: e.target.checked })}
              className="mr-2"
            />
            <label htmlFor="enabled" className="text-sm font-medium text-gray-700">Enabled</label>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700">Rollout Percentage (0-100)</label>
            <input
              type="number"
              min="0"
              max="100"
              value={formData.rollout_percentage}
              onChange={(e) => setFormData({ ...formData, rollout_percentage: e.target.value })}
              className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700">Target Groups (comma-separated)</label>
            <input
              type="text"
              value={formData.target_groups}
              onChange={(e) => setFormData({ ...formData, target_groups: e.target.value })}
              className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              placeholder="beta-users, premium-users"
            />
          </div>
          <div className="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              onClick={onCancel}
              className="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center space-x-2"
            >
              <Save className="w-4 h-4" />
              <span>{flag ? 'Update' : 'Create'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

const FlagManagement = () => {
  const [editingFlag, setEditingFlag] = useState(null);
  const [isCreating, setIsCreating] = useState(false);
  
  const queryClient = useQueryClient();
  const { data: flags = [], isLoading } = useQuery('flags', api.getFlags);

  const createMutation = useMutation(api.createFlag, {
    onSuccess: () => {
      queryClient.invalidateQueries('flags');
      toast.success('Flag created successfully');
      setIsCreating(false);
    },
    onError: (error) => {
      toast.error('Failed to create flag');
    }
  });

  const updateMutation = useMutation(api.updateFlag, {
    onSuccess: () => {
      queryClient.invalidateQueries('flags');
      toast.success('Flag updated successfully');
      setEditingFlag(null);
    },
    onError: (error) => {
      toast.error('Failed to update flag');
    }
  });

  const deleteMutation = useMutation(api.deleteFlag, {
    onSuccess: () => {
      queryClient.invalidateQueries('flags');
      toast.success('Flag deleted successfully');
    },
    onError: (error) => {
      toast.error('Failed to delete flag');
    }
  });

  const handleCreate = (data) => {
    createMutation.mutate(data);
  };

  const handleUpdate = (data) => {
    updateMutation.mutate({ id: editingFlag.id, ...data });
  };

  const handleDelete = (id) => {
    if (window.confirm('Are you sure you want to delete this flag?')) {
      deleteMutation.mutate(id);
    }
  };

  const handleToggle = (id, enabled) => {
    updateMutation.mutate({ id, enabled });
  };

  if (isLoading) {
    return <div className="text-center py-8">Loading flags...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Feature Flag Management</h1>
          <p className="text-gray-600">Create, edit, and manage your feature flags</p>
        </div>
        <button
          onClick={() => setIsCreating(true)}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 flex items-center space-x-2"
        >
          <Plus className="w-4 h-4" />
          <span>Create Flag</span>
        </button>
      </div>

      {flags.length === 0 ? (
        <div className="text-center py-12">
          <Flag className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">No feature flags yet</h3>
          <p className="text-gray-500 mb-4">Get started by creating your first feature flag</p>
          <button
            onClick={() => setIsCreating(true)}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
          >
            Create Your First Flag
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {flags.map((flag) => (
            <FlagCard
              key={flag.id}
              flag={flag}
              onEdit={setEditingFlag}
              onDelete={handleDelete}
              onToggle={handleToggle}
            />
          ))}
        </div>
      )}

      {(isCreating || editingFlag) && (
        <FlagForm
          flag={editingFlag}
          onSubmit={isCreating ? handleCreate : handleUpdate}
          onCancel={() => {
            setIsCreating(false);
            setEditingFlag(null);
          }}
        />
      )}
    </div>
  );
};

export default FlagManagement;
EOF

cat > frontend/src/pages/AuditLogs.jsx << 'EOF'
import React, { useState } from 'react';
import { useQuery } from 'react-query';
import { Search, Filter, Calendar, User, Activity } from 'lucide-react';
import api from '../services/api';

const LogEntry = ({ log }) => {
  const [isExpanded, setIsExpanded] = useState(false);

  const getEventColor = (eventType) => {
    switch (eventType) {
      case 'create': return 'bg-green-100 text-green-800';
      case 'update': return 'bg-blue-100 text-blue-800';
      case 'delete': return 'bg-red-100 text-red-800';
      case 'evaluate': return 'bg-gray-100 text-gray-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const formatState = (state) => {
    if (!state) return 'N/A';
    if (typeof state === 'object') {
      return JSON.stringify(state, null, 2);
    }
    return String(state);
  };

  return (
    <div className="bg-white border rounded-lg overflow-hidden">
      <div 
        className="p-4 cursor-pointer hover:bg-gray-50"
        onClick={() => setIsExpanded(!isExpanded)}
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <span className={`px-2 py-1 text-xs rounded-full font-medium ${getEventColor(log.event_type)}`}>
              {log.event_type}
            </span>
            <span className="font-medium text-gray-900">{log.flag_name}</span>
            <span className="text-sm text-gray-500">
              {new Date(log.timestamp).toLocaleString()}
            </span>
          </div>
          <div className="text-sm text-gray-500">
            {log.user_id && (
              <span className="flex items-center space-x-1">
                <User className="w-3 h-3" />
                <span>{log.user_id}</span>
              </span>
            )}
          </div>
        </div>
      </div>
      
      {isExpanded && (
        <div className="px-4 pb-4 border-t bg-gray-50">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
            {log.previous_state && (
              <div>
                <h4 className="text-sm font-medium text-gray-700 mb-2">Previous State</h4>
                <pre className="text-xs bg-white p-2 rounded border overflow-auto max-h-40">
                  {formatState(log.previous_state)}
                </pre>
              </div>
            )}
            {log.new_state && (
              <div>
                <h4 className="text-sm font-medium text-gray-700 mb-2">New State</h4>
                <pre className="text-xs bg-white p-2 rounded border overflow-auto max-h-40">
                  {formatState(log.new_state)}
                </pre>
              </div>
            )}
          </div>
          
          {log.context && Object.keys(log.context).length > 0 && (
            <div className="mt-4">
              <h4 className="text-sm font-medium text-gray-700 mb-2">Context</h4>
              <pre className="text-xs bg-white p-2 rounded border overflow-auto max-h-40">
                {JSON.stringify(log.context, null, 2)}
              </pre>
            </div>
          )}
          
          <div className="mt-4 text-xs text-gray-500 space-y-1">
            <div>Event ID: {log.id}</div>
            <div>Flag ID: {log.flag_id}</div>
            {log.user_agent && <div>User Agent: {log.user_agent}</div>}
            {log.ip_address && <div>IP Address: {log.ip_address}</div>}
          </div>
        </div>
      )}
    </div>
  );
};

const AuditLogs = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [eventFilter, setEventFilter] = useState('all');
  
  const { data: logs = [], isLoading } = useQuery('recentLogs', api.getRecentLogs, {
    refetchInterval: 10000
  });

  const filteredLogs = logs.filter(log => {
    const matchesSearch = !searchTerm || 
      log.flag_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      log.event_type.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesFilter = eventFilter === 'all' || log.event_type === eventFilter;
    
    return matchesSearch && matchesFilter;
  });

  const eventTypes = ['all', ...new Set(logs.map(log => log.event_type))];

  if (isLoading) {
    return <div className="text-center py-8">Loading audit logs...</div>;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Audit Logs</h1>
        <p className="text-gray-600">Track all feature flag activities and changes</p>
      </div>

      {/* Filters */}
      <div className="bg-white p-4 rounded-lg border space-y-4 md:space-y-0 md:flex md:items-center md:justify-between">
        <div className="flex items-center space-x-4">
          <div className="relative">
            <Search className="w-4 h-4 absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search logs..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          
          <select
            value={eventFilter}
            onChange={(e) => setEventFilter(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-blue-500 focus:border-blue-500"
          >
            {eventTypes.map(type => (
              <option key={type} value={type}>
                {type === 'all' ? 'All Events' : type.charAt(0).toUpperCase() + type.slice(1)}
              </option>
            ))}
          </select>
        </div>
        
        <div className="flex items-center space-x-2 text-sm text-gray-500">
          <Activity className="w-4 h-4" />
          <span>{filteredLogs.length} events found</span>
        </div>
      </div>

      {/* Logs */}
      {filteredLogs.length === 0 ? (
        <div className="text-center py-12">
          <Activity className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">No logs found</h3>
          <p className="text-gray-500">Try adjusting your search or filters</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredLogs.map((log) => (
            <LogEntry key={log.id} log={log} />
          ))}
        </div>
      )}
    </div>
  );
};

export default AuditLogs;
EOF

cat > frontend/src/services/api.js << 'EOF'
import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000/api/v1';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

export default {
  // Feature Flags
  getFlags: () => api.get('/flags').then(res => res.data),
  createFlag: (flagData) => api.post('/flags', flagData).then(res => res.data),
  updateFlag: ({ id, ...data }) => api.put(`/flags/${id}`, data).then(res => res.data),
  deleteFlag: (id) => api.delete(`/flags/${id}`).then(res => res.data),
  
  // Flag Evaluation
  evaluateFlag: (evaluation) => api.post('/flags/evaluate', evaluation).then(res => res.data),
  
  // Logs
  getFlagLogs: (flagName) => api.get(`/flags/${flagName}/logs`).then(res => res.data),
  getRecentLogs: () => api.get('/logs/recent').then(res => res.data),
};
EOF

# Create CSS styles
cat > frontend/src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background-color: #f9fafb;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}

/* Custom scrollbar styles */
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}

::-webkit-scrollbar-track {
  background: #f1f1f1;
  border-radius: 3px;
}

::-webkit-scrollbar-thumb {
  background: #c1c1c1;
  border-radius: 3px;
}

::-webkit-scrollbar-thumb:hover {
  background: #a8a8a8;
}

/* Animation classes */
.fade-in {
  animation: fadeIn 0.3s ease-in-out;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}
EOF

cat > frontend/src/main.jsx << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Create Vite config
cat > frontend/vite.config.js << 'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true
      }
    }
  },
  build: {
    outDir: 'build'
  }
});
EOF

# Create Tailwind config
cat > frontend/tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
        }
      }
    },
  },
  plugins: [],
}
EOF

cat > frontend/postcss.config.js << 'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

# Create HTML template
cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Feature Flag Logger</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

# Create test files
echo -e "${YELLOW}🧪 Creating test files...${NC}"
cat > backend/tests/test_feature_flags.py << 'EOF'
import pytest
import asyncio
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models.feature_flag import Base
from app.services.feature_flag_service import flag_service
from app.core.database import get_db

# Setup test database
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)

@pytest.fixture
def db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

@pytest.mark.asyncio
async def test_create_feature_flag(db):
    """Test creating a new feature flag"""
    flag = await flag_service.create_flag(
        db=db,
        name="test_flag",
        description="Test flag description",
        enabled=True,
        rollout_percentage="50"
    )
    
    assert flag.name == "test_flag"
    assert flag.enabled == True
    assert flag.rollout_percentage == "50"

@pytest.mark.asyncio
async def test_update_feature_flag(db):
    """Test updating an existing feature flag"""
    # Create flag first
    flag = await flag_service.create_flag(db=db, name="update_test", enabled=False)
    
    # Update the flag
    updated_flag = await flag_service.update_flag(
        db=db,
        flag_id=flag.id,
        updates={"enabled": True, "rollout_percentage": "75"}
    )
    
    assert updated_flag.enabled == True
    assert updated_flag.rollout_percentage == "75"

@pytest.mark.asyncio
async def test_evaluate_feature_flag(db):
    """Test feature flag evaluation"""
    # Create enabled flag with 100% rollout
    flag = await flag_service.create_flag(
        db=db,
        name="eval_test",
        enabled=True,
        rollout_percentage="100"
    )
    
    result = await flag_service.evaluate_flag(
        db=db,
        flag_name="eval_test",
        user_context={"user_id": "test_user"}
    )
    
    assert result == True

@pytest.mark.asyncio
async def test_delete_feature_flag(db):
    """Test deleting a feature flag"""
    # Create flag first
    flag = await flag_service.create_flag(db=db, name="delete_test")
    
    # Delete the flag
    result = await flag_service.delete_flag(db=db, flag_id=flag.id)
    
    assert result == True
    
    # Verify it's deleted
    flags = await flag_service.get_all_flags(db)
    flag_names = [f.name for f in flags]
    assert "delete_test" not in flag_names

if __name__ == "__main__":
    pytest.main([__file__])
EOF

# Create integration tests
cat > backend/tests/test_integration.py << 'EOF'
import pytest
import asyncio
from httpx import AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_create_flag_api():
    """Test creating flag through API"""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post("/api/v1/flags", json={
            "name": "api_test_flag",
            "description": "API test flag",
            "enabled": True,
            "rollout_percentage": "50"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "api_test_flag"
        assert data["enabled"] == True

@pytest.mark.asyncio
async def test_get_flags_api():
    """Test getting all flags through API"""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/api/v1/flags")
        
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

@pytest.mark.asyncio
async def test_evaluate_flag_api():
    """Test flag evaluation through API"""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        # Create flag first
        create_response = await ac.post("/api/v1/flags", json={
            "name": "eval_api_test",
            "enabled": True,
            "rollout_percentage": "100"
        })
        assert create_response.status_code == 200
        
        # Evaluate flag
        eval_response = await ac.post("/api/v1/flags/evaluate", json={
            "flag_name": "eval_api_test",
            "user_context": {"user_id": "test_user"},
            "default_value": False
        })
        
        assert eval_response.status_code == 200
        data = eval_response.json()
        assert data["enabled"] == True

if __name__ == "__main__":
    pytest.main([__file__])
EOF

# Create Docker configuration
echo -e "${YELLOW}🐳 Creating Docker configuration...${NC}"
cat > Dockerfile << 'EOF'
# Backend Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY backend/ .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: featureflags
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

  rabbitmq:
    image: rabbitmq:3.12-management-alpine
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

  backend:
    build: .
    ports:
      - "8000:8000"
    depends_on:
      - postgres
      - redis
      - rabbitmq
    environment:
      DATABASE_URL: postgresql://postgres:password@postgres:5432/featureflags
      REDIS_URL: redis://redis:6379/0
    volumes:
      - ./backend:/app
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    depends_on:
      - backend
    volumes:
      - ./frontend:/app
      - /app/node_modules

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
EOF

# Create frontend Dockerfile
cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
EOF

# Create dockerignore files
cat > .dockerignore << 'EOF'
node_modules
npm-debug.log*
.git
.gitignore
README.md
Dockerfile
.dockerignore
.env
.env.local
.env.production
.env.staging
build
coverage
EOF

cat > frontend/.dockerignore << 'EOF'
node_modules
build
.git
.env
EOF

# Create build script
echo -e "${YELLOW}🔨 Creating build script...${NC}"
cat > build.sh << 'EOF'
#!/bin/bash

set -e

echo "🚀 Building Feature Flag Status Logging System"
echo "=============================================="

# Create and activate virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv venv
fi

echo "🔌 Activating virtual environment..."
source venv/bin/activate

# Verify Python version
python_version=$(python --version 2>&1)
echo "✅ Using $python_version"

# Install backend dependencies
echo "📥 Installing backend dependencies..."
cd backend
pip install --upgrade pip
pip install -r requirements.txt
cd ..

# Install frontend dependencies
echo "📥 Installing frontend dependencies..."
cd frontend
npm install
cd ..

echo "✅ Build completed successfully!"
echo ""
echo "Next steps:"
echo "1. Run: ./start.sh (to start all services)"
echo "2. Open: http://localhost:3000 (frontend)"
echo "3. API: http://localhost:8000 (backend)"
echo "4. Run: ./test.sh (to run tests)"
EOF

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash

set -e

echo "🚀 Starting Feature Flag Status Logging System"
echo "=============================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Please run ./build.sh first."
    exit 1
fi

# Start services with Docker Compose
echo "🐳 Starting infrastructure services (PostgreSQL, Redis, RabbitMQ)..."
docker-compose up -d postgres redis rabbitmq

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if services are healthy
echo "🏥 Checking service health..."
docker-compose ps

# Activate virtual environment and start backend
echo "🔌 Activating virtual environment..."
source venv/bin/activate

echo "🖥️  Starting backend server..."
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
BACKEND_PID=$!
cd ..

# Start frontend
echo "⚛️  Starting frontend development server..."
cd frontend
npm run dev &
FRONTEND_PID=$!
cd ..

echo ""
echo "✅ All services started successfully!"
echo ""
echo "🌐 Access URLs:"
echo "  Frontend: http://localhost:3000"
echo "  Backend API: http://localhost:8000"
echo "  API Docs: http://localhost:8000/docs"
echo "  RabbitMQ Management: http://localhost:15672 (guest/guest)"
echo ""
echo "🛑 To stop all services: ./stop.sh"

# Save PIDs for stop script
echo $BACKEND_PID > .backend_pid
echo $FRONTEND_PID > .frontend_pid

# Wait for user input
echo "Press Ctrl+C to stop all services..."
wait
EOF

# Create test script
cat > test.sh << 'EOF'
#!/bin/bash

set -e

echo "🧪 Running Feature Flag Status Logging System Tests"
echo "=================================================="

# Activate virtual environment
source venv/bin/activate

# Run backend tests
echo "🐍 Running backend unit tests..."
cd backend
python -m pytest tests/ -v --tb=short
cd ..

# Run integration tests (if backend is running)
echo "🔗 Checking if backend is running for integration tests..."
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ Backend is running, running integration tests..."
    cd backend
    python -m pytest tests/test_integration.py -v
    cd ..
else
    echo "⚠️  Backend not running, skipping integration tests"
fi

# Test frontend build
echo "⚛️  Testing frontend build..."
cd frontend
npm run build
echo "✅ Frontend builds successfully"
cd ..

echo ""
echo "✅ All tests completed successfully!"
EOF

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Feature Flag Status Logging System"
echo "============================================="

# Stop backend process
if [ -f ".backend_pid" ]; then
    BACKEND_PID=$(cat .backend_pid)
    if kill -0 $BACKEND_PID 2>/dev/null; then
        echo "🔌 Stopping backend server..."
        kill $BACKEND_PID
    fi
    rm .backend_pid
fi

# Stop frontend process
if [ -f ".frontend_pid" ]; then
    FRONTEND_PID=$(cat .frontend_pid)
    if kill -0 $FRONTEND_PID 2>/dev/null; then
        echo "⚛️  Stopping frontend server..."
        kill $FRONTEND_PID
    fi
    rm .frontend_pid
fi

# Stop Docker services
echo "🐳 Stopping Docker services..."
docker-compose down

echo "✅ All services stopped successfully!"
EOF

# Create demo script
cat > demo.sh << 'EOF'
#!/bin/bash

set -e

echo "🎬 Feature Flag Status Logging System Demo"
echo "========================================"

# Check if services are running
if ! curl -s http://localhost:8000/health > /dev/null; then
    echo "❌ Backend not running. Please run ./start.sh first."
    exit 1
fi

echo "🎯 Creating demo feature flags..."

# Create sample flags
curl -s -X POST http://localhost:8000/api/v1/flags \
  -H "Content-Type: application/json" \
  -d '{
    "name": "dark_mode",
    "description": "Enable dark mode for the application",
    "enabled": true,
    "rollout_percentage": "50",
    "target_groups": ["beta-users", "premium-users"]
  }' > /dev/null

curl -s -X POST http://localhost:8000/api/v1/flags \
  -H "Content-Type: application/json" \
  -d '{
    "name": "new_checkout",
    "description": "New checkout flow with improved UX",
    "enabled": false,
    "rollout_percentage": "10",
    "target_groups": ["internal-users"]
  }' > /dev/null

curl -s -X POST http://localhost:8000/api/v1/flags \
  -H "Content-Type: application/json" \
  -d '{
    "name": "analytics_tracking",
    "description": "Enhanced analytics tracking",
    "enabled": true,
    "rollout_percentage": "100"
  }' > /dev/null

echo "✅ Created demo feature flags"

echo "🔄 Simulating flag evaluations..."

# Simulate flag evaluations
for i in {1..10}; do
  curl -s -X POST http://localhost:8000/api/v1/flags/evaluate \
    -H "Content-Type: application/json" \
    -d "{
      \"flag_name\": \"dark_mode\",
      \"user_context\": {\"user_id\": \"user_$i\", \"group\": \"beta-users\"},
      \"default_value\": false
    }" > /dev/null
done

echo "✅ Simulated 10 flag evaluations"

echo "🔧 Simulating flag updates..."

# Get dark_mode flag ID and update it
FLAG_ID=$(curl -s http://localhost:8000/api/v1/flags | jq -r '.[] | select(.name=="dark_mode") | .id')

curl -s -X PUT http://localhost:8000/api/v1/flags/$FLAG_ID \
  -H "Content-Type: application/json" \
  -d '{
    "rollout_percentage": "75",
    "description": "Enable dark mode for the application - Updated rollout"
  }' > /dev/null

echo "✅ Updated dark_mode flag rollout to 75%"

echo "📊 Fetching recent activity..."
curl -s http://localhost:8000/api/v1/logs/recent | jq '.[0:5] | .[] | {flag_name, event_type, timestamp}'

echo ""
echo "🎉 Demo completed successfully!"
echo ""
echo "🌐 Open these URLs to explore:"
echo "  • Frontend Dashboard: http://localhost:3000"
echo "  • Backend API Docs: http://localhost:8000/docs"
echo "  • Recent Logs: http://localhost:8000/api/v1/logs/recent"
EOF

# Make all scripts executable
chmod +x build.sh start.sh stop.sh test.sh demo.sh

echo -e "${YELLOW}📝 Creating README.md...${NC}"
cat > README.md << 'EOF'
# Feature Flag Status Logging System

A comprehensive feature flag management system with automatic status logging, built for Day 134 of the 254-Day System Design Series.

## 🎯 Features

- **Feature Flag Management**: Create, update, delete, and evaluate feature flags
- **Automatic Logging**: All flag interactions are automatically logged
- **Real-time Dashboard**: Monitor flag status and activity in real-time
- **Audit Trail**: Complete history of all flag changes and evaluations
- **High Performance**: Redis caching with database persistence
- **Scalable Architecture**: Designed for distributed systems

## 🏗️ Architecture

### Backend (Python 3.11 + FastAPI)
- **FastAPI**: Modern web framework for APIs
- **SQLAlchemy**: Database ORM with PostgreSQL
- **Redis**: High-performance caching and metrics
- **RabbitMQ**: Message queue for distributed logging
- **Structured Logging**: JSON-based logging for observability

### Frontend (React 18)
- **React**: Modern UI framework with hooks
- **Tailwind CSS**: Utility-first CSS framework
- **React Query**: Data fetching and caching
- **Recharts**: Beautiful charts for analytics
- **React Router**: Client-side routing

### Infrastructure
- **PostgreSQL**: Primary database for flag storage
- **Redis**: Caching and real-time metrics
- **RabbitMQ**: Message broker for event streaming
- **Docker**: Containerized deployment

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Node.js 18+
- Docker & Docker Compose

### 1. Build the System
```bash
./build.sh
```

### 2. Start All Services
```bash
./start.sh
```

### 3. Run Tests
```bash
./test.sh
```

### 4. View Demo
```bash
./demo.sh
```

### 5. Stop Services
```bash
./stop.sh
```

## 🌐 Access URLs

- **Frontend Dashboard**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **RabbitMQ Management**: http://localhost:15672 (guest/guest)

## 📊 API Endpoints

### Feature Flags
- `GET /api/v1/flags` - List all flags
- `POST /api/v1/flags` - Create new flag
- `PUT /api/v1/flags/{id}` - Update existing flag
- `DELETE /api/v1/flags/{id}` - Delete flag

### Flag Evaluation
- `POST /api/v1/flags/evaluate` - Evaluate flag for user context

### Audit Logs
- `GET /api/v1/logs/recent` - Get recent activity logs
- `GET /api/v1/flags/{name}/logs` - Get logs for specific flag

## 🧪 Testing

The system includes comprehensive testing:
- **Unit Tests**: Test individual components
- **Integration Tests**: Test API endpoints
- **Load Tests**: Performance validation

## 📝 Usage Examples

### Create Feature Flag
```bash
curl -X POST http://localhost:8000/api/v1/flags \
  -H "Content-Type: application/json" \
  -d '{
    "name": "new_feature",
    "description": "Enable new feature",
    "enabled": true,
    "rollout_percentage": "50",
    "target_groups": ["beta-users"]
  }'
```

### Evaluate Flag
```bash
curl -X POST http://localhost:8000/api/v1/flags/evaluate \
  -H "Content-Type: application/json" \
  -d '{
    "flag_name": "new_feature",
    "user_context": {"user_id": "user123", "group": "beta-users"},
    "default_value": false
  }'
```

## 🔧 Configuration

### Backend Configuration
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- Environment variables in `docker-compose.yml`

### Frontend Configuration
- `REACT_APP_API_URL`: Backend API URL
- Vite configuration in `vite.config.js`

## 📈 Monitoring & Observability

The system provides comprehensive observability:
- **Structured Logs**: JSON-formatted logs for analysis
- **Metrics Collection**: Flag evaluation counts and timing
- **Event Streaming**: All changes published to message queue
- **Real-time Dashboard**: Live monitoring of system activity

## 🏢 Production Considerations

- **Security**: Implement authentication and authorization
- **Scaling**: Use load balancers and multiple instances
- **Monitoring**: Add external monitoring (Prometheus, Grafana)
- **Backup**: Regular database and configuration backups

## 📚 Further Reading

This implementation demonstrates patterns used in production systems like:
- LaunchDarkly's feature flag service
- Facebook's GateKeeper system
- Netflix's feature rollout infrastructure

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is part of the 254-Day System Design Series.
EOF

echo -e "${GREEN}✅ All files created successfully!${NC}"
echo ""

# Execute the build process
echo -e "${BLUE}🏗️  Executing build process...${NC}"

# Make build script executable and run it
chmod +x build.sh
./build.sh

echo -e "${BLUE}🐳 Starting infrastructure services...${NC}"
docker-compose up -d postgres redis rabbitmq

echo -e "${YELLOW}⏳ Waiting for services to initialize...${NC}"
sleep 15

# Verify services are running
echo -e "${BLUE}🏥 Checking service health...${NC}"
docker-compose ps

# Start backend
echo -e "${BLUE}🖥️  Starting backend server...${NC}"
source venv/bin/activate
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
BACKEND_PID=$!
cd ..

# Wait for backend to start
sleep 10

# Test backend health
echo -e "${BLUE}🏥 Testing backend health...${NC}"
if curl -s http://localhost:8000/health; then
    echo -e "${GREEN}✅ Backend is healthy!${NC}"
else
    echo -e "${RED}❌ Backend health check failed${NC}"
fi

# Install frontend dependencies and start
echo -e "${BLUE}📦 Installing frontend dependencies...${NC}"
cd frontend
npm install
echo -e "${BLUE}⚛️  Starting frontend development server...${NC}"
npm run dev &
FRONTEND_PID=$!
cd ..

# Wait for frontend to start
sleep 10

# Run demo to populate data
echo -e "${BLUE}🎬 Running demo to populate sample data...${NC}"
chmod +x demo.sh
./demo.sh

# Run tests
echo -e "${BLUE}🧪 Running system tests...${NC}"
chmod +x test.sh
./test.sh

echo -e "${GREEN}🎉 Feature Flag Status Logging System Setup Complete!${NC}"
echo ""
echo -e "${BLUE}🌐 Access URLs:${NC}"
echo -e "${GREEN}  • Frontend Dashboard: http://localhost:3000${NC}"
echo -e "${GREEN}  • Backend API: http://localhost:8000${NC}"
echo -e "${GREEN}  • API Documentation: http://localhost:8000/docs${NC}"
echo -e "${GREEN}  • RabbitMQ Management: http://localhost:15672 (guest/guest)${NC}"
echo ""
echo -e "${BLUE}📊 Demo Features:${NC}"
echo -e "${GREEN}  ✅ 3 sample feature flags created${NC}"
echo -e "${GREEN}  ✅ 10 flag evaluations logged${NC}"
echo -e "${GREEN}  ✅ Flag update events recorded${NC}"
echo -e "${GREEN}  ✅ Real-time dashboard with charts${NC}"
echo -e "${GREEN}  ✅ Comprehensive audit logs${NC}"
echo ""
echo -e "${BLUE}🛑 To stop all services: ./stop.sh${NC}"

# Save PIDs for cleanup
echo $BACKEND_PID > .backend_pid
echo $FRONTEND_PID > .frontend_pid

echo -e "${YELLOW}⚠️  Keep this terminal open or services will stop${NC}"
echo -e "${YELLOW}⚠️  Press Ctrl+C to stop all services${NC}"