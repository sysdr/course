#!/bin/bash

# Day 132: Error Tracking Features Implementation Script
# Module 5: Integration and Ecosystem | Week 19: Application Integration

set -e

echo "🚀 Day 132: Implementing Error Tracking Features"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Create project directory structure
print_header "📁 Creating Project Structure..."

PROJECT_NAME="error-tracking-system"
mkdir -p ${PROJECT_NAME}
cd ${PROJECT_NAME}

# Create comprehensive directory structure
mkdir -p {backend/{app,tests,scripts},frontend/{src/{components,services,styles,utils},public,tests},docker,docs,data}
mkdir -p backend/app/{api,core,models,services}
mkdir -p frontend/src/components/{ErrorList,ErrorDetail,Dashboard,Alerts}
mkdir -p backend/tests/{unit,integration}
mkdir -p frontend/tests

print_status "Project structure created successfully"

# Create Python virtual environment
print_header "🐍 Setting up Python Virtual Environment..."

# Try python3.11 first, fallback to python3
if command -v python3.11 &> /dev/null; then
    PYTHON_CMD=python3.11
elif command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
else
    print_error "Python 3 not found. Please install Python 3.8 or higher."
    exit 1
fi

$PYTHON_CMD -m venv venv
source venv/bin/activate

# Upgrade pip and install setuptools (needed for Python 3.12+)
pip install --upgrade pip setuptools wheel

print_status "Python virtual environment activated"

# Create requirements.txt for backend
cat > backend/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
alembic==1.12.1
psycopg2-binary==2.9.9
redis==5.0.1
pydantic==2.5.0
pydantic-settings==2.1.0
python-multipart==0.0.6
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
aioredis==2.0.1
asyncpg==0.29.0
pytest==7.4.3
pytest-asyncio==0.21.1
httpx==0.25.2
structlog==23.2.0
scikit-learn==1.4.0
numpy==1.26.0
pandas==2.2.0
celery==5.3.4
kombu==5.3.4
aiofiles==23.2.1
Jinja2==3.1.2
python-dotenv==1.0.0
websockets==12.0
EOF

# Install Python dependencies
print_header "📦 Installing Python Dependencies..."
pip install -r backend/requirements.txt
print_status "Backend dependencies installed"

# Create backend application files
print_header "🔧 Creating Backend Application Files..."

# Main FastAPI application
cat > backend/app/main.py << 'EOF'
"""
Error Tracking System - Main FastAPI Application
Day 132: Error Tracking Features Implementation
"""

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import asyncio
import uvicorn
from contextlib import asynccontextmanager

from app.api import errors, groups, alerts, analytics
from app.core.config import settings
from app.core.database import init_db
from app.services.websocket_manager import WebSocketManager

# WebSocket connection manager
websocket_manager = WebSocketManager()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize application on startup"""
    await init_db()
    yield

# Create FastAPI application
app = FastAPI(
    title="Error Tracking System",
    description="Intelligent error tracking with automatic grouping",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(errors.router, prefix="/api/v1/errors", tags=["errors"])
app.include_router(groups.router, prefix="/api/v1/groups", tags=["groups"])
app.include_router(alerts.router, prefix="/api/v1/alerts", tags=["alerts"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["analytics"])

# WebSocket endpoint for real-time updates
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket_manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Handle client messages if needed
    except WebSocketDisconnect:
        websocket_manager.disconnect(websocket)

@app.get("/")
async def root():
    return {"message": "Error Tracking System API", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "error-tracking-api"}

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
EOF

# Database configuration
cat > backend/app/core/database.py << 'EOF'
"""Database configuration and connection management"""

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.ext.declarative import declarative_base
import redis.asyncio as redis
from app.core.config import settings

# PostgreSQL async engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_size=10,
    max_overflow=20,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)

Base = declarative_base()

# Redis connection
redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)

async def get_db_session():
    """Get database session"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def init_db():
    """Initialize database tables"""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
EOF

# Configuration settings
cat > backend/app/core/config.py << 'EOF'
"""Application configuration settings"""

from pydantic_settings import BaseSettings
from typing import Optional
import os

class Settings(BaseSettings):
    # Database settings
    DATABASE_URL: str = "postgresql+asyncpg://postgres:password@localhost:5432/errortracking"
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # Application settings
    DEBUG: bool = True
    SECRET_KEY: str = "your-secret-key-here"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # Error processing settings
    MAX_STACK_TRACE_LENGTH: int = 10000
    SIMILARITY_THRESHOLD: float = 0.8
    ERROR_BATCH_SIZE: int = 100
    FINGERPRINT_CACHE_TTL: int = 3600
    
    class Config:
        env_file = ".env"

settings = Settings()
EOF

# Error models
cat > backend/app/models/error.py << 'EOF'
"""Error and ErrorGroup database models"""

from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, JSON, ForeignKey, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.core.database import Base

class ErrorGroup(Base):
    __tablename__ = "error_groups"
    
    id = Column(Integer, primary_key=True, index=True)
    fingerprint = Column(String(64), unique=True, index=True)
    title = Column(String(500), nullable=False)
    status = Column(String(20), default="new")  # new, acknowledged, resolved, ignored
    first_seen = Column(DateTime, default=datetime.utcnow)
    last_seen = Column(DateTime, default=datetime.utcnow)
    count = Column(Integer, default=1)
    level = Column(String(10), default="error")  # debug, info, warning, error, critical
    platform = Column(String(50))
    tags = Column(JSON, default=dict)
    assigned_to = Column(String(100))
    resolved_at = Column(DateTime, nullable=True)
    
    # Relationships
    errors = relationship("Error", back_populates="group")

class Error(Base):
    __tablename__ = "errors"
    
    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("error_groups.id"), nullable=False)
    event_id = Column(String(36), default=lambda: str(uuid.uuid4()), unique=True)
    message = Column(Text, nullable=False)
    stack_trace = Column(Text)
    timestamp = Column(DateTime, default=datetime.utcnow)
    level = Column(String(10), default="error")
    platform = Column(String(50))
    release = Column(String(100))
    environment = Column(String(50), default="production")
    user_id = Column(String(100))
    request_id = Column(String(100))
    trace_id = Column(String(100))  # From distributed tracing
    span_id = Column(String(100))   # From distributed tracing
    context = Column(JSON, default=dict)
    tags = Column(JSON, default=dict)
    extra = Column(JSON, default=dict)
    
    # Relationships
    group = relationship("ErrorGroup", back_populates="errors")
EOF

# Error fingerprinting service
cat > backend/app/services/fingerprinting.py << 'EOF'
"""Error fingerprinting and similarity calculation service"""

import hashlib
import re
from typing import Dict, List, Optional, Tuple
import json
from difflib import SequenceMatcher

class ErrorFingerprinter:
    """Service for generating error fingerprints and calculating similarity"""
    
    def __init__(self):
        self.stack_trace_patterns = [
            r'\b\d+\b',  # Line numbers
            r'0x[0-9a-fA-F]+',  # Memory addresses
            r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',  # UUIDs
            r'\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\b',  # ISO timestamps
        ]
        
        self.message_patterns = [
            r'\b\d+\b',  # Numbers
            r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',  # UUIDs
            r'\b[\w._%+-]+@[\w.-]+\.\w+\b',  # Email addresses
            r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',  # IP addresses
        ]
    
    def generate_fingerprint(self, error_data: Dict) -> str:
        """Generate a unique fingerprint for an error"""
        # Extract key components
        message = self._normalize_message(error_data.get('message', ''))
        stack_trace = self._normalize_stack_trace(error_data.get('stack_trace', ''))
        error_type = error_data.get('type', '')
        
        # Create fingerprint components
        components = [
            error_type,
            message[:200],  # First 200 chars of normalized message
            self._get_stack_trace_signature(stack_trace)
        ]
        
        # Generate hash
        fingerprint_string = '|'.join(filter(None, components))
        return hashlib.sha256(fingerprint_string.encode()).hexdigest()[:16]
    
    def _normalize_message(self, message: str) -> str:
        """Normalize error message by removing dynamic content"""
        normalized = message
        for pattern in self.message_patterns:
            normalized = re.sub(pattern, '<DYNAMIC>', normalized)
        return normalized.strip()
    
    def _normalize_stack_trace(self, stack_trace: str) -> str:
        """Normalize stack trace by removing dynamic content"""
        if not stack_trace:
            return ""
        
        normalized = stack_trace
        for pattern in self.stack_trace_patterns:
            normalized = re.sub(pattern, '<NUM>', normalized)
        
        return normalized
    
    def _get_stack_trace_signature(self, stack_trace: str) -> str:
        """Extract a signature from the stack trace (top 3 frames)"""
        if not stack_trace:
            return ""
        
        lines = stack_trace.strip().split('\n')
        # Take first 3 meaningful lines
        signature_lines = []
        for line in lines[:10]:  # Look at first 10 lines
            line = line.strip()
            if line and not line.startswith('#'):
                # Extract function/method names
                if 'at ' in line:
                    parts = line.split('at ')
                    if len(parts) > 1:
                        signature_lines.append(parts[1].split('(')[0])
                elif 'in ' in line:
                    parts = line.split('in ')
                    if len(parts) > 1:
                        signature_lines.append(parts[1])
                
                if len(signature_lines) >= 3:
                    break
        
        return '->'.join(signature_lines)
    
    def calculate_similarity(self, error1: Dict, error2: Dict) -> float:
        """Calculate similarity score between two errors (0.0 - 1.0)"""
        # Message similarity (40% weight)
        message1 = self._normalize_message(error1.get('message', ''))
        message2 = self._normalize_message(error2.get('message', ''))
        message_sim = SequenceMatcher(None, message1, message2).ratio()
        
        # Stack trace similarity (50% weight)
        stack1 = self._normalize_stack_trace(error1.get('stack_trace', ''))
        stack2 = self._normalize_stack_trace(error2.get('stack_trace', ''))
        stack_sim = SequenceMatcher(None, stack1, stack2).ratio()
        
        # Context similarity (10% weight)
        context1 = error1.get('context', {})
        context2 = error2.get('context', {})
        context_sim = self._calculate_context_similarity(context1, context2)
        
        # Weighted average
        total_similarity = (message_sim * 0.4) + (stack_sim * 0.5) + (context_sim * 0.1)
        return round(total_similarity, 3)
    
    def _calculate_context_similarity(self, ctx1: Dict, ctx2: Dict) -> float:
        """Calculate similarity between error contexts"""
        if not ctx1 and not ctx2:
            return 1.0
        if not ctx1 or not ctx2:
            return 0.0
        
        # Compare common keys
        common_keys = set(ctx1.keys()) & set(ctx2.keys())
        if not common_keys:
            return 0.0
        
        matches = 0
        for key in common_keys:
            if ctx1[key] == ctx2[key]:
                matches += 1
        
        return matches / len(common_keys)

# Global instance
fingerprinter = ErrorFingerprinter()
EOF

# Error grouping service
cat > backend/app/services/grouping.py << 'EOF'
"""Error grouping and lifecycle management service"""

from typing import Dict, List, Optional
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
import json

from app.models.error import Error, ErrorGroup
from app.services.fingerprinting import fingerprinter
from app.core.config import settings

class ErrorGroupingService:
    """Service for managing error groups and lifecycle"""
    
    def __init__(self):
        self.similarity_threshold = settings.SIMILARITY_THRESHOLD
    
    async def process_error(self, session: AsyncSession, error_data: Dict) -> Dict:
        """Process a new error and assign it to a group"""
        # Generate fingerprint
        fingerprint = fingerprinter.generate_fingerprint(error_data)
        
        # Check if error group exists
        group = await self._find_or_create_group(session, fingerprint, error_data)
        
        # Create error record
        error = Error(
            group_id=group.id,
            message=error_data.get('message', ''),
            stack_trace=error_data.get('stack_trace', ''),
            level=error_data.get('level', 'error'),
            platform=error_data.get('platform', ''),
            release=error_data.get('release', ''),
            environment=error_data.get('environment', 'production'),
            user_id=error_data.get('user_id'),
            request_id=error_data.get('request_id'),
            trace_id=error_data.get('trace_id'),
            span_id=error_data.get('span_id'),
            context=error_data.get('context', {}),
            tags=error_data.get('tags', {}),
            extra=error_data.get('extra', {}),
        )
        
        session.add(error)
        
        # Update group statistics
        await self._update_group_stats(session, group)
        
        await session.commit()
        
        return {
            "error_id": error.event_id,
            "group_id": group.id,
            "fingerprint": fingerprint,
            "status": group.status
        }
    
    async def _find_or_create_group(self, session: AsyncSession, fingerprint: str, error_data: Dict) -> ErrorGroup:
        """Find existing group or create new one"""
        # Try exact fingerprint match first
        result = await session.execute(
            select(ErrorGroup).where(ErrorGroup.fingerprint == fingerprint)
        )
        group = result.scalar_one_or_none()
        
        if group:
            return group
        
        # Create new group
        group = ErrorGroup(
            fingerprint=fingerprint,
            title=self._generate_title(error_data),
            status="new",
            level=error_data.get('level', 'error'),
            platform=error_data.get('platform', ''),
            tags=error_data.get('tags', {})
        )
        
        session.add(group)
        await session.flush()
        return group
    
    async def _update_group_stats(self, session: AsyncSession, group: ErrorGroup):
        """Update group occurrence count and last seen"""
        group.count += 1
        group.last_seen = datetime.utcnow()
        
        # Check for regression
        if group.status == "resolved" and group.count > 0:
            group.status = "regressed"
    
    def _generate_title(self, error_data: Dict) -> str:
        """Generate a human-readable title for the error group"""
        message = error_data.get('message', '')
        error_type = error_data.get('type', '')
        
        # Try to extract meaningful title from message
        if message:
            # Normalize the message for title
            title = fingerprinter._normalize_message(message)
            if len(title) > 100:
                title = title[:97] + "..."
            return title
        
        if error_type:
            return f"{error_type}"
        
        return "Unknown Error"
    
    async def get_groups_summary(self, session: AsyncSession, filters: Dict = None) -> List[Dict]:
        """Get summary of error groups with filters"""
        query = select(ErrorGroup)
        
        # Apply filters
        if filters:
            if filters.get('status'):
                query = query.where(ErrorGroup.status == filters['status'])
            if filters.get('level'):
                query = query.where(ErrorGroup.level == filters['level'])
            if filters.get('platform'):
                query = query.where(ErrorGroup.platform == filters['platform'])
        
        # Order by last seen desc
        query = query.order_by(ErrorGroup.last_seen.desc())
        
        result = await session.execute(query)
        groups = result.scalars().all()
        
        summary = []
        for group in groups:
            summary.append({
                "id": group.id,
                "fingerprint": group.fingerprint,
                "title": group.title,
                "status": group.status,
                "count": group.count,
                "level": group.level,
                "platform": group.platform,
                "first_seen": group.first_seen.isoformat(),
                "last_seen": group.last_seen.isoformat(),
                "assigned_to": group.assigned_to,
            })
        
        return summary
    
    async def update_group_status(self, session: AsyncSession, group_id: int, status: str, assigned_to: str = None) -> bool:
        """Update error group status and assignment"""
        update_data = {"status": status}
        
        if assigned_to:
            update_data["assigned_to"] = assigned_to
            
        if status == "resolved":
            update_data["resolved_at"] = datetime.utcnow()
        
        result = await session.execute(
            update(ErrorGroup)
            .where(ErrorGroup.id == group_id)
            .values(**update_data)
        )
        
        await session.commit()
        return result.rowcount > 0

# Global instance
grouping_service = ErrorGroupingService()
EOF

# WebSocket manager for real-time updates
cat > backend/app/services/websocket_manager.py << 'EOF'
"""WebSocket manager for real-time error tracking updates"""

from typing import List, Dict
from fastapi import WebSocket
import json
import asyncio

class WebSocketManager:
    """Manages WebSocket connections for real-time updates"""
    
    def __init__(self):
        self.active_connections: List[WebSocket] = []
    
    async def connect(self, websocket: WebSocket):
        """Accept new WebSocket connection"""
        await websocket.accept()
        self.active_connections.append(websocket)
    
    def disconnect(self, websocket: WebSocket):
        """Remove WebSocket connection"""
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
    
    async def send_error_update(self, data: Dict):
        """Send error update to all connected clients"""
        if self.active_connections:
            message = json.dumps({
                "type": "error_update",
                "data": data
            })
            
            # Send to all connections, remove failed ones
            disconnected = []
            for connection in self.active_connections:
                try:
                    await connection.send_text(message)
                except:
                    disconnected.append(connection)
            
            # Clean up disconnected clients
            for connection in disconnected:
                self.disconnect(connection)
    
    async def send_group_update(self, data: Dict):
        """Send group update to all connected clients"""
        if self.active_connections:
            message = json.dumps({
                "type": "group_update", 
                "data": data
            })
            
            disconnected = []
            for connection in self.active_connections:
                try:
                    await connection.send_text(message)
                except:
                    disconnected.append(connection)
            
            for connection in disconnected:
                self.disconnect(connection)

# Global instance
websocket_manager = WebSocketManager()
EOF

# API routes for errors
cat > backend/app/api/errors.py << 'EOF'
"""Error collection and management API endpoints"""

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Dict, Optional
from datetime import datetime

from app.core.database import get_db_session
from app.services.grouping import grouping_service
from app.services.websocket_manager import websocket_manager
from app.models.error import Error, ErrorGroup

router = APIRouter()

@router.post("/collect")
async def collect_error(
    error_data: Dict,
    background_tasks: BackgroundTasks,
    session: AsyncSession = Depends(get_db_session)
):
    """Collect and process a new error"""
    try:
        # Process error through grouping service
        result = await grouping_service.process_error(session, error_data)
        
        # Send real-time update
        background_tasks.add_task(
            websocket_manager.send_error_update,
            {
                "event": "new_error",
                "error_id": result["error_id"],
                "group_id": result["group_id"],
                "fingerprint": result["fingerprint"]
            }
        )
        
        return {
            "success": True,
            "error_id": result["error_id"],
            "group_id": result["group_id"]
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing failed: {str(e)}")

@router.get("/groups")
async def get_error_groups(
    status: Optional[str] = None,
    level: Optional[str] = None,
    platform: Optional[str] = None,
    session: AsyncSession = Depends(get_db_session)
):
    """Get list of error groups with optional filters"""
    filters = {}
    if status:
        filters["status"] = status
    if level:
        filters["level"] = level  
    if platform:
        filters["platform"] = platform
    
    groups = await grouping_service.get_groups_summary(session, filters)
    return {"groups": groups}

@router.get("/groups/{group_id}")
async def get_error_group_detail(
    group_id: int,
    session: AsyncSession = Depends(get_db_session)
):
    """Get detailed information about an error group"""
    # Get group info
    result = await session.execute(
        select(ErrorGroup).where(ErrorGroup.id == group_id)
    )
    group = result.scalar_one_or_none()
    
    if not group:
        raise HTTPException(status_code=404, detail="Error group not found")
    
    # Get recent errors in group
    result = await session.execute(
        select(Error)
        .where(Error.group_id == group_id)
        .order_by(Error.timestamp.desc())
        .limit(50)
    )
    errors = result.scalars().all()
    
    error_list = []
    for error in errors:
        error_list.append({
            "id": error.event_id,
            "message": error.message,
            "timestamp": error.timestamp.isoformat(),
            "level": error.level,
            "platform": error.platform,
            "release": error.release,
            "environment": error.environment,
            "user_id": error.user_id,
            "trace_id": error.trace_id,
            "context": error.context,
            "tags": error.tags
        })
    
    return {
        "group": {
            "id": group.id,
            "fingerprint": group.fingerprint,
            "title": group.title,
            "status": group.status,
            "count": group.count,
            "level": group.level,
            "platform": group.platform,
            "first_seen": group.first_seen.isoformat(),
            "last_seen": group.last_seen.isoformat(),
            "assigned_to": group.assigned_to,
            "tags": group.tags
        },
        "errors": error_list
    }

@router.put("/groups/{group_id}/status")
async def update_group_status(
    group_id: int,
    status_data: Dict,
    background_tasks: BackgroundTasks,
    session: AsyncSession = Depends(get_db_session)
):
    """Update error group status"""
    status = status_data.get("status")
    assigned_to = status_data.get("assigned_to")
    
    if not status:
        raise HTTPException(status_code=400, detail="Status is required")
    
    if status not in ["new", "acknowledged", "resolved", "ignored"]:
        raise HTTPException(status_code=400, detail="Invalid status")
    
    success = await grouping_service.update_group_status(session, group_id, status, assigned_to)
    
    if not success:
        raise HTTPException(status_code=404, detail="Error group not found")
    
    # Send real-time update
    background_tasks.add_task(
        websocket_manager.send_group_update,
        {
            "event": "status_updated",
            "group_id": group_id,
            "status": status,
            "assigned_to": assigned_to
        }
    )
    
    return {"success": True, "message": "Status updated successfully"}

@router.get("/search")
async def search_errors(
    query: str,
    session: AsyncSession = Depends(get_db_session)
):
    """Search errors by message content"""
    result = await session.execute(
        select(Error)
        .join(ErrorGroup)
        .where(Error.message.ilike(f"%{query}%"))
        .order_by(Error.timestamp.desc())
        .limit(100)
    )
    
    errors = result.scalars().all()
    
    search_results = []
    for error in errors:
        search_results.append({
            "error_id": error.event_id,
            "group_id": error.group_id,
            "message": error.message,
            "timestamp": error.timestamp.isoformat(),
            "level": error.level,
            "platform": error.platform
        })
    
    return {"results": search_results, "count": len(search_results)}
EOF

# Create remaining API files
cat > backend/app/api/groups.py << 'EOF'
"""Error group management API endpoints"""

from fastapi import APIRouter

router = APIRouter()

@router.get("/")
async def list_groups():
    return {"message": "Error groups endpoint"}
EOF

cat > backend/app/api/alerts.py << 'EOF'
"""Alert management API endpoints"""

from fastapi import APIRouter

router = APIRouter()

@router.get("/")
async def list_alerts():
    return {"message": "Alerts endpoint"}
EOF

cat > backend/app/api/analytics.py << 'EOF'
"""Analytics API endpoints"""

from fastapi import APIRouter

router = APIRouter()

@router.get("/")
async def get_analytics():
    return {"message": "Analytics endpoint"}
EOF

# Create __init__.py files
touch backend/app/__init__.py
touch backend/app/api/__init__.py
touch backend/app/core/__init__.py
touch backend/app/models/__init__.py
touch backend/app/services/__init__.py

print_status "Backend application files created"

# Create frontend React application
print_header "⚛️ Creating React Frontend Application..."

# Create package.json for frontend
cat > frontend/package.json << 'EOF'
{
  "name": "error-tracking-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@testing-library/jest-dom": "^6.1.4",
    "@testing-library/react": "^13.4.0",
    "@testing-library/user-event": "^14.5.1",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "^5.0.1",
    "react-router-dom": "^6.18.0",
    "axios": "^1.6.0",
    "tailwindcss": "^3.3.5",
    "@tailwindcss/forms": "^0.5.7",
    "date-fns": "^2.30.0",
    "recharts": "^2.8.0",
    "lucide-react": "^0.292.0",
    "@headlessui/react": "^1.7.17",
    "classnames": "^2.3.2",
    "web-vitals": "^3.5.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "devDependencies": {
    "@types/react": "^18.2.37",
    "@types/react-dom": "^18.2.15"
  },
  "proxy": "http://localhost:8000"
}
EOF

# Install Node.js dependencies (if Node.js is available)
# Skip npm install to speed up setup - can be run manually later
if command -v node &> /dev/null; then
    print_status "Node.js found. Frontend dependencies can be installed later with: cd frontend && npm install"
else
    print_warning "Node.js not found. Frontend dependencies not installed."
fi

# Create main React App component
cat > frontend/src/App.js << 'EOF'
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Dashboard from './components/Dashboard/Dashboard';
import ErrorList from './components/ErrorList/ErrorList';
import ErrorDetail from './components/ErrorDetail/ErrorDetail';
import Navigation from './components/Navigation';
import './App.css';

function App() {
  return (
    <Router>
      <div className="App min-h-screen bg-gray-50">
        <Navigation />
        <main className="container mx-auto px-4 py-8">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/errors" element={<ErrorList />} />
            <Route path="/errors/:groupId" element={<ErrorDetail />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;
EOF

# Create Navigation component
cat > frontend/src/components/Navigation.js << 'EOF'
import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { AlertTriangle, BarChart3, List } from 'lucide-react';

const Navigation = () => {
  const location = useLocation();
  
  const navItems = [
    { path: '/', name: 'Dashboard', icon: BarChart3 },
    { path: '/errors', name: 'Error Groups', icon: List },
  ];
  
  return (
    <nav className="bg-white shadow-sm border-b border-gray-200">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-2">
              <AlertTriangle className="h-8 w-8 text-red-500" />
              <h1 className="text-xl font-bold text-gray-900">Error Tracker</h1>
            </div>
            <div className="hidden md:flex space-x-4">
              {navItems.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    className={`flex items-center space-x-2 px-3 py-2 rounded-md text-sm font-medium ${
                      location.pathname === item.path
                        ? 'bg-blue-100 text-blue-700'
                        : 'text-gray-500 hover:text-gray-700 hover:bg-gray-100'
                    }`}
                  >
                    <Icon className="h-4 w-4" />
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

# Create Dashboard component
cat > frontend/src/components/Dashboard/Dashboard.js << 'EOF'
import React, { useState, useEffect } from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line } from 'recharts';
import { AlertCircle, TrendingUp, Clock, Users } from 'lucide-react';
import api from '../../services/api';

const Dashboard = () => {
  const [stats, setStats] = useState({
    totalErrors: 0,
    activeGroups: 0,
    resolvedToday: 0,
    criticalErrors: 0
  });
  const [errorTrends, setErrorTrends] = useState([]);
  const [recentGroups, setRecentGroups] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      const [groupsResponse] = await Promise.all([
        api.get('/errors/groups')
      ]);
      
      const groups = groupsResponse.data.groups || [];
      
      // Calculate stats
      const newStats = {
        totalErrors: groups.reduce((sum, group) => sum + group.count, 0),
        activeGroups: groups.filter(g => g.status !== 'resolved').length,
        resolvedToday: groups.filter(g => 
          g.status === 'resolved' && 
          new Date(g.resolved_at) > new Date(Date.now() - 24*60*60*1000)
        ).length,
        criticalErrors: groups.filter(g => g.level === 'critical').length
      };
      
      setStats(newStats);
      setRecentGroups(groups.slice(0, 5));
      
      // Generate mock trend data (in real app, this would come from API)
      const trendData = Array.from({ length: 7 }, (_, i) => ({
        day: new Date(Date.now() - (6-i) * 24*60*60*1000).toLocaleDateString('en-US', { weekday: 'short' }),
        errors: Math.floor(Math.random() * 100) + 20
      }));
      setErrorTrends(trendData);
      
    } catch (error) {
      console.error('Failed to load dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  const StatCard = ({ title, value, icon: Icon, trend, color = "blue" }) => (
    <div className="bg-white rounded-lg p-6 shadow-sm border border-gray-200">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className={`text-2xl font-bold text-${color}-600 mt-1`}>{value}</p>
          {trend && (
            <div className="flex items-center mt-2">
              <TrendingUp className="h-4 w-4 text-green-500" />
              <span className="text-sm text-green-600 ml-1">{trend}</span>
            </div>
          )}
        </div>
        <Icon className={`h-8 w-8 text-${color}-500`} />
      </div>
    </div>
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold text-gray-900">Error Tracking Dashboard</h1>
        <button 
          onClick={loadDashboardData}
          className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors"
        >
          Refresh
        </button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Errors"
          value={stats.totalErrors}
          icon={AlertCircle}
          color="red"
        />
        <StatCard
          title="Active Groups"
          value={stats.activeGroups}
          icon={Users}
          color="orange"
        />
        <StatCard
          title="Resolved Today"
          value={stats.resolvedToday}
          icon={Clock}
          color="green"
        />
        <StatCard
          title="Critical Errors"
          value={stats.criticalErrors}
          icon={AlertCircle}
          color="red"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Error Trends</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={errorTrends}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="day" />
              <YAxis />
              <Tooltip />
              <Line type="monotone" dataKey="errors" stroke="#3B82F6" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Recent Error Groups</h3>
          <div className="space-y-3">
            {recentGroups.map(group => (
              <div key={group.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
                <div>
                  <p className="font-medium text-gray-900 truncate max-w-xs">{group.title}</p>
                  <div className="flex items-center space-x-2 mt-1">
                    <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
                      group.status === 'new' ? 'bg-red-100 text-red-800' :
                      group.status === 'acknowledged' ? 'bg-yellow-100 text-yellow-800' :
                      'bg-green-100 text-green-800'
                    }`}>
                      {group.status}
                    </span>
                    <span className="text-sm text-gray-500">{group.count} occurrences</span>
                  </div>
                </div>
                <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
                  group.level === 'critical' ? 'bg-red-100 text-red-800' :
                  group.level === 'error' ? 'bg-orange-100 text-orange-800' :
                  'bg-yellow-100 text-yellow-800'
                }`}>
                  {group.level}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
EOF

# Create ErrorList component
cat > frontend/src/components/ErrorList/ErrorList.js << 'EOF'
import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { AlertCircle, Clock, Filter } from 'lucide-react';
import api from '../../services/api';

const ErrorList = () => {
  const [groups, setGroups] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({
    status: '',
    level: '',
    platform: ''
  });

  useEffect(() => {
    loadErrorGroups();
  }, [filters]);

  const loadErrorGroups = async () => {
    setLoading(true);
    try {
      const params = Object.entries(filters)
        .filter(([key, value]) => value)
        .reduce((acc, [key, value]) => ({ ...acc, [key]: value }), {});
      
      const response = await api.get('/errors/groups', { params });
      setGroups(response.data.groups || []);
    } catch (error) {
      console.error('Failed to load error groups:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateGroupStatus = async (groupId, status) => {
    try {
      await api.put(`/errors/groups/${groupId}/status`, { status });
      loadErrorGroups(); // Reload data
    } catch (error) {
      console.error('Failed to update group status:', error);
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'new': return 'bg-red-100 text-red-800';
      case 'acknowledged': return 'bg-yellow-100 text-yellow-800';
      case 'resolved': return 'bg-green-100 text-green-800';
      case 'ignored': return 'bg-gray-100 text-gray-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const getLevelColor = (level) => {
    switch (level) {
      case 'critical': return 'bg-red-100 text-red-800';
      case 'error': return 'bg-orange-100 text-orange-800';
      case 'warning': return 'bg-yellow-100 text-yellow-800';
      case 'info': return 'bg-blue-100 text-blue-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold text-gray-900">Error Groups</h1>
        <button 
          onClick={loadErrorGroups}
          className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors"
        >
          Refresh
        </button>
      </div>

      {/* Filters */}
      <div className="bg-white p-4 rounded-lg shadow-sm border border-gray-200">
        <div className="flex items-center space-x-4">
          <Filter className="h-5 w-5 text-gray-500" />
          <select
            value={filters.status}
            onChange={(e) => setFilters({ ...filters, status: e.target.value })}
            className="border border-gray-300 rounded-md px-3 py-2"
          >
            <option value="">All Statuses</option>
            <option value="new">New</option>
            <option value="acknowledged">Acknowledged</option>
            <option value="resolved">Resolved</option>
            <option value="ignored">Ignored</option>
          </select>
          <select
            value={filters.level}
            onChange={(e) => setFilters({ ...filters, level: e.target.value })}
            className="border border-gray-300 rounded-md px-3 py-2"
          >
            <option value="">All Levels</option>
            <option value="critical">Critical</option>
            <option value="error">Error</option>
            <option value="warning">Warning</option>
            <option value="info">Info</option>
          </select>
        </div>
      </div>

      {/* Error Groups List */}
      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        </div>
      ) : (
        <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
          <div className="divide-y divide-gray-200">
            {groups.length === 0 ? (
              <div className="p-8 text-center">
                <AlertCircle className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                <p className="text-gray-500">No error groups found</p>
              </div>
            ) : (
              groups.map(group => (
                <div key={group.id} className="p-6 hover:bg-gray-50">
                  <div className="flex items-center justify-between">
                    <div className="flex-1 min-w-0">
                      <Link 
                        to={`/errors/${group.id}`}
                        className="text-lg font-medium text-gray-900 hover:text-blue-600 truncate block"
                      >
                        {group.title}
                      </Link>
                      <div className="flex items-center space-x-4 mt-2">
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(group.status)}`}>
                          {group.status}
                        </span>
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getLevelColor(group.level)}`}>
                          {group.level}
                        </span>
                        <span className="text-sm text-gray-500">
                          {group.count} occurrences
                        </span>
                        <span className="text-sm text-gray-500 flex items-center">
                          <Clock className="h-4 w-4 mr-1" />
                          {formatDate(group.last_seen)}
                        </span>
                      </div>
                    </div>
                    <div className="flex items-center space-x-2">
                      {group.status === 'new' && (
                        <button
                          onClick={() => updateGroupStatus(group.id, 'acknowledged')}
                          className="bg-yellow-600 text-white px-3 py-1 rounded text-sm hover:bg-yellow-700"
                        >
                          Acknowledge
                        </button>
                      )}
                      {group.status === 'acknowledged' && (
                        <button
                          onClick={() => updateGroupStatus(group.id, 'resolved')}
                          className="bg-green-600 text-white px-3 py-1 rounded text-sm hover:bg-green-700"
                        >
                          Resolve
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default ErrorList;
EOF

# Create ErrorDetail component
cat > frontend/src/components/ErrorDetail/ErrorDetail.js << 'EOF'
import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft, Clock, User, Tag } from 'lucide-react';
import api from '../../services/api';

const ErrorDetail = () => {
  const { groupId } = useParams();
  const navigate = useNavigate();
  const [group, setGroup] = useState(null);
  const [errors, setErrors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedError, setSelectedError] = useState(null);

  useEffect(() => {
    loadErrorDetail();
  }, [groupId]);

  const loadErrorDetail = async () => {
    setLoading(true);
    try {
      const response = await api.get(`/errors/groups/${groupId}`);
      setGroup(response.data.group);
      setErrors(response.data.errors);
      if (response.data.errors.length > 0) {
        setSelectedError(response.data.errors[0]);
      }
    } catch (error) {
      console.error('Failed to load error detail:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleString();
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!group) {
    return (
      <div className="text-center">
        <p className="text-gray-500">Error group not found</p>
        <button 
          onClick={() => navigate('/errors')}
          className="mt-4 bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
        >
          Back to Error Groups
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center space-x-4">
        <button 
          onClick={() => navigate('/errors')}
          className="flex items-center text-gray-600 hover:text-gray-900"
        >
          <ArrowLeft className="h-5 w-5 mr-1" />
          Back
        </button>
        <h1 className="text-3xl font-bold text-gray-900 truncate">{group.title}</h1>
      </div>

      {/* Error Group Info */}
      <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div>
            <p className="text-sm font-medium text-gray-600">Status</p>
            <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-sm font-medium mt-1 ${
              group.status === 'new' ? 'bg-red-100 text-red-800' :
              group.status === 'acknowledged' ? 'bg-yellow-100 text-yellow-800' :
              'bg-green-100 text-green-800'
            }`}>
              {group.status}
            </span>
          </div>
          <div>
            <p className="text-sm font-medium text-gray-600">Level</p>
            <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-sm font-medium mt-1 ${
              group.level === 'critical' ? 'bg-red-100 text-red-800' :
              group.level === 'error' ? 'bg-orange-100 text-orange-800' :
              'bg-yellow-100 text-yellow-800'
            }`}>
              {group.level}
            </span>
          </div>
          <div>
            <p className="text-sm font-medium text-gray-600">Occurrences</p>
            <p className="text-lg font-semibold text-gray-900 mt-1">{group.count}</p>
          </div>
          <div>
            <p className="text-sm font-medium text-gray-600">Platform</p>
            <p className="text-lg font-semibold text-gray-900 mt-1">{group.platform || 'N/A'}</p>
          </div>
        </div>
        
        <div className="mt-6 pt-6 border-t border-gray-200">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <p className="text-sm font-medium text-gray-600 flex items-center">
                <Clock className="h-4 w-4 mr-1" />
                First Seen
              </p>
              <p className="text-sm text-gray-900 mt-1">{formatDate(group.first_seen)}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-gray-600 flex items-center">
                <Clock className="h-4 w-4 mr-1" />
                Last Seen
              </p>
              <p className="text-sm text-gray-900 mt-1">{formatDate(group.last_seen)}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Error Instances */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Error List */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="p-4 border-b border-gray-200">
            <h3 className="text-lg font-semibold text-gray-900">Recent Occurrences</h3>
          </div>
          <div className="divide-y divide-gray-200 max-h-96 overflow-y-auto">
            {errors.map(error => (
              <div 
                key={error.id}
                onClick={() => setSelectedError(error)}
                className={`p-4 cursor-pointer hover:bg-gray-50 ${
                  selectedError?.id === error.id ? 'bg-blue-50 border-l-4 border-blue-500' : ''
                }`}
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium text-gray-900">
                    {formatDate(error.timestamp)}
                  </span>
                  {error.trace_id && (
                    <span className="text-xs text-blue-600 bg-blue-100 px-2 py-1 rounded">
                      Trace: {error.trace_id.slice(0, 8)}...
                    </span>
                  )}
                </div>
                <p className="text-sm text-gray-600 mt-1 truncate">{error.message}</p>
                {error.user_id && (
                  <div className="flex items-center mt-1">
                    <User className="h-3 w-3 text-gray-400 mr-1" />
                    <span className="text-xs text-gray-500">{error.user_id}</span>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Error Details */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="p-4 border-b border-gray-200">
            <h3 className="text-lg font-semibold text-gray-900">Error Details</h3>
          </div>
          {selectedError ? (
            <div className="p-4 space-y-4">
              <div>
                <h4 className="text-sm font-medium text-gray-600 mb-2">Message</h4>
                <p className="text-sm text-gray-900 bg-gray-50 p-3 rounded-md">{selectedError.message}</p>
              </div>
              
              {selectedError.stack_trace && (
                <div>
                  <h4 className="text-sm font-medium text-gray-600 mb-2">Stack Trace</h4>
                  <pre className="text-xs text-gray-900 bg-gray-50 p-3 rounded-md overflow-x-auto max-h-64">
                    {selectedError.stack_trace}
                  </pre>
                </div>
              )}
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <h4 className="text-sm font-medium text-gray-600 mb-1">Environment</h4>
                  <p className="text-sm text-gray-900">{selectedError.environment}</p>
                </div>
                <div>
                  <h4 className="text-sm font-medium text-gray-600 mb-1">Release</h4>
                  <p className="text-sm text-gray-900">{selectedError.release || 'N/A'}</p>
                </div>
              </div>
              
              {Object.keys(selectedError.context || {}).length > 0 && (
                <div>
                  <h4 className="text-sm font-medium text-gray-600 mb-2">Context</h4>
                  <pre className="text-xs text-gray-900 bg-gray-50 p-3 rounded-md overflow-x-auto">
                    {JSON.stringify(selectedError.context, null, 2)}
                  </pre>
                </div>
              )}
            </div>
          ) : (
            <div className="p-8 text-center text-gray-500">
              Select an error occurrence to view details
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default ErrorDetail;
EOF

# Create API service
cat > frontend/src/services/api.js << 'EOF'
import axios from 'axios';

// Create axios instance with base configuration
const api = axios.create({
  baseURL: '/api/v1',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor
api.interceptors.request.use(
  (config) => {
    // Add auth token if available
    const token = localStorage.getItem('authToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor
api.interceptors.response.use(
  (response) => response,
  (error) => {
    console.error('API Error:', error);
    return Promise.reject(error);
  }
);

export default api;
EOF

# Create CSS files
cat > frontend/src/App.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

.App {
  text-align: left;
}

/* Custom scrollbar styles */
.overflow-y-auto::-webkit-scrollbar {
  width: 8px;
}

.overflow-y-auto::-webkit-scrollbar-track {
  background: #f1f1f1;
  border-radius: 4px;
}

.overflow-y-auto::-webkit-scrollbar-thumb {
  background: #c1c1c1;
  border-radius: 4px;
}

.overflow-y-auto::-webkit-scrollbar-thumb:hover {
  background: #a8a8a8;
}

/* Loading spinner */
.animate-spin {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
EOF

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
EOF

# Create index.js
cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Create tailwind config
cat > frontend/tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/forms'),
  ],
}
EOF

# Create public HTML
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta
      name="description"
      content="Error Tracking System - Intelligent error monitoring and grouping"
    />
    <title>Error Tracking System</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

# Create tests
cat > backend/tests/test_fingerprinting.py << 'EOF'
"""Tests for error fingerprinting service"""

import pytest
from app.services.fingerprinting import fingerprinter

def test_generate_fingerprint():
    """Test fingerprint generation"""
    error_data = {
        "message": "Database connection failed: Connection timeout after 30s",
        "stack_trace": "at line 123 in database.py",
        "type": "ConnectionError"
    }
    
    fingerprint = fingerprinter.generate_fingerprint(error_data)
    assert len(fingerprint) == 16
    assert isinstance(fingerprint, str)

def test_fingerprint_consistency():
    """Test that same error generates same fingerprint"""
    error_data = {
        "message": "User 12345 not found",
        "stack_trace": "at line 100 in user_service.py",
        "type": "UserNotFoundError"
    }
    
    fingerprint1 = fingerprinter.generate_fingerprint(error_data)
    fingerprint2 = fingerprinter.generate_fingerprint(error_data)
    assert fingerprint1 == fingerprint2

def test_normalize_message():
    """Test message normalization"""
    original = "User 12345 failed to login at 192.168.1.1"
    normalized = fingerprinter._normalize_message(original)
    assert "12345" not in normalized
    assert "192.168.1.1" not in normalized
    assert "<DYNAMIC>" in normalized

def test_calculate_similarity():
    """Test similarity calculation between errors"""
    error1 = {
        "message": "Database timeout",
        "stack_trace": "at database.connect() line 100"
    }
    error2 = {
        "message": "Database timeout", 
        "stack_trace": "at database.connect() line 101"
    }
    
    similarity = fingerprinter.calculate_similarity(error1, error2)
    assert similarity > 0.8  # Should be highly similar
EOF

cat > backend/tests/test_grouping.py << 'EOF'
"""Tests for error grouping service"""

import pytest
from unittest.mock import AsyncMock, MagicMock
from app.services.grouping import grouping_service

@pytest.mark.asyncio
async def test_process_error():
    """Test error processing and grouping"""
    mock_session = AsyncMock()
    mock_session.execute = AsyncMock()
    mock_session.commit = AsyncMock()
    mock_session.flush = AsyncMock()
    
    error_data = {
        "message": "Test error message",
        "stack_trace": "Test stack trace",
        "level": "error",
        "platform": "python"
    }
    
    # Mock that no existing group is found
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_session.execute.return_value = mock_result
    
    # Process should create new group and error
    result = await grouping_service.process_error(mock_session, error_data)
    
    assert "error_id" in result
    assert "group_id" in result
    assert "fingerprint" in result
EOF

# Create Docker configuration
print_header "🐳 Creating Docker Configuration..."

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: errortracking
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  backend:
    build: 
      context: .
      dockerfile: docker/backend.Dockerfile
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql+asyncpg://postgres:password@postgres:5432/errortracking
      REDIS_URL: redis://redis:6379/0
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./backend:/app
    command: python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

  frontend:
    build:
      context: .
      dockerfile: docker/frontend.Dockerfile
    ports:
      - "3000:3000"
    volumes:
      - ./frontend:/app
      - /app/node_modules
    environment:
      REACT_APP_API_URL: http://localhost:8000
    command: npm start

volumes:
  postgres_data:
  redis_data:
EOF

cat > docker/backend.Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY backend/ .

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > docker/frontend.Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY frontend/package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY frontend/ .

EXPOSE 3000

CMD ["npm", "start"]
EOF

# Create .dockerignore
cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
Dockerfile
.dockerignore
.git
.gitignore
README.md
.env
.nyc_output
coverage
.nyc_output
.coverage
.pytest_cache
__pycache__
*.pyc
*.pyo
*.pyd
.Python
venv/
*.log
EOF

# Create environment file
cat > .env << 'EOF'
# Database Configuration
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/errortracking
REDIS_URL=redis://localhost:6379/0

# Application Configuration
DEBUG=True
SECRET_KEY=your-secret-key-here-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Error Processing Configuration
MAX_STACK_TRACE_LENGTH=10000
SIMILARITY_THRESHOLD=0.8
ERROR_BATCH_SIZE=100
FINGERPRINT_CACHE_TTL=3600
EOF

# Create build script
cat > build.sh << 'EOF'
#!/bin/bash

echo "🔨 Building Error Tracking System..."

# Activate virtual environment
source venv/bin/activate

# Install backend dependencies
echo "📦 Installing backend dependencies..."
pip install -r backend/requirements.txt

# Install frontend dependencies (if Node.js available)
if command -v node &> /dev/null; then
    echo "📦 Installing frontend dependencies..."
    cd frontend && npm install && cd ..
else
    echo "⚠️ Node.js not found, skipping frontend dependencies"
fi

echo "✅ Build completed successfully!"
EOF

chmod +x build.sh

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Error Tracking System..."

# Check if using Docker
if [ "$1" = "docker" ]; then
    echo "🐳 Starting with Docker Compose..."
    docker-compose up --build
else
    echo "🏃 Starting local development servers..."
    
    # Start PostgreSQL and Redis (assuming they're running locally)
    
    # Start backend in background
    echo "🔧 Starting backend server..."
    source venv/bin/activate
    cd backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
    BACKEND_PID=$!
    cd ..
    
    # Start frontend if Node.js is available
    if command -v node &> /dev/null; then
        echo "⚛️ Starting frontend server..."
        cd frontend && npm start &
        FRONTEND_PID=$!
        cd ..
    fi
    
    echo "✅ Services started!"
    echo "🌐 Backend API: http://localhost:8000"
    echo "🌐 Frontend: http://localhost:3000"
    echo "📊 API Docs: http://localhost:8000/docs"
    
    # Wait for interrupt
    trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null" EXIT
    wait
fi
EOF

chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Error Tracking System..."

if [ "$1" = "docker" ]; then
    docker-compose down
else
    # Kill processes by port
    lsof -ti:8000 | xargs kill -9 2>/dev/null || true
    lsof -ti:3000 | xargs kill -9 2>/dev/null || true
fi

echo "✅ Services stopped!"
EOF

chmod +x stop.sh

# Create test script
print_header "🧪 Creating Test Suite..."

cat > test.sh << 'EOF'
#!/bin/bash

echo "🧪 Running Error Tracking System Tests..."

# Activate virtual environment
source venv/bin/activate

# Run backend tests
echo "🔧 Running backend tests..."
cd backend
python -m pytest tests/ -v --tb=short
TEST_EXIT_CODE=$?
cd ..

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed!"
    exit 1
fi
EOF

chmod +x test.sh

# Create demo script with error injection
cat > demo.py << 'EOF'
#!/usr/bin/env python3
"""
Demo script to showcase error tracking system
Generates various types of errors to demonstrate functionality
"""

import asyncio
import aiohttp
import json
import random
import time
from datetime import datetime

BASE_URL = "http://localhost:8000/api/v1"

# Sample error templates
ERROR_TEMPLATES = [
    {
        "message": "Database connection timeout after {timeout}s",
        "stack_trace": "at database.py line 123\n  at connection_pool.get() line 45\n  at service.connect() line 67",
        "type": "ConnectionTimeoutError",
        "level": "error",
        "platform": "python"
    },
    {
        "message": "User {user_id} not found in database",
        "stack_trace": "at user_service.py line 89\n  at get_user() line 23\n  at api.users() line 156",
        "type": "UserNotFoundError", 
        "level": "warning",
        "platform": "python"
    },
    {
        "message": "Payment processing failed: Invalid card number",
        "stack_trace": "at payment.py line 234\n  at validate_card() line 12\n  at process_payment() line 45",
        "type": "PaymentError",
        "level": "critical",
        "platform": "python"
    },
    {
        "message": "Memory allocation failed: Out of memory",
        "stack_trace": "at memory.c line 567\n  at malloc() line 34\n  at allocate_buffer() line 78",
        "type": "MemoryError",
        "level": "critical",
        "platform": "c++"
    },
    {
        "message": "API rate limit exceeded: {rate}/minute",
        "stack_trace": "at rate_limiter.py line 45\n  at check_limit() line 23\n  at api_middleware() line 89",
        "type": "RateLimitError",
        "level": "warning",
        "platform": "python"
    }
]

async def generate_error(session, template):
    """Generate a single error based on template"""
    # Fill in template variables
    error_data = template.copy()
    
    if "{timeout}" in error_data["message"]:
        error_data["message"] = error_data["message"].format(timeout=random.randint(10, 60))
    
    if "{user_id}" in error_data["message"]:
        error_data["message"] = error_data["message"].format(user_id=f"user_{random.randint(1000, 9999)}")
    
    if "{rate}" in error_data["message"]:
        error_data["message"] = error_data["message"].format(rate=random.randint(100, 500))
    
    # Add random context
    error_data.update({
        "timestamp": datetime.now().isoformat(),
        "request_id": f"req_{random.randint(10000, 99999)}",
        "trace_id": f"trace_{random.randint(100000, 999999)}",
        "environment": random.choice(["production", "staging", "development"]),
        "release": f"v{random.randint(1, 5)}.{random.randint(0, 9)}.{random.randint(0, 9)}",
        "context": {
            "url": random.choice(["/api/users", "/api/payments", "/api/orders", "/api/products"]),
            "method": random.choice(["GET", "POST", "PUT", "DELETE"]),
            "ip": f"192.168.1.{random.randint(1, 255)}"
        },
        "tags": {
            "service": random.choice(["user-service", "payment-service", "order-service"]),
            "version": f"{random.randint(1, 3)}.{random.randint(0, 9)}"
        }
    })
    
    # Send to error tracking system
    try:
        async with session.post(f"{BASE_URL}/errors/collect", json=error_data) as response:
            if response.status == 200:
                result = await response.json()
                print(f"✅ Created error: {result.get('error_id')} -> Group {result.get('group_id')}")
                return True
            else:
                print(f"❌ Failed to create error: {response.status}")
                return False
    except Exception as e:
        print(f"❌ Exception creating error: {e}")
        return False

async def run_demo():
    """Run the error tracking demo"""
    print("🎭 Error Tracking System Demo")
    print("=" * 50)
    print(f"🎯 Target API: {BASE_URL}")
    print()
    
    # Check if API is available
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(f"http://localhost:8000/health") as response:
                if response.status != 200:
                    print("❌ Backend API is not running!")
                    print("   Run: python backend/main.py")
                    return
        except:
            print("❌ Cannot connect to backend API!")
            print("   Make sure the backend is running on port 8000")
            return
    
    print("✅ Backend API is running")
    print()
    
    # Generate errors
    async with aiohttp.ClientSession() as session:
        print("📊 Generating demo errors...")
        
        # Create multiple instances of each error type
        success_count = 0
        total_count = 0
        
        for round_num in range(3):  # 3 rounds
            print(f"\n🔄 Round {round_num + 1}/3")
            
            for template in ERROR_TEMPLATES:
                # Create 2-5 instances of each error type
                instances = random.randint(2, 5)
                
                for i in range(instances):
                    success = await generate_error(session, template)
                    if success:
                        success_count += 1
                    total_count += 1
                    
                    # Small delay between errors
                    await asyncio.sleep(0.1)
        
        print(f"\n📈 Demo Results:")
        print(f"   Generated: {success_count}/{total_count} errors")
        print(f"   Success rate: {(success_count/total_count)*100:.1f}%")
    
    # Show how to access the results
    print(f"\n🌐 View Results:")
    print(f"   Frontend Dashboard: http://localhost:3000")
    print(f"   API Documentation: http://localhost:8000/docs")
    print(f"   Error Groups API: {BASE_URL}/errors/groups")
    print()
    print("🎯 Check the dashboard to see how similar errors are grouped together!")

if __name__ == "__main__":
    asyncio.run(run_demo())
EOF

# Run build and test (skip for now to speed up - can run manually)
print_header "🔧 Building and Testing System..."

# Skip build and test during setup - user can run manually
print_status "Build and test scripts created. Run './build.sh' and './test.sh' manually when ready."

# Skip demo during setup - user can run manually
print_header "🎭 Demo Script Created"
print_status "Demo script created at demo.py. Run it manually after starting services."

print_header "✅ Implementation Complete!"
print_status "Day 132: Error Tracking Features implemented successfully"
print_status "Key features: Error collection, fingerprinting, grouping, real-time dashboard"
print_status "Integration with distributed tracing from Day 131"
print_status "Ready for deployment tracking integration (Day 133)"

echo ""
echo "📂 Project Structure:"
find . -type f -name "*.py" -o -name "*.js" -o -name "*.json" -o -name "*.yml" | grep -v __pycache__ | grep -v node_modules | sort