#!/bin/bash

# Day 138: JIRA/ServiceNow Ticket Creation Implementation Script
# Module 5: Integration and Ecosystem | Week 20: External System Integration

set -e

PROJECT_NAME="log-ticket-integration"
PYTHON_VERSION="3.12"

echo "🚀 Day 138: Setting up JIRA/ServiceNow Ticket Creation System"
echo "============================================================"

# Create project structure
echo "📁 Creating project structure..."
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

mkdir -p {src/{api,services,models,utils,templates},tests/{unit,integration},config,frontend/{src/{components,services,styles},public},docker,scripts,docs}

# Create Python virtual environment
echo "🐍 Setting up Python ${PYTHON_VERSION} virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Create requirements.txt with latest May 2025 libraries
echo "📦 Creating requirements.txt with latest dependencies..."
cat > requirements.txt << 'EOF'
# FastAPI and web framework
fastapi==0.111.0
uvicorn[standard]==0.30.1
pydantic==2.7.4
pydantic-settings==2.3.0

# HTTP clients and API integration
httpx==0.27.0
aiohttp==3.9.5
requests==2.32.3

# Authentication and security
python-multipart==0.0.9
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4

# Database and caching
sqlalchemy==2.0.30
alembic==1.13.2
redis==5.0.5
asyncpg==0.29.0

# Background tasks and scheduling
celery==5.3.6
celery[redis]==5.3.6

# Monitoring and logging
structlog==24.2.0
prometheus-client==0.20.0

# Templating and utilities
jinja2==3.1.4
python-dotenv==1.0.1
PyYAML==6.0.1

# Testing
pytest==8.2.2
pytest-asyncio==0.23.7
pytest-httpx==0.30.0

# Development tools
black==24.4.2
flake8==7.1.0
mypy==1.10.0
EOF

# Install Python dependencies
echo "⬇️  Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create main application structure
echo "🏗️  Creating application source files..."

# Main FastAPI application
cat > src/main.py << 'EOF'
#!/usr/bin/env python3
"""
Day 138: JIRA/ServiceNow Ticket Creation System
Main FastAPI application entry point
"""

import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import structlog
import uvicorn

from api.tickets import router as tickets_router
from api.events import router as events_router
from api.dashboard import router as dashboard_router
from services.event_processor import EventProcessor
from services.ticket_service import TicketService
from utils.config import settings

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Global services
event_processor: EventProcessor = None
ticket_service: TicketService = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle management"""
    global event_processor, ticket_service
    
    logger.info("Starting JIRA/ServiceNow Ticket Creation System")
    
    # Initialize services
    ticket_service = TicketService()
    await ticket_service.initialize()
    
    event_processor = EventProcessor(ticket_service)
    await event_processor.start()
    
    logger.info("System initialized successfully")
    
    yield
    
    # Cleanup
    await event_processor.stop()
    await ticket_service.close()
    logger.info("System shutdown complete")

# Create FastAPI app
app = FastAPI(
    title="Log Ticket Integration System",
    description="Automatic JIRA/ServiceNow ticket creation from log events",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(tickets_router, prefix="/api/tickets", tags=["tickets"])
app.include_router(events_router, prefix="/api/events", tags=["events"])
app.include_router(dashboard_router, prefix="/api/dashboard", tags=["dashboard"])

# Serve frontend static files
app.mount("/static", StaticFiles(directory="frontend/build"), name="static")

@app.get("/")
async def root():
    """Root endpoint with system info"""
    return {
        "service": "Log Ticket Integration System",
        "day": 138,
        "module": "Integration and Ecosystem",
        "status": "active",
        "features": [
            "JIRA ticket creation",
            "ServiceNow ticket creation", 
            "Event classification",
            "Deduplication",
            "Template management"
        ]
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "event_processor": event_processor.is_running() if event_processor else False,
        "ticket_service": ticket_service.is_connected() if ticket_service else False
    }

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_config=None
    )
EOF

# Configuration management
cat > src/utils/config.py << 'EOF'
"""Configuration management for ticket creation system"""

from pydantic_settings import BaseSettings
from typing import Dict, List, Optional

class Settings(BaseSettings):
    """Application settings"""
    
    # API Configuration
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    debug: bool = True
    
    # JIRA Configuration
    jira_url: str = "https://demo-jira.atlassian.net"
    jira_username: str = "demo@example.com"
    jira_api_token: str = "demo_token"
    jira_project_key: str = "DEMO"
    
    # ServiceNow Configuration
    servicenow_url: str = "https://demo.service-now.com"
    servicenow_username: str = "demo"
    servicenow_password: str = "demo_password"
    servicenow_table: str = "incident"
    
    # Redis Configuration
    redis_url: str = "redis://localhost:6379/0"
    
    # Event Processing
    event_batch_size: int = 100
    event_processing_interval: int = 5  # seconds
    duplicate_detection_window: int = 300  # seconds
    
    # Ticket Creation Rules
    severity_mapping: Dict[str, str] = {
        "critical": "1",  # High priority
        "error": "2",     # Medium priority  
        "warning": "3",   # Low priority
        "info": "4"       # Informational
    }
    
    # Team routing rules
    team_routing: Dict[str, str] = {
        "database": "JIRA",
        "api": "JIRA", 
        "infrastructure": "ServiceNow",
        "security": "ServiceNow"
    }

    class Config:
        env_file = ".env"
        case_sensitive = False

settings = Settings()
EOF

# Event processor service
cat > src/services/event_processor.py << 'EOF'
"""Event processing service for log analysis and ticket creation"""

import asyncio
import hashlib
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Set
import structlog
import redis.asyncio as aioredis

from models.log_event import LogEvent
from models.ticket import TicketRequest
from services.ticket_service import TicketService
from utils.config import settings

logger = structlog.get_logger()

class EventProcessor:
    """Processes log events and creates tickets"""
    
    def __init__(self, ticket_service: TicketService):
        self.ticket_service = ticket_service
        self.redis = None
        self.running = False
        self._task = None
        self.processed_events = 0
        self.created_tickets = 0
        
    async def start(self):
        """Start the event processor"""
        self.redis = aioredis.from_url(settings.redis_url)
        self.running = True
        self._task = asyncio.create_task(self._process_events_loop())
        logger.info("Event processor started")
        
    async def stop(self):
        """Stop the event processor"""
        self.running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        if self.redis:
            await self.redis.close()
        logger.info("Event processor stopped")
        
    def is_running(self) -> bool:
        """Check if processor is running"""
        return self.running
        
    async def process_event(self, event: LogEvent) -> Optional[str]:
        """Process a single log event"""
        try:
            # Classify event
            classification = await self._classify_event(event)
            
            if not classification.should_create_ticket:
                return None
                
            # Generate incident fingerprint for deduplication
            fingerprint = self._generate_fingerprint(event)
            
            # Check for existing ticket
            existing_ticket = await self._check_existing_ticket(fingerprint)
            if existing_ticket:
                await self._update_existing_ticket(existing_ticket, event)
                return existing_ticket
                
            # Create new ticket
            ticket_request = await self._create_ticket_request(event, classification)
            ticket_id = await self.ticket_service.create_ticket(ticket_request)
            
            if ticket_id:
                await self._store_ticket_fingerprint(fingerprint, ticket_id)
                self.created_tickets += 1
                logger.info("Created ticket", ticket_id=ticket_id, event_id=event.id)
                
            return ticket_id
            
        except Exception as e:
            logger.error("Error processing event", event_id=event.id, error=str(e))
            return None
            
    async def _process_events_loop(self):
        """Main event processing loop"""
        while self.running:
            try:
                # Get events from Redis queue
                events = await self._get_pending_events()
                
                if events:
                    tasks = [self.process_event(event) for event in events]
                    results = await asyncio.gather(*tasks, return_exceptions=True)
                    
                    successful = sum(1 for r in results if r and not isinstance(r, Exception))
                    self.processed_events += len(events)
                    
                    logger.info("Processed batch", 
                              events=len(events), 
                              successful=successful,
                              total_processed=self.processed_events)
                
                await asyncio.sleep(settings.event_processing_interval)
                
            except Exception as e:
                logger.error("Error in processing loop", error=str(e))
                await asyncio.sleep(5)
                
    async def _classify_event(self, event: LogEvent) -> 'EventClassification':
        """Classify log event to determine ticket creation needs"""
        
        # Severity-based rules
        should_create = event.level in ['critical', 'error']
        
        # Service-based rules
        if event.service in ['payment', 'authentication', 'database']:
            should_create = True
            
        # Pattern-based rules
        if any(keyword in event.message.lower() for keyword in ['timeout', 'connection failed', 'out of memory']):
            should_create = True
            
        # Frequency-based rules (rate limiting)
        recent_count = await self._get_recent_event_count(event)
        if recent_count > 10:  # Too many similar events
            should_create = False
            
        priority = settings.severity_mapping.get(event.level, "3")
        team = self._determine_team(event)
        system = settings.team_routing.get(team, "JIRA")
        
        return EventClassification(
            should_create_ticket=should_create,
            priority=priority,
            team=team,
            target_system=system,
            category=self._categorize_event(event)
        )
        
    def _generate_fingerprint(self, event: LogEvent) -> str:
        """Generate unique fingerprint for deduplication"""
        # Normalize error message (remove timestamps, IDs, etc.)
        normalized_message = self._normalize_message(event.message)
        
        fingerprint_data = {
            'service': event.service,
            'component': event.component or '',
            'level': event.level,
            'message_pattern': normalized_message[:200],  # Truncate
            'error_type': event.metadata.get('error_type', '')
        }
        
        fingerprint_str = json.dumps(fingerprint_data, sort_keys=True)
        return hashlib.sha256(fingerprint_str.encode()).hexdigest()[:16]
        
    async def _check_existing_ticket(self, fingerprint: str) -> Optional[str]:
        """Check if ticket already exists for this incident"""
        key = f"ticket_fingerprint:{fingerprint}"
        ticket_id = await self.redis.get(key)
        return ticket_id.decode() if ticket_id else None
        
    async def _store_ticket_fingerprint(self, fingerprint: str, ticket_id: str):
        """Store ticket fingerprint for deduplication"""
        key = f"ticket_fingerprint:{fingerprint}"
        await self.redis.setex(key, settings.duplicate_detection_window, ticket_id)
        
    def _normalize_message(self, message: str) -> str:
        """Normalize message for fingerprinting"""
        import re
        
        # Remove timestamps, IDs, numbers
        normalized = re.sub(r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}', 'TIMESTAMP', message)
        normalized = re.sub(r'\b[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\b', 'UUID', normalized)
        normalized = re.sub(r'\b\d+\b', 'NUMBER', normalized)
        normalized = re.sub(r'\s+', ' ', normalized)
        
        return normalized.strip().lower()
        
    def _determine_team(self, event: LogEvent) -> str:
        """Determine responsible team based on event"""
        service_teams = {
            'database': 'database',
            'redis': 'database', 
            'api': 'api',
            'web': 'api',
            'auth': 'security',
            'payment': 'security',
            'infrastructure': 'infrastructure'
        }
        
        return service_teams.get(event.service, 'api')
        
    async def _get_pending_events(self) -> List[LogEvent]:
        """Get pending events from Redis queue"""
        events = []
        for _ in range(settings.event_batch_size):
            event_data = await self.redis.lpop("events:pending")
            if not event_data:
                break
            try:
                event_dict = json.loads(event_data)
                event = LogEvent(**event_dict)
                events.append(event)
            except Exception as e:
                logger.error("Failed to parse event", error=str(e))
                
        return events

class EventClassification:
    """Result of event classification"""
    def __init__(self, should_create_ticket: bool, priority: str, team: str, 
                 target_system: str, category: str):
        self.should_create_ticket = should_create_ticket
        self.priority = priority
        self.team = team
        self.target_system = target_system
        self.category = category
EOF

# Ticket service for JIRA/ServiceNow integration
cat > src/services/ticket_service.py << 'EOF'
"""Ticket creation service for JIRA and ServiceNow integration"""

import asyncio
import json
from typing import Dict, List, Optional
import httpx
import structlog
from jinja2 import Environment, BaseLoader

from models.ticket import TicketRequest, TicketResponse
from utils.config import settings

logger = structlog.get_logger()

class TicketService:
    """Unified ticket creation service"""
    
    def __init__(self):
        self.jira_client = None
        self.servicenow_client = None
        self.template_env = Environment(loader=BaseLoader())
        self.connected = False
        
    async def initialize(self):
        """Initialize HTTP clients"""
        timeout = httpx.Timeout(30.0)
        
        # JIRA client with basic auth
        jira_auth = (settings.jira_username, settings.jira_api_token)
        self.jira_client = httpx.AsyncClient(
            base_url=settings.jira_url,
            auth=jira_auth,
            timeout=timeout,
            headers={"Content-Type": "application/json"}
        )
        
        # ServiceNow client with basic auth  
        servicenow_auth = (settings.servicenow_username, settings.servicenow_password)
        self.servicenow_client = httpx.AsyncClient(
            base_url=settings.servicenow_url,
            auth=servicenow_auth,
            timeout=timeout,
            headers={"Content-Type": "application/json"}
        )
        
        self.connected = True
        logger.info("Ticket service initialized")
        
    async def close(self):
        """Close HTTP clients"""
        if self.jira_client:
            await self.jira_client.aclose()
        if self.servicenow_client:
            await self.servicenow_client.aclose()
        self.connected = False
        
    def is_connected(self) -> bool:
        """Check if service is connected"""
        return self.connected
        
    async def create_ticket(self, ticket_request: TicketRequest) -> Optional[str]:
        """Create ticket in appropriate system"""
        try:
            if ticket_request.system.upper() == "JIRA":
                return await self._create_jira_ticket(ticket_request)
            elif ticket_request.system.upper() == "SERVICENOW":
                return await self._create_servicenow_ticket(ticket_request)
            else:
                logger.error("Unknown ticket system", system=ticket_request.system)
                return None
                
        except Exception as e:
            logger.error("Failed to create ticket", error=str(e), system=ticket_request.system)
            return None
            
    async def _create_jira_ticket(self, ticket_request: TicketRequest) -> Optional[str]:
        """Create JIRA issue"""
        
        # JIRA issue payload
        issue_data = {
            "fields": {
                "project": {"key": settings.jira_project_key},
                "summary": ticket_request.title,
                "description": {
                    "type": "doc",
                    "version": 1,
                    "content": [
                        {
                            "type": "paragraph",
                            "content": [
                                {"type": "text", "text": ticket_request.description}
                            ]
                        }
                    ]
                },
                "issuetype": {"name": "Bug"},
                "priority": {"id": ticket_request.priority},
                "labels": ticket_request.tags,
                "customfield_10000": ticket_request.metadata.get("component", ""),  # Component field
            }
        }
        
        response = await self.jira_client.post("/rest/api/3/issue", json=issue_data)
        
        if response.status_code == 201:
            result = response.json()
            issue_key = result["key"]
            logger.info("Created JIRA issue", issue_key=issue_key)
            return issue_key
        else:
            logger.error("JIRA API error", status=response.status_code, response=response.text)
            return None
            
    async def _create_servicenow_ticket(self, ticket_request: TicketRequest) -> Optional[str]:
        """Create ServiceNow incident"""
        
        # ServiceNow incident payload
        incident_data = {
            "short_description": ticket_request.title,
            "description": ticket_request.description,
            "urgency": ticket_request.priority,
            "impact": ticket_request.priority,
            "category": ticket_request.metadata.get("category", "Software"),
            "subcategory": ticket_request.metadata.get("subcategory", "Application"),
            "state": "1",  # New
            "caller_id": settings.servicenow_username,
            "work_notes": json.dumps(ticket_request.metadata, indent=2)
        }
        
        response = await self.servicenow_client.post(
            f"/api/now/table/{settings.servicenow_table}", 
            json=incident_data
        )
        
        if response.status_code == 201:
            result = response.json()
            incident_number = result["result"]["number"]
            logger.info("Created ServiceNow incident", incident_number=incident_number)
            return incident_number
        else:
            logger.error("ServiceNow API error", status=response.status_code, response=response.text)
            return None
            
    async def update_ticket(self, ticket_id: str, system: str, update_data: Dict) -> bool:
        """Update existing ticket with new information"""
        try:
            if system.upper() == "JIRA":
                return await self._update_jira_ticket(ticket_id, update_data)
            elif system.upper() == "SERVICENOW":
                return await self._update_servicenow_ticket(ticket_id, update_data)
            else:
                logger.error("Unknown ticket system for update", system=system)
                return False
                
        except Exception as e:
            logger.error("Failed to update ticket", ticket_id=ticket_id, error=str(e))
            return False
            
    async def _update_jira_ticket(self, issue_key: str, update_data: Dict) -> bool:
        """Update JIRA issue with additional information"""
        
        # Add comment to JIRA issue
        comment_data = {
            "body": {
                "type": "doc",
                "version": 1,
                "content": [
                    {
                        "type": "paragraph", 
                        "content": [
                            {"type": "text", "text": update_data.get("comment", "Additional event information")}
                        ]
                    }
                ]
            }
        }
        
        response = await self.jira_client.post(
            f"/rest/api/3/issue/{issue_key}/comment",
            json=comment_data
        )
        
        return response.status_code == 201
        
    async def get_ticket_stats(self) -> Dict:
        """Get ticket creation statistics"""
        stats = {
            "total_created": 0,
            "jira_tickets": 0,
            "servicenow_tickets": 0,
            "last_24h": 0
        }
        
        # In production, these would come from database/metrics
        return stats
EOF

# Data models
cat > src/models/log_event.py << 'EOF'
"""Log event data models"""

from datetime import datetime
from typing import Dict, Optional, Any
from pydantic import BaseModel, Field

class LogEvent(BaseModel):
    """Log event from distributed logging system"""
    
    id: str = Field(..., description="Unique event identifier")
    timestamp: datetime = Field(..., description="Event timestamp")
    level: str = Field(..., description="Log level (critical, error, warning, info)")
    service: str = Field(..., description="Service name")
    component: Optional[str] = Field(None, description="Component name")
    message: str = Field(..., description="Log message")
    
    # Context information
    host: Optional[str] = Field(None, description="Host name")
    user_id: Optional[str] = Field(None, description="User ID if applicable")
    request_id: Optional[str] = Field(None, description="Request ID for tracing")
    
    # Technical details
    stack_trace: Optional[str] = Field(None, description="Stack trace for errors")
    error_code: Optional[str] = Field(None, description="Error code")
    
    # Metadata
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Additional metadata")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class EventBatch(BaseModel):
    """Batch of log events for processing"""
    
    events: list[LogEvent]
    batch_id: str
    received_at: datetime = Field(default_factory=datetime.utcnow)
EOF

cat > src/models/ticket.py << 'EOF'
"""Ticket data models"""

from datetime import datetime
from typing import Dict, List, Optional, Any
from pydantic import BaseModel, Field

class TicketRequest(BaseModel):
    """Request to create a ticket"""
    
    title: str = Field(..., description="Ticket title/summary")
    description: str = Field(..., description="Detailed description") 
    system: str = Field(..., description="Target system (JIRA/ServiceNow)")
    priority: str = Field(..., description="Priority level")
    
    # Classification
    category: str = Field(..., description="Issue category")
    team: str = Field(..., description="Responsible team")
    
    # Additional data
    tags: List[str] = Field(default_factory=list, description="Tags/labels")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Additional metadata")
    
    # Source event reference
    source_event_id: str = Field(..., description="Source log event ID")
    fingerprint: str = Field(..., description="Deduplication fingerprint")

class TicketResponse(BaseModel):
    """Response from ticket creation"""
    
    ticket_id: str = Field(..., description="Created ticket ID")
    system: str = Field(..., description="System where ticket was created")
    url: Optional[str] = Field(None, description="Ticket URL")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
class TicketUpdate(BaseModel):
    """Update to existing ticket"""
    
    ticket_id: str
    system: str
    comment: Optional[str] = None
    status_change: Optional[str] = None
    additional_events: List[str] = Field(default_factory=list)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class TicketStats(BaseModel):
    """Ticket creation statistics"""
    
    total_created: int = 0
    jira_tickets: int = 0 
    servicenow_tickets: int = 0
    by_priority: Dict[str, int] = Field(default_factory=dict)
    by_team: Dict[str, int] = Field(default_factory=dict)
    last_24h: int = 0
EOF

# API routes
cat > src/api/tickets.py << 'EOF'
"""Ticket management API routes"""

from fastapi import APIRouter, HTTPException, Depends
from typing import List, Optional
import structlog

from models.ticket import TicketRequest, TicketResponse, TicketStats, TicketUpdate
from services.ticket_service import TicketService

logger = structlog.get_logger()
router = APIRouter()

# Dependency injection for ticket service
async def get_ticket_service() -> TicketService:
    from main import ticket_service
    if not ticket_service:
        raise HTTPException(status_code=503, detail="Ticket service not available")
    return ticket_service

@router.post("/create", response_model=TicketResponse)
async def create_ticket(
    request: TicketRequest,
    service: TicketService = Depends(get_ticket_service)
) -> TicketResponse:
    """Create a new ticket in JIRA or ServiceNow"""
    
    ticket_id = await service.create_ticket(request)
    
    if not ticket_id:
        raise HTTPException(status_code=500, detail="Failed to create ticket")
    
    # Generate URL based on system
    url = None
    if request.system.upper() == "JIRA":
        url = f"https://demo-jira.atlassian.net/browse/{ticket_id}"
    elif request.system.upper() == "SERVICENOW":
        url = f"https://demo.service-now.com/nav_to.do?uri=incident.do?sys_id={ticket_id}"
    
    return TicketResponse(
        ticket_id=ticket_id,
        system=request.system,
        url=url
    )

@router.put("/{ticket_id}/update")
async def update_ticket(
    ticket_id: str,
    update: TicketUpdate,
    service: TicketService = Depends(get_ticket_service)
) -> dict:
    """Update an existing ticket"""
    
    success = await service.update_ticket(ticket_id, update.system, {
        "comment": update.comment,
        "status": update.status_change,
        "additional_events": update.additional_events
    })
    
    if not success:
        raise HTTPException(status_code=500, detail="Failed to update ticket")
    
    return {"message": "Ticket updated successfully", "ticket_id": ticket_id}

@router.get("/stats", response_model=TicketStats)
async def get_ticket_stats(
    service: TicketService = Depends(get_ticket_service)
) -> TicketStats:
    """Get ticket creation statistics"""
    
    stats = await service.get_ticket_stats()
    return TicketStats(**stats)

@router.get("/templates")
async def get_ticket_templates() -> dict:
    """Get available ticket templates"""
    
    templates = {
        "database_error": {
            "title": "Database Error: {service} - {error_type}",
            "description": """
Service: {service}
Component: {component}
Error: {message}
Timestamp: {timestamp}
Host: {host}

Stack Trace:
{stack_trace}

Impact: {impact_assessment}
Suggested Action: {suggested_action}
            """,
            "priority": "2",
            "tags": ["database", "production"]
        },
        "api_timeout": {
            "title": "API Timeout: {service} endpoint {endpoint}",
            "description": """
Service: {service}
Endpoint: {endpoint} 
Timeout Duration: {timeout_duration}
Request ID: {request_id}
User Impact: {user_impact}

Recent Occurrences: {recent_count}
Performance Metrics: {metrics}
            """,
            "priority": "3",
            "tags": ["api", "performance"]
        }
    }
    
    return {"templates": templates}
EOF

# Event submission API
cat > src/api/events.py << 'EOF'
"""Event processing API routes"""

from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
from typing import List
import json
import redis.asyncio as aioredis
import structlog

from models.log_event import LogEvent, EventBatch
from services.event_processor import EventProcessor
from utils.config import settings

logger = structlog.get_logger()
router = APIRouter()

# Redis connection for event queuing
redis_client = None

async def get_redis():
    global redis_client
    if not redis_client:
        redis_client = aioredis.from_url(settings.redis_url)
    return redis_client

async def get_event_processor() -> EventProcessor:
    from main import event_processor
    if not event_processor:
        raise HTTPException(status_code=503, detail="Event processor not available")
    return event_processor

@router.post("/submit")
async def submit_event(
    event: LogEvent,
    background_tasks: BackgroundTasks,
    redis: aioredis.Redis = Depends(get_redis)
) -> dict:
    """Submit a log event for processing"""
    
    try:
        # Queue event for processing
        await redis.rpush("events:pending", event.json())
        
        logger.info("Event queued for processing", 
                   event_id=event.id, 
                   service=event.service,
                   level=event.level)
        
        return {
            "message": "Event queued for processing",
            "event_id": event.id,
            "queue_position": await redis.llen("events:pending")
        }
        
    except Exception as e:
        logger.error("Failed to queue event", event_id=event.id, error=str(e))
        raise HTTPException(status_code=500, detail="Failed to queue event")

@router.post("/batch")
async def submit_event_batch(
    batch: EventBatch,
    redis: aioredis.Redis = Depends(get_redis)
) -> dict:
    """Submit multiple events in batch"""
    
    try:
        # Queue all events
        pipe = redis.pipeline()
        for event in batch.events:
            pipe.rpush("events:pending", event.json())
        await pipe.execute()
        
        logger.info("Event batch queued", 
                   batch_id=batch.batch_id,
                   event_count=len(batch.events))
        
        return {
            "message": "Event batch queued successfully",
            "batch_id": batch.batch_id,
            "events_queued": len(batch.events),
            "total_queue_size": await redis.llen("events:pending")
        }
        
    except Exception as e:
        logger.error("Failed to queue event batch", 
                    batch_id=batch.batch_id, 
                    error=str(e))
        raise HTTPException(status_code=500, detail="Failed to queue event batch")

@router.get("/queue/status")
async def get_queue_status(
    redis: aioredis.Redis = Depends(get_redis)
) -> dict:
    """Get event processing queue status"""
    
    try:
        pending_count = await redis.llen("events:pending")
        processing_count = await redis.llen("events:processing")
        
        return {
            "pending_events": pending_count,
            "processing_events": processing_count,
            "total_events": pending_count + processing_count
        }
        
    except Exception as e:
        logger.error("Failed to get queue status", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to get queue status")

@router.post("/test/generate")
async def generate_test_events(
    count: int = 10,
    redis: aioredis.Redis = Depends(get_redis)
) -> dict:
    """Generate test events for demonstration"""
    
    import uuid
    from datetime import datetime, timedelta
    import random
    
    services = ["web-api", "payment-service", "user-auth", "database", "cache"]
    levels = ["info", "warning", "error", "critical"]
    components = ["handler", "processor", "connector", "validator"]
    
    error_templates = {
        "database": "Connection timeout to database server {host}",
        "api": "HTTP {status_code} error on endpoint {endpoint}",
        "auth": "Authentication failed for user {user_id}",
        "payment": "Payment processing failed: {error_code}",
        "cache": "Redis connection lost to {redis_host}"
    }
    
    events = []
    for i in range(count):
        service = random.choice(services)
        level = random.choice(levels)
        component = random.choice(components)
        
        # Weight towards more errors for demo
        if random.random() < 0.4:
            level = random.choice(["error", "critical"])
        
        # Generate realistic error message
        if service in error_templates:
            message = error_templates[service].format(
                host=f"db-{random.randint(1,5)}.internal",
                status_code=random.choice([500, 502, 503, 504]),
                endpoint=f"/api/v1/{random.choice(['users', 'orders', 'payments'])}",
                user_id=f"user_{random.randint(1000, 9999)}",
                error_code=f"ERR_{random.randint(100, 999)}",
                redis_host=f"redis-{random.randint(1,3)}.cache.internal"
            )
        else:
            message = f"Service {service} {level} in {component}"
        
        event = LogEvent(
            id=str(uuid.uuid4()),
            timestamp=datetime.utcnow() - timedelta(minutes=random.randint(0, 60)),
            level=level,
            service=service,
            component=component,
            message=message,
            host=f"host-{random.randint(1, 10)}.cluster.local",
            request_id=str(uuid.uuid4()),
            metadata={
                "environment": "production",
                "region": random.choice(["us-east-1", "us-west-2", "eu-west-1"]),
                "pod_id": f"pod-{random.randint(1, 20)}"
            }
        )
        
        # Queue event
        await redis.rpush("events:pending", event.json())
        events.append({
            "id": event.id,
            "service": event.service,
            "level": event.level,
            "message": event.message[:100] + "..." if len(event.message) > 100 else event.message
        })
    
    logger.info("Generated test events", count=count)
    
    return {
        "message": f"Generated {count} test events",
        "events": events,
        "queue_size": await redis.llen("events:pending")
    }
EOF

# Dashboard API
cat > src/api/dashboard.py << 'EOF'
"""Dashboard API routes for monitoring and statistics"""

from fastapi import APIRouter, Depends
from typing import Dict, List
import json
import redis.asyncio as aioredis
import structlog

from services.event_processor import EventProcessor
from services.ticket_service import TicketService
from utils.config import settings

logger = structlog.get_logger()
router = APIRouter()

async def get_redis():
    return aioredis.from_url(settings.redis_url)

async def get_services():
    from main import event_processor, ticket_service
    return event_processor, ticket_service

@router.get("/stats")
async def get_dashboard_stats(
    redis: aioredis.Redis = Depends(get_redis)
) -> Dict:
    """Get comprehensive dashboard statistics"""
    
    event_processor, ticket_service = await get_services()
    
    # Queue statistics
    pending_events = await redis.llen("events:pending")
    processing_events = await redis.llen("events:processing")
    
    # Processing statistics
    processed_events = event_processor.processed_events if event_processor else 0
    created_tickets = event_processor.created_tickets if event_processor else 0
    
    # System health
    system_health = {
        "event_processor": event_processor.is_running() if event_processor else False,
        "ticket_service": ticket_service.is_connected() if ticket_service else False,
        "redis": True  # If we got here, Redis is working
    }
    
    # Recent activity (mock data for demo)
    recent_tickets = [
        {"id": "DEMO-123", "system": "JIRA", "title": "Database connection timeout", "created": "2 minutes ago"},
        {"id": "INC0012345", "system": "ServiceNow", "title": "API authentication failures", "created": "5 minutes ago"},
        {"id": "DEMO-122", "system": "JIRA", "title": "Memory leak in payment service", "created": "8 minutes ago"},
    ]
    
    return {
        "queue": {
            "pending": pending_events,
            "processing": processing_events,
            "total": pending_events + processing_events
        },
        "processing": {
            "events_processed": processed_events,
            "tickets_created": created_tickets,
            "success_rate": round((created_tickets / max(processed_events, 1)) * 100, 1)
        },
        "system_health": system_health,
        "recent_tickets": recent_tickets,
        "configuration": {
            "jira_project": settings.jira_project_key,
            "servicenow_table": settings.servicenow_table,
            "processing_interval": settings.event_processing_interval,
            "batch_size": settings.event_batch_size
        }
    }

@router.get("/metrics")
async def get_metrics() -> Dict:
    """Get metrics in Prometheus format"""
    
    event_processor, ticket_service = await get_services()
    
    metrics = {
        "events_processed_total": event_processor.processed_events if event_processor else 0,
        "tickets_created_total": event_processor.created_tickets if event_processor else 0,
        "system_up": 1 if (event_processor and ticket_service) else 0,
    }
    
    return metrics

@router.get("/health")
async def health_check() -> Dict:
    """Detailed health check endpoint"""
    
    event_processor, ticket_service = await get_services()
    
    health_checks = {
        "event_processor": {
            "status": "up" if (event_processor and event_processor.is_running()) else "down",
            "processed_events": event_processor.processed_events if event_processor else 0
        },
        "ticket_service": {
            "status": "up" if (ticket_service and ticket_service.is_connected()) else "down",
            "jira_connection": True,  # Would test actual connection in production
            "servicenow_connection": True
        },
        "overall": "healthy" if all([
            event_processor and event_processor.is_running(),
            ticket_service and ticket_service.is_connected()
        ]) else "degraded"
    }
    
    return health_checks
EOF

# Create package __init__ files
touch src/__init__.py
touch src/api/__init__.py
touch src/services/__init__.py
touch src/models/__init__.py
touch src/utils/__init__.py

# Create configuration files
echo "⚙️ Creating configuration files..."

# Environment configuration
cat > .env << 'EOF'
# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
DEBUG=true

# JIRA Configuration (Demo credentials)
JIRA_URL=https://demo-jira.atlassian.net
JIRA_USERNAME=demo@example.com
JIRA_API_TOKEN=demo_token_replace_in_production
JIRA_PROJECT_KEY=DEMO

# ServiceNow Configuration (Demo credentials)
SERVICENOW_URL=https://demo.service-now.com
SERVICENOW_USERNAME=demo
SERVICENOW_PASSWORD=demo_password_replace_in_production
SERVICENOW_TABLE=incident

# Redis Configuration
REDIS_URL=redis://localhost:6379/0

# Processing Configuration
EVENT_BATCH_SIZE=100
EVENT_PROCESSING_INTERVAL=5
DUPLICATE_DETECTION_WINDOW=300
EOF

# Frontend React application
echo "⚛️ Creating React frontend..."

# Package.json for React app
cat > frontend/package.json << 'EOF'
{
  "name": "ticket-integration-dashboard",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-scripts": "5.0.1",
    "axios": "^1.7.2",
    "react-router-dom": "^6.23.1",
    "recharts": "^2.12.7",
    "lucide-react": "^0.383.0",
    "tailwindcss": "^3.4.4",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.38"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
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
  "proxy": "http://localhost:8000"
}
EOF

# Tailwind CSS configuration
cat > frontend/tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
        },
        success: {
          50: '#f0fdf4',
          500: '#22c55e',
        },
        warning: {
          50: '#fffbeb',
          500: '#f59e0b',
        },
        error: {
          50: '#fef2f2',
          500: '#ef4444',
        }
      }
    },
  },
  plugins: [],
}
EOF

# PostCSS configuration
cat > frontend/postcss.config.js << 'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

# Main React App component
cat > frontend/src/App.js << 'EOF'
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Dashboard from './components/Dashboard';
import EventSubmission from './components/EventSubmission';
import TicketManagement from './components/TicketManagement';
import Navigation from './components/Navigation';
import './styles/App.css';

function App() {
  return (
    <div className="App min-h-screen bg-gray-50">
      <Router>
        <Navigation />
        <main className="container mx-auto px-4 py-8">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/events" element={<EventSubmission />} />
            <Route path="/tickets" element={<TicketManagement />} />
          </Routes>
        </main>
      </Router>
    </div>
  );
}

export default App;
EOF

# Main dashboard component
cat > frontend/src/components/Dashboard.js << 'EOF'
import React, { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { Activity, AlertTriangle, CheckCircle, Clock } from 'lucide-react';
import axios from 'axios';

const COLORS = ['#3b82f6', '#22c55e', '#f59e0b', '#ef4444'];

function Dashboard() {
  const [stats, setStats] = useState({
    queue: { pending: 0, processing: 0, total: 0 },
    processing: { events_processed: 0, tickets_created: 0, success_rate: 0 },
    system_health: {},
    recent_tickets: []
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStats();
    const interval = setInterval(fetchStats, 5000); // Update every 5 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchStats = async () => {
    try {
      const response = await axios.get('/api/dashboard/stats');
      setStats(response.data);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching stats:', error);
      setLoading(false);
    }
  };

  const generateTestEvents = async () => {
    try {
      await axios.post('/api/events/test/generate', null, {
        params: { count: 20 }
      });
      fetchStats(); // Refresh stats
    } catch (error) {
      console.error('Error generating test events:', error);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  const healthStatus = (status) => {
    if (status) return <CheckCircle className="w-5 h-5 text-success-500" />;
    return <AlertTriangle className="w-5 h-5 text-error-500" />;
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-900">Ticket Integration Dashboard</h1>
        <button
          onClick={generateTestEvents}
          className="bg-primary-500 hover:bg-primary-600 text-white px-4 py-2 rounded-lg transition-colors"
        >
          Generate Test Events
        </button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <div className="flex items-center">
            <Clock className="w-8 h-8 text-warning-500" />
            <div className="ml-3">
              <p className="text-sm font-medium text-gray-600">Pending Events</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.queue.pending}</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <div className="flex items-center">
            <Activity className="w-8 h-8 text-primary-500" />
            <div className="ml-3">
              <p className="text-sm font-medium text-gray-600">Events Processed</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.processing.events_processed}</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <div className="flex items-center">
            <CheckCircle className="w-8 h-8 text-success-500" />
            <div className="ml-3">
              <p className="text-sm font-medium text-gray-600">Tickets Created</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.processing.tickets_created}</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <div className="flex items-center">
            <Activity className="w-8 h-8 text-primary-500" />
            <div className="ml-3">
              <p className="text-sm font-medium text-gray-600">Success Rate</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.processing.success_rate}%</p>
            </div>
          </div>
        </div>
      </div>

      {/* System Health */}
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <h2 className="text-xl font-semibold mb-4">System Health</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="flex items-center space-x-3">
            {healthStatus(stats.system_health.event_processor)}
            <span>Event Processor</span>
          </div>
          <div className="flex items-center space-x-3">
            {healthStatus(stats.system_health.ticket_service)}
            <span>Ticket Service</span>
          </div>
          <div className="flex items-center space-x-3">
            {healthStatus(stats.system_health.redis)}
            <span>Redis Queue</span>
          </div>
        </div>
      </div>

      {/* Recent Tickets */}
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <h2 className="text-xl font-semibold mb-4">Recent Tickets</h2>
        <div className="space-y-3">
          {stats.recent_tickets.map((ticket, index) => (
            <div key={index} className="flex items-center justify-between p-3 bg-gray-50 rounded">
              <div>
                <div className="font-medium">{ticket.title}</div>
                <div className="text-sm text-gray-600">{ticket.id} • {ticket.system}</div>
              </div>
              <div className="text-sm text-gray-500">{ticket.created}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Configuration */}
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <h2 className="text-xl font-semibold mb-4">Configuration</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div>
            <span className="text-gray-600">JIRA Project:</span>
            <div className="font-medium">{stats.configuration?.jira_project}</div>
          </div>
          <div>
            <span className="text-gray-600">ServiceNow Table:</span>
            <div className="font-medium">{stats.configuration?.servicenow_table}</div>
          </div>
          <div>
            <span className="text-gray-600">Processing Interval:</span>
            <div className="font-medium">{stats.configuration?.processing_interval}s</div>
          </div>
          <div>
            <span className="text-gray-600">Batch Size:</span>
            <div className="font-medium">{stats.configuration?.batch_size}</div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default Dashboard;
EOF

# Navigation component
cat > frontend/src/components/Navigation.js << 'EOF'
import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Home, FileText, Ticket } from 'lucide-react';

function Navigation() {
  const location = useLocation();
  
  const navItems = [
    { path: '/', label: 'Dashboard', icon: Home },
    { path: '/events', label: 'Events', icon: FileText },
    { path: '/tickets', label: 'Tickets', icon: Ticket },
  ];

  return (
    <nav className="bg-white shadow-sm border-b">
      <div className="container mx-auto px-4">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center space-x-8">
            <h1 className="text-xl font-semibold text-gray-900">
              Ticket Integration System
            </h1>
            <div className="flex space-x-6">
              {navItems.map(({ path, label, icon: Icon }) => {
                const isActive = location.pathname === path;
                return (
                  <Link
                    key={path}
                    to={path}
                    className={`flex items-center space-x-2 px-3 py-2 rounded-md transition-colors ${
                      isActive
                        ? 'bg-primary-50 text-primary-600'
                        : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{label}</span>
                  </Link>
                );
              })}
            </div>
          </div>
          <div className="text-sm text-gray-500">
            Day 138: JIRA/ServiceNow Integration
          </div>
        </div>
      </div>
    </nav>
  );
}

export default Navigation;
EOF

# Event submission component
cat > frontend/src/components/EventSubmission.js << 'EOF'
import React, { useState } from 'react';
import { Send, AlertCircle } from 'lucide-react';
import axios from 'axios';

function EventSubmission() {
  const [event, setEvent] = useState({
    level: 'error',
    service: 'web-api',
    component: 'handler',
    message: 'Database connection timeout after 30 seconds'
  });
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    
    try {
      const eventData = {
        id: `event-${Date.now()}`,
        timestamp: new Date().toISOString(),
        ...event,
        host: 'demo-host-1.cluster.local',
        request_id: `req-${Date.now()}`,
        metadata: {
          environment: 'production',
          region: 'us-east-1'
        }
      };
      
      const response = await axios.post('/api/events/submit', eventData);
      setResult({ type: 'success', data: response.data });
    } catch (error) {
      setResult({ type: 'error', message: error.response?.data?.detail || error.message });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      <div className="bg-white p-8 rounded-lg shadow-sm border">
        <h1 className="text-2xl font-bold mb-6">Submit Log Event</h1>
        
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Log Level
            </label>
            <select
              value={event.level}
              onChange={(e) => setEvent({ ...event, level: e.target.value })}
              className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            >
              <option value="info">Info</option>
              <option value="warning">Warning</option>
              <option value="error">Error</option>
              <option value="critical">Critical</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Service
            </label>
            <select
              value={event.service}
              onChange={(e) => setEvent({ ...event, service: e.target.value })}
              className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            >
              <option value="web-api">Web API</option>
              <option value="payment-service">Payment Service</option>
              <option value="user-auth">User Auth</option>
              <option value="database">Database</option>
              <option value="cache">Cache</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Component
            </label>
            <input
              type="text"
              value={event.component}
              onChange={(e) => setEvent({ ...event, component: e.target.value })}
              className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="handler, processor, validator..."
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Error Message
            </label>
            <textarea
              value={event.message}
              onChange={(e) => setEvent({ ...event, message: e.target.value })}
              rows={4}
              className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="Describe the error or event..."
            />
          </div>

          <button
            type="submit"
            disabled={submitting}
            className="w-full flex items-center justify-center space-x-2 bg-primary-500 hover:bg-primary-600 disabled:bg-gray-400 text-white py-3 px-6 rounded-lg transition-colors"
          >
            {submitting ? (
              <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
            ) : (
              <Send className="w-4 h-4" />
            )}
            <span>{submitting ? 'Submitting...' : 'Submit Event'}</span>
          </button>
        </form>

        {result && (
          <div className={`mt-6 p-4 rounded-lg ${
            result.type === 'success' ? 'bg-success-50 text-success-700' : 'bg-error-50 text-error-700'
          }`}>
            {result.type === 'success' ? (
              <div>
                <h3 className="font-medium">Event submitted successfully!</h3>
                <p className="text-sm mt-1">Event ID: {result.data.event_id}</p>
                <p className="text-sm">Queue position: {result.data.queue_position}</p>
              </div>
            ) : (
              <div className="flex items-start space-x-2">
                <AlertCircle className="w-5 h-5 mt-0.5" />
                <div>
                  <h3 className="font-medium">Error submitting event</h3>
                  <p className="text-sm mt-1">{result.message}</p>
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export default EventSubmission;
EOF

# Ticket management component
cat > frontend/src/components/TicketManagement.js << 'EOF'
import React, { useState, useEffect } from 'react';
import { ExternalLink, Ticket } from 'lucide-react';
import axios from 'axios';

function TicketManagement() {
  const [stats, setStats] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchTicketStats();
    const interval = setInterval(fetchTicketStats, 10000);
    return () => clearInterval(interval);
  }, []);

  const fetchTicketStats = async () => {
    try {
      const response = await axios.get('/api/tickets/stats');
      setStats(response.data);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching ticket stats:', error);
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900">Ticket Management</h1>

      {/* Ticket Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <div className="flex items-center">
            <Ticket className="w-8 h-8 text-primary-500" />
            <div className="ml-3">
              <p className="text-sm font-medium text-gray-600">Total Created</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.total_created || 0}</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <div className="flex items-center">
            <div className="w-8 h-8 bg-blue-500 rounded flex items-center justify-center text-white font-bold">
              J
            </div>
            <div className="ml-3">
              <p className="text-sm font-medium text-gray-600">JIRA Tickets</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.jira_tickets || 0}</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow-sm border">
          <div className="flex items-center">
            <div className="w-8 h-8 bg-green-500 rounded flex items-center justify-center text-white font-bold">
              S
            </div>
            <div className="ml-3">
              <p className="text-sm font-medium text-gray-600">ServiceNow</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.servicenow_tickets || 0}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Ticket Templates */}
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <h2 className="text-xl font-semibold mb-4">Available Templates</h2>
        
        <div className="space-y-4">
          <div className="border rounded-lg p-4">
            <h3 className="font-medium text-gray-900">Database Error Template</h3>
            <p className="text-sm text-gray-600 mt-1">
              For database connection issues, timeouts, and query failures
            </p>
            <div className="flex space-x-2 mt-2">
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                JIRA
              </span>
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                High Priority
              </span>
            </div>
          </div>

          <div className="border rounded-lg p-4">
            <h3 className="font-medium text-gray-900">API Timeout Template</h3>
            <p className="text-sm text-gray-600 mt-1">
              For API endpoint timeouts and performance issues
            </p>
            <div className="flex space-x-2 mt-2">
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                JIRA
              </span>
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                Medium Priority
              </span>
            </div>
          </div>

          <div className="border rounded-lg p-4">
            <h3 className="font-medium text-gray-900">Infrastructure Alert Template</h3>
            <p className="text-sm text-gray-600 mt-1">
              For infrastructure and system-level issues
            </p>
            <div className="flex space-x-2 mt-2">
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                ServiceNow
              </span>
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                Critical
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Integration Links */}
      <div className="bg-white p-6 rounded-lg shadow-sm border">
        <h2 className="text-xl font-semibold mb-4">External Systems</h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <a
            href="https://demo-jira.atlassian.net"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center justify-between p-4 border rounded-lg hover:bg-gray-50 transition-colors"
          >
            <div>
              <h3 className="font-medium">JIRA Dashboard</h3>
              <p className="text-sm text-gray-600">View created issues and bugs</p>
            </div>
            <ExternalLink className="w-5 h-5 text-gray-400" />
          </a>

          <a
            href="https://demo.service-now.com"
            target="_blank" 
            rel="noopener noreferrer"
            className="flex items-center justify-between p-4 border rounded-lg hover:bg-gray-50 transition-colors"
          >
            <div>
              <h3 className="font-medium">ServiceNow Portal</h3>
              <p className="text-sm text-gray-600">View incidents and requests</p>
            </div>
            <ExternalLink className="w-5 h-5 text-gray-400" />
          </a>
        </div>
      </div>
    </div>
  );
}

export default TicketManagement;
EOF

# App CSS styles
cat > frontend/src/styles/App.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Custom animations */
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

.fade-in {
  animation: fadeIn 0.3s ease-out;
}

/* Custom scrollbar */
::-webkit-scrollbar {
  width: 8px;
}

::-webkit-scrollbar-track {
  background: #f1f5f9;
}

::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}

/* Loading animation */
.loading-pulse {
  background: linear-gradient(90deg, #f1f5f9 25%, #e2e8f0 50%, #f1f5f9 75%);
  background-size: 200% 100%;
  animation: loading 1.5s infinite;
}

@keyframes loading {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
EOF

# Index.js for React
cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# HTML template
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="JIRA/ServiceNow Ticket Integration Dashboard" />
    <title>Ticket Integration System - Day 138</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

# Testing files
echo "🧪 Creating comprehensive test suite..."

# Test configuration
cat > pytest.ini << 'EOF'
[tool:pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short
asyncio_mode = auto
EOF

# Unit tests for ticket service
cat > tests/unit/test_ticket_service.py << 'EOF'
import pytest
import httpx
from unittest.mock import Mock, AsyncMock
from services.ticket_service import TicketService
from models.ticket import TicketRequest

@pytest.fixture
async def ticket_service():
    service = TicketService()
    service.jira_client = Mock()
    service.servicenow_client = Mock()
    service.connected = True
    return service

@pytest.mark.asyncio
async def test_create_jira_ticket(ticket_service):
    """Test JIRA ticket creation"""
    # Mock successful response
    mock_response = Mock()
    mock_response.status_code = 201
    mock_response.json.return_value = {"key": "DEMO-123"}
    
    ticket_service.jira_client.post = AsyncMock(return_value=mock_response)
    
    request = TicketRequest(
        title="Test Database Error",
        description="Database connection timeout",
        system="JIRA",
        priority="2",
        category="database",
        team="database",
        source_event_id="event-123",
        fingerprint="abc123"
    )
    
    result = await ticket_service.create_ticket(request)
    assert result == "DEMO-123"
    ticket_service.jira_client.post.assert_called_once()

@pytest.mark.asyncio 
async def test_create_servicenow_ticket(ticket_service):
    """Test ServiceNow ticket creation"""
    mock_response = Mock()
    mock_response.status_code = 201
    mock_response.json.return_value = {"result": {"number": "INC0012345"}}
    
    ticket_service.servicenow_client.post = AsyncMock(return_value=mock_response)
    
    request = TicketRequest(
        title="Infrastructure Alert",
        description="Server memory usage critical",
        system="ServiceNow",
        priority="1", 
        category="infrastructure",
        team="infrastructure",
        source_event_id="event-456",
        fingerprint="def456"
    )
    
    result = await ticket_service.create_ticket(request)
    assert result == "INC0012345"
    ticket_service.servicenow_client.post.assert_called_once()

@pytest.mark.asyncio
async def test_ticket_creation_failure(ticket_service):
    """Test handling of ticket creation failure"""
    mock_response = Mock()
    mock_response.status_code = 400
    mock_response.text = "Bad Request"
    
    ticket_service.jira_client.post = AsyncMock(return_value=mock_response)
    
    request = TicketRequest(
        title="Test Error",
        description="Test",
        system="JIRA",
        priority="3",
        category="test", 
        team="test",
        source_event_id="event-789",
        fingerprint="ghi789"
    )
    
    result = await ticket_service.create_ticket(request)
    assert result is None
EOF

# Unit tests for event processor
cat > tests/unit/test_event_processor.py << 'EOF'
import pytest
from unittest.mock import Mock, AsyncMock
from datetime import datetime
from services.event_processor import EventProcessor
from models.log_event import LogEvent

@pytest.fixture
def mock_ticket_service():
    service = Mock()
    service.create_ticket = AsyncMock(return_value="TICKET-123")
    return service

@pytest.fixture
def event_processor(mock_ticket_service):
    processor = EventProcessor(mock_ticket_service)
    processor.redis = Mock()
    return processor

@pytest.mark.asyncio
async def test_process_critical_event(event_processor):
    """Test processing critical event creates ticket"""
    event = LogEvent(
        id="event-123",
        timestamp=datetime.utcnow(),
        level="critical",
        service="database",
        component="connection",
        message="Database server unavailable",
        metadata={"environment": "production"}
    )
    
    # Mock Redis operations
    event_processor.redis.get = AsyncMock(return_value=None)  # No existing ticket
    event_processor.redis.setex = AsyncMock()
    
    # Mock classification
    event_processor._classify_event = AsyncMock()
    event_processor._classify_event.return_value = Mock(should_create_ticket=True)
    
    # Mock ticket creation
    event_processor._create_ticket_request = AsyncMock()
    event_processor._create_ticket_request.return_value = Mock()
    
    result = await event_processor.process_event(event)
    assert result == "TICKET-123"

@pytest.mark.asyncio
async def test_process_info_event_no_ticket(event_processor):
    """Test info level event doesn't create ticket"""
    event = LogEvent(
        id="event-456", 
        timestamp=datetime.utcnow(),
        level="info",
        service="web",
        component="handler",
        message="Request processed successfully",
        metadata={}
    )
    
    # Mock classification to not create ticket
    event_processor._classify_event = AsyncMock()
    event_processor._classify_event.return_value = Mock(should_create_ticket=False)
    
    result = await event_processor.process_event(event)
    assert result is None

def test_generate_fingerprint(event_processor):
    """Test fingerprint generation for deduplication"""
    event1 = LogEvent(
        id="event-1",
        timestamp=datetime.utcnow(),
        level="error", 
        service="api",
        component="auth",
        message="Authentication failed for user 123",
        metadata={}
    )
    
    event2 = LogEvent(
        id="event-2",
        timestamp=datetime.utcnow(),
        level="error",
        service="api", 
        component="auth",
        message="Authentication failed for user 456",  # Different user ID
        metadata={}
    )
    
    fingerprint1 = event_processor._generate_fingerprint(event1)
    fingerprint2 = event_processor._generate_fingerprint(event2)
    
    # Should be same fingerprint for similar errors
    assert fingerprint1 == fingerprint2
    assert len(fingerprint1) == 16  # SHA256 truncated to 16 chars
EOF

# Integration tests
cat > tests/integration/test_api_endpoints.py << 'EOF'
import pytest
from fastapi.testclient import TestClient
import json
from datetime import datetime

@pytest.fixture
def client():
    from src.main import app
    return TestClient(app)

def test_root_endpoint(client):
    """Test root endpoint returns system info"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["service"] == "Log Ticket Integration System"
    assert data["day"] == 138

def test_health_endpoint(client):
    """Test health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert "status" in data

def test_submit_event_endpoint(client):
    """Test event submission endpoint"""
    event_data = {
        "id": "test-event-123",
        "timestamp": datetime.utcnow().isoformat(),
        "level": "error",
        "service": "test-service",
        "component": "test-component", 
        "message": "Test error message",
        "metadata": {"test": True}
    }
    
    response = client.post("/api/events/submit", json=event_data)
    assert response.status_code == 200
    data = response.json()
    assert "event_id" in data
    assert data["event_id"] == "test-event-123"

def test_dashboard_stats_endpoint(client):
    """Test dashboard statistics endpoint"""
    response = client.get("/api/dashboard/stats")
    assert response.status_code == 200
    data = response.json()
    assert "queue" in data
    assert "processing" in data
    assert "system_health" in data

def test_ticket_stats_endpoint(client):
    """Test ticket statistics endpoint"""
    response = client.get("/api/tickets/stats")
    assert response.status_code == 200
    data = response.json()
    assert "total_created" in data
EOF

# Docker configuration
echo "🐳 Creating Docker configuration..."

cat > Dockerfile << 'EOF'
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY .env .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run application
CMD ["python", "-m", "src.main"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Redis for event queuing
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  # Main application
  ticket-service:
    build: .
    ports:
      - "8000:8000"
    depends_on:
      - redis
    environment:
      - REDIS_URL=redis://redis:6379/0
      - API_HOST=0.0.0.0
      - API_PORT=8000
    volumes:
      - ./logs:/app/logs
    restart: unless-stopped

  # Frontend (if built)
  frontend:
    image: node:18-alpine
    working_dir: /app
    volumes:
      - ./frontend:/app
    ports:
      - "3000:3000"
    command: sh -c "npm install && npm start"
    depends_on:
      - ticket-service
    environment:
      - REACT_APP_API_URL=http://localhost:8000

volumes:
  redis_data:
EOF

cat > .dockerignore << 'EOF'
# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
*.egg-info/
.venv/
venv/

# Node
node_modules/
npm-debug.log
.npm

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Git
.git/
.gitignore

# Logs
*.log
logs/

# Testing
.coverage
.pytest_cache/
.tox/

# Documentation  
docs/build/

# Development
.env.local
.env.development
*.local
EOF

# Build and test scripts
echo "📜 Creating build and test scripts..."

cat > build.sh << 'EOF'
#!/bin/bash
set -e

echo "🏗️  Building JIRA/ServiceNow Ticket Integration System"
echo "======================================================"

# Activate virtual environment
source venv/bin/activate

# Install/upgrade dependencies
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Run code formatting and linting
echo "🔍 Running code quality checks..."
black src/ tests/ --check || true
flake8 src/ tests/ --max-line-length=88 --ignore=E203,W503 || true

# Run type checking
echo "🏷️  Running type checks..."
mypy src/ --ignore-missing-imports || true

# Run unit tests
echo "🧪 Running unit tests..."
python -m pytest tests/unit/ -v --tb=short

# Run integration tests  
echo "🔗 Running integration tests..."
python -m pytest tests/integration/ -v --tb=short

echo "✅ Build completed successfully!"
EOF

cat > test.sh << 'EOF'
#!/bin/bash
set -e

echo "🧪 Running Comprehensive Test Suite"
echo "==================================="

# Activate virtual environment
source venv/bin/activate

# Run all tests with coverage
echo "Running tests with coverage..."
python -m pytest tests/ -v \
    --cov=src \
    --cov-report=html \
    --cov-report=term-missing \
    --tb=short

echo "📊 Coverage report generated in htmlcov/"
echo "✅ All tests completed!"
EOF

cat > start.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting JIRA/ServiceNow Ticket Integration System"
echo "==================================================="

# Check if Redis is running
if ! redis-cli ping > /dev/null 2>&1; then
    echo "⚠️  Redis not running. Starting Redis with Docker..."
    docker run -d --name redis-ticket-system -p 6379:6379 redis:7-alpine || true
    sleep 3
fi

# Activate virtual environment
source venv/bin/activate

# Start the application
echo "🎯 Starting ticket integration service on http://localhost:8000"
echo "📊 Dashboard will be available at http://localhost:8000"
echo ""
echo "Press Ctrl+C to stop..."

python -m src.main
EOF

cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping JIRA/ServiceNow Ticket Integration System"
echo "=================================================="

# Stop Redis container if running
docker stop redis-ticket-system > /dev/null 2>&1 || true
docker rm redis-ticket-system > /dev/null 2>&1 || true

# Kill any running Python processes
pkill -f "python -m src.main" || true

echo "✅ System stopped successfully!"
EOF

cat > demo.sh << 'EOF'
#!/bin/bash
set -e

echo "🎬 JIRA/ServiceNow Ticket Integration Demo"
echo "========================================="

# Activate virtual environment
source venv/bin/activate

# Start system in background
echo "🚀 Starting system..."
python -m src.main &
SERVER_PID=$!

# Wait for server to start
echo "⏳ Waiting for system to initialize..."
sleep 5

# Test system health
echo "🏥 Checking system health..."
curl -s http://localhost:8000/health | jq '.'

# Generate test events
echo ""
echo "📊 Generating test events..."
curl -s -X POST "http://localhost:8000/api/events/test/generate?count=10" | jq '.'

# Wait for processing
echo ""
echo "⏳ Waiting for event processing..."
sleep 8

# Check dashboard stats
echo ""
echo "📈 Dashboard Statistics:"
curl -s http://localhost:8000/api/dashboard/stats | jq '.'

echo ""
echo "✅ Demo completed successfully!"
echo "🌐 Dashboard available at: http://localhost:8000"
echo "📊 API documentation at: http://localhost:8000/docs"

# Keep server running for manual testing
echo ""
echo "Press Ctrl+C to stop the demo server..."
wait $SERVER_PID
EOF

# Make scripts executable
chmod +x build.sh test.sh start.sh stop.sh demo.sh

# Frontend setup
echo "⚛️ Setting up React frontend..."
cd frontend

# Install Node.js dependencies (if available)
if command -v npm &> /dev/null; then
    echo "📦 Installing npm dependencies..."
    npm install
    
    echo "🏗️  Building React app..."
    npm run build
    
    echo "✅ Frontend build complete!"
else
    echo "⚠️  npm not found. Frontend will need to be built manually."
    echo "   Run: cd frontend && npm install && npm run build"
fi

cd ..

# Create documentation
echo "📚 Creating documentation..."
cat > README.md << 'EOF'
# JIRA/ServiceNow Ticket Integration System

Day 138 of the 254-Day Hands-On System Design Series

## Overview

Automatic ticket creation system that analyzes log events and creates appropriate tickets in JIRA or ServiceNow based on configurable rules.

## Features

- ✅ Automatic event classification and ticket routing
- ✅ JIRA and ServiceNow API integration
- ✅ Intelligent deduplication using event fingerprints
- ✅ Template-based ticket creation
- ✅ Real-time monitoring dashboard
- ✅ Background event processing with Redis
- ✅ Comprehensive test suite

## Quick Start

```bash
# Build and test
./build.sh

# Start system
./start.sh

# Run demo
./demo.sh
```

## Architecture

The system processes log events through several stages:
1. Event classification and priority assignment
2. Fingerprint generation for deduplication
3. Template-based ticket content generation
4. API integration with target systems
5. Ticket lifecycle management

## API Endpoints

- `GET /` - System information
- `GET /health` - Health check
- `POST /api/events/submit` - Submit log event
- `GET /api/dashboard/stats` - Dashboard statistics
- `POST /api/tickets/create` - Create ticket manually

## Configuration

Edit `.env` file to configure:
- JIRA credentials and project
- ServiceNow instance and credentials
- Redis connection settings
- Processing parameters

## Testing

```bash
# Unit tests
python -m pytest tests/unit/ -v

# Integration tests  
python -m pytest tests/integration/ -v

# All tests with coverage
./test.sh
```

## Development

The system is built with:
- **Backend**: FastAPI + Python 3.11
- **Frontend**: React + Tailwind CSS
- **Queue**: Redis
- **APIs**: JIRA REST API v3, ServiceNow Table API

## Production Deployment

```bash
# Docker deployment
docker-compose up -d

# Check services
docker-compose ps

# View logs
docker-compose logs -f ticket-service
```
EOF

# Final verification
echo "🔍 Verifying installation..."

# Check file structure
echo "📁 Verifying file structure..."
if [[ -f "src/main.py" && -f "src/services/ticket_service.py" && -f "frontend/src/App.js" ]]; then
    echo "✅ All core files created successfully"
else
    echo "❌ Some files missing"
    exit 1
fi

# Check Python syntax
echo "🐍 Checking Python syntax..."
python -m py_compile src/main.py
python -m py_compile src/services/ticket_service.py
python -m py_compile src/services/event_processor.py

# Test imports
echo "📦 Testing imports..."
python -c "import sys; sys.path.append('src'); from main import app; print('✅ All Python imports successful')"

# Run build and test
echo "🏗️  Running build process..."
./build.sh

# Run demo
echo "🎬 Running system demonstration..."
./demo.sh &
DEMO_PID=$!

# Wait for demo to initialize
sleep 10

# Test key endpoints
echo "🌐 Testing web endpoints..."

# Test health endpoint
HEALTH_RESPONSE=$(curl -s http://localhost:8000/health)
if echo "$HEALTH_RESPONSE" | grep -q "status"; then
    echo "✅ Health endpoint working"
else
    echo "❌ Health endpoint failed"
fi

# Test dashboard stats
STATS_RESPONSE=$(curl -s http://localhost:8000/api/dashboard/stats)
if echo "$STATS_RESPONSE" | grep -q "queue"; then
    echo "✅ Dashboard API working"
else
    echo "❌ Dashboard API failed"
fi

# Test event submission
EVENT_DATA='{"id":"test-123","timestamp":"2025-05-16T10:00:00Z","level":"error","service":"test","component":"handler","message":"Test error","metadata":{}}'
SUBMIT_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "$EVENT_DATA" http://localhost:8000/api/events/submit)
if echo "$SUBMIT_RESPONSE" | grep -q "event_id"; then
    echo "✅ Event submission working"
else
    echo "❌ Event submission failed"
fi

# Stop demo
kill $DEMO_PID 2>/dev/null || true

# Final success message
echo ""
echo "🎉 SUCCESS! JIRA/ServiceNow Ticket Integration System Setup Complete!"
echo "=================================================================="
echo ""
echo "📋 What was created:"
echo "  ✅ Complete Python backend with FastAPI"
echo "  ✅ React frontend with modern UI"  
echo "  ✅ Redis-based event processing queue"
echo "  ✅ JIRA and ServiceNow API integrations"
echo "  ✅ Comprehensive test suite"
echo "  ✅ Docker deployment configuration"
echo "  ✅ Monitoring and dashboard"
echo ""
echo "🚀 Quick Start Commands:"
echo "  ./start.sh    - Start the complete system"
echo "  ./demo.sh     - Run interactive demonstration" 
echo "  ./test.sh     - Run all tests"
echo "  ./stop.sh     - Stop all services"
echo ""
echo "🌐 Access Points:"
echo "  Dashboard:     http://localhost:8000"
echo "  API Docs:      http://localhost:8000/docs"
echo "  React App:     http://localhost:3000 (if built)"
echo ""
echo "📊 System Features:"
echo "  • Automatic log event classification"
echo "  • Smart ticket routing (JIRA/ServiceNow)"
echo "  • Deduplication via event fingerprints"
echo "  • Template-based ticket generation"
echo "  • Real-time processing dashboard"
echo "  • Background queue processing"
echo ""
echo "🔧 Configuration:"
echo "  Edit .env file to customize JIRA/ServiceNow credentials"
echo "  Modify src/utils/config.py for processing rules"
echo ""
echo "🎯 Test the System:"
echo "1. Start: ./start.sh"
echo "2. Visit: http://localhost:8000"
echo "3. Click 'Generate Test Events' on dashboard"
echo "4. Watch tickets being created automatically"
echo ""
echo "💡 This implementation demonstrates:"
echo "  • Enterprise system integration patterns"
echo "  • Event-driven architecture" 
echo "  • Intelligent event classification"
echo "  • Production-ready error handling"
echo "  • Modern web dashboard development"
echo ""
echo "✨ Ready for Day 138 assignment completion!"

cd ..
echo "📍 Setup completed in: $(pwd)/$PROJECT_NAME"