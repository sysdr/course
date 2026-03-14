#!/bin/bash

# Day 137: PagerDuty/OpsGenie Integration - Complete Implementation
# Module 5: Integration and Ecosystem | Week 20: External System Integration

set -e

echo "🚀 Day 137: Building PagerDuty/OpsGenie Integration System"
echo "========================================================"

# Create project directory structure
echo "📁 Creating project structure..."
mkdir -p day137-incident-management/{src,tests,config,frontend,docker,scripts,logs}
cd day137-incident-management

# Create detailed directory structure
mkdir -p src/{core,integrations,webhooks,monitoring,utils}
mkdir -p tests/{unit,integration,load}
mkdir -p frontend/{public,src/{components,hooks,services,styles}}
mkdir -p config/{templates,policies}
mkdir -p docker/

echo "✅ Project structure created successfully"

# Create Python virtual environment with Python 3
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Create requirements.txt with latest May 2025 compatible libraries
cat > requirements.txt << 'EOF'
# Core FastAPI and async libraries
fastapi==0.111.0
uvicorn[standard]==0.30.1
pydantic==2.7.1
pydantic-settings==2.3.0

# HTTP client and webhooks
httpx==0.27.0
aiohttp==3.9.5

# Database and caching
sqlalchemy==2.0.30
alembic==1.13.1
redis==5.0.4

# Background tasks and scheduling
celery==5.4.0
APScheduler==3.10.4

# Monitoring and metrics
prometheus-client==0.20.0
structlog==24.1.0

# Security and validation
python-jose[cryptography]==3.3.0
python-multipart==0.0.9

# Testing
pytest==8.2.0
pytest-asyncio==0.23.6
pytest-cov==5.0.0
httpx==0.27.0

# Development
black==24.4.2
isort==5.13.2
mypy==1.10.0
EOF

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create core application structure
echo "🏗️  Creating core application files..."

# Main application entry point
cat > src/main.py << 'EOF'
"""
Day 137: PagerDuty/OpsGenie Integration System
Main application entry point with FastAPI server
"""

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

import structlog
import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse

from core.config import get_settings
from core.alert_router import AlertRouter
from integrations.incident_manager import IncidentManager
from webhooks.webhook_handler import WebhookHandler
from monitoring.health_monitor import HealthMonitor

# Configure structured logging
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.dev.ConsoleRenderer()
    ],
    wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
)

logger = structlog.get_logger()

# Global instances
alert_router = None
incident_manager = None
webhook_handler = None
health_monitor = None

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Initialize and cleanup application lifecycle"""
    global alert_router, incident_manager, webhook_handler, health_monitor
    
    logger.info("🚀 Starting PagerDuty/OpsGenie Integration System")
    
    # Initialize core components
    settings = get_settings()
    
    # Initialize incident manager with provider configurations
    incident_manager = IncidentManager(
        pagerduty_api_key=settings.pagerduty_api_key,
        opsgenie_api_key=settings.opsgenie_api_key
    )
    await incident_manager.initialize()
    
    # Initialize alert router with escalation policies
    alert_router = AlertRouter(incident_manager)
    await alert_router.load_escalation_policies()
    
    # Initialize webhook handler for bidirectional communication
    webhook_handler = WebhookHandler(incident_manager, alert_router)
    
    # Initialize health monitoring
    health_monitor = HealthMonitor(incident_manager)
    await health_monitor.start_monitoring()
    
    logger.info("✅ All systems initialized successfully")
    
    yield
    
    # Cleanup
    logger.info("🛑 Shutting down systems...")
    if health_monitor:
        await health_monitor.stop_monitoring()
    if incident_manager:
        await incident_manager.cleanup()

# Create FastAPI application
app = FastAPI(
    title="Incident Management Integration System",
    description="PagerDuty/OpsGenie integration for distributed log processing",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Routes
@app.post("/api/v1/alerts")
async def create_alert(alert_data: dict, request: Request):
    """Create new alert and route to appropriate incident management system"""
    try:
        result = await alert_router.process_alert(alert_data)
        logger.info("Alert processed successfully", 
                   alert_id=result.get("alert_id"), 
                   provider=result.get("provider"))
        return result
    except Exception as e:
        logger.error("Failed to process alert", error=str(e))
        raise

@app.get("/api/v1/incidents")
async def get_incidents():
    """Get current incidents from all providers"""
    return await incident_manager.get_all_incidents()

@app.get("/api/v1/health")
async def get_health():
    """Get system health status"""
    return await health_monitor.get_health_status()

@app.get("/api/v1/metrics")
async def get_metrics():
    """Get integration metrics"""
    return await health_monitor.get_metrics()

@app.post("/api/v1/webhooks/pagerduty")
async def pagerduty_webhook(request: Request):
    """Handle PagerDuty webhooks"""
    body = await request.body()
    headers = dict(request.headers)
    return await webhook_handler.handle_pagerduty_webhook(body, headers)

@app.post("/api/v1/webhooks/opsgenie")
async def opsgenie_webhook(request: Request):
    """Handle OpsGenie webhooks"""
    body = await request.body()
    headers = dict(request.headers)
    return await webhook_handler.handle_opsgenie_webhook(body, headers)

# Serve React frontend
app.mount("/static", StaticFiles(directory="frontend/build/static"), name="static")

@app.get("/{path:path}")
async def serve_frontend(path: str):
    """Serve React frontend for all routes"""
    return HTMLResponse(open("frontend/build/index.html").read())

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
cat > src/core/config.py << 'EOF'
"""Configuration management for the incident management system"""

from typing import Optional
from pydantic import BaseSettings, Field

class Settings(BaseSettings):
    """Application settings with environment variable support"""
    
    # API Keys (use environment variables in production)
    pagerduty_api_key: str = Field(default="test_pd_key", env="PAGERDUTY_API_KEY")
    opsgenie_api_key: str = Field(default="test_og_key", env="OPSGENIE_API_KEY")
    
    # Webhook validation
    pagerduty_webhook_secret: Optional[str] = Field(default=None, env="PAGERDUTY_WEBHOOK_SECRET")
    opsgenie_webhook_secret: Optional[str] = Field(default=None, env="OPSGENIE_WEBHOOK_SECRET")
    
    # Database
    database_url: str = Field(default="sqlite:///./incidents.db", env="DATABASE_URL")
    redis_url: str = Field(default="redis://localhost:6379", env="REDIS_URL")
    
    # System settings
    max_alerts_per_minute: int = Field(default=100)
    default_escalation_timeout_minutes: int = Field(default=15)
    
    # Feature flags
    enable_pagerduty: bool = Field(default=True)
    enable_opsgenie: bool = Field(default=True)
    enable_webhook_validation: bool = Field(default=True)
    
    class Config:
        env_file = ".env"

_settings = None

def get_settings() -> Settings:
    """Get application settings (singleton pattern)"""
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings
EOF

# Alert Router - Core alert classification and routing logic
cat > src/core/alert_router.py << 'EOF'
"""
Alert Router - Core component for alert classification and routing
Determines which incidents should be created in which external systems
"""

import asyncio
import json
import time
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from enum import Enum

import structlog

logger = structlog.get_logger()

class AlertSeverity(Enum):
    """Alert severity levels mapped to external system severities"""
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium" 
    LOW = "low"
    INFO = "info"

class AlertSource(Enum):
    """Source systems that generate alerts"""
    DATABASE = "database"
    API = "api"
    SECURITY = "security"
    INFRASTRUCTURE = "infrastructure"
    APPLICATION = "application"

@dataclass
class AlertData:
    """Structured alert data"""
    id: str
    title: str
    description: str
    source: AlertSource
    severity: AlertSeverity
    timestamp: datetime
    metadata: Dict[str, Any]
    tags: List[str]
    service_name: str
    team: Optional[str] = None

@dataclass
class RoutingResult:
    """Result of alert routing decision"""
    alert_id: str
    provider: str
    incident_id: Optional[str]
    escalation_policy: str
    success: bool
    error: Optional[str] = None

class AlertRouter:
    """Core alert routing and classification engine"""
    
    def __init__(self, incident_manager):
        self.incident_manager = incident_manager
        self.escalation_policies = {}
        self.service_catalog = {}
        self.routing_rules = {}
        
    async def load_escalation_policies(self):
        """Load escalation policies from configuration"""
        # Default escalation policies
        self.escalation_policies = {
            "critical_24x7": {
                "provider": "pagerduty",
                "escalation_timeout": 5,  # minutes
                "teams": ["oncall-primary", "oncall-secondary"]
            },
            "business_hours": {
                "provider": "opsgenie",
                "escalation_timeout": 15,
                "teams": ["support-team"]
            },
            "infrastructure": {
                "provider": "pagerduty", 
                "escalation_timeout": 10,
                "teams": ["infrastructure-team"]
            },
            "security": {
                "provider": "both",  # Create in both systems for security
                "escalation_timeout": 2,
                "teams": ["security-team", "oncall-primary"]
            }
        }
        
        # Service to team mapping
        self.service_catalog = {
            "payment-service": {"team": "payments", "criticality": "critical"},
            "user-service": {"team": "identity", "criticality": "high"},
            "recommendation-service": {"team": "ml", "criticality": "medium"},
            "logging-service": {"team": "infrastructure", "criticality": "low"},
            "security-service": {"team": "security", "criticality": "critical"}
        }
        
        # Routing rules based on alert characteristics
        self.routing_rules = {
            ("database", "critical"): "critical_24x7",
            ("security", "*"): "security",  # All security alerts
            ("api", "critical"): "critical_24x7",
            ("infrastructure", "*"): "infrastructure",
            ("application", "critical"): "critical_24x7",
            ("application", "high"): "business_hours",
            ("*", "low"): "business_hours",  # Default for low priority
        }
        
        logger.info("Escalation policies loaded", policies=len(self.escalation_policies))
    
    async def process_alert(self, alert_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process incoming alert and route to appropriate system"""
        start_time = time.time()
        
        try:
            # Parse and validate alert data
            alert = self._parse_alert_data(alert_data)
            logger.info("Processing alert", alert_id=alert.id, severity=alert.severity.value)
            
            # Apply classification rules
            classified_alert = await self._classify_alert(alert)
            
            # Determine routing destination
            routing_policy = self._get_routing_policy(classified_alert)
            
            # Create incident(s) in external systems
            routing_results = await self._create_incidents(classified_alert, routing_policy)
            
            processing_time = time.time() - start_time
            
            return {
                "alert_id": alert.id,
                "processing_time_ms": round(processing_time * 1000, 2),
                "routing_results": [asdict(result) for result in routing_results],
                "success": all(r.success for r in routing_results)
            }
            
        except Exception as e:
            logger.error("Alert processing failed", error=str(e))
            return {
                "alert_id": alert_data.get("id", "unknown"),
                "success": False,
                "error": str(e)
            }
    
    def _parse_alert_data(self, data: Dict[str, Any]) -> AlertData:
        """Parse raw alert data into structured format"""
        return AlertData(
            id=data.get("id", f"alert_{int(time.time())}"),
            title=data.get("title", "Unknown Alert"),
            description=data.get("description", ""),
            source=AlertSource(data.get("source", "application")),
            severity=AlertSeverity(data.get("severity", "medium")),
            timestamp=datetime.fromisoformat(
                data.get("timestamp", datetime.now(timezone.utc).isoformat())
            ),
            metadata=data.get("metadata", {}),
            tags=data.get("tags", []),
            service_name=data.get("service_name", "unknown-service"),
            team=data.get("team")
        )
    
    async def _classify_alert(self, alert: AlertData) -> AlertData:
        """Apply classification rules to enhance alert data"""
        # Enhance with service catalog information
        if alert.service_name in self.service_catalog:
            service_info = self.service_catalog[alert.service_name]
            if not alert.team:
                alert.team = service_info["team"]
            
            # Upgrade severity based on service criticality
            if service_info["criticality"] == "critical" and alert.severity in [AlertSeverity.MEDIUM, AlertSeverity.LOW]:
                alert.severity = AlertSeverity.HIGH
                alert.tags.append("service-critical")
        
        # Time-based classification
        current_hour = datetime.now().hour
        if current_hour < 8 or current_hour > 18:  # After hours
            alert.tags.append("after-hours")
        
        return alert
    
    def _get_routing_policy(self, alert: AlertData) -> str:
        """Determine which escalation policy to use"""
        # Check specific routing rules
        for (source_pattern, severity_pattern), policy in self.routing_rules.items():
            if ((source_pattern == "*" or source_pattern == alert.source.value) and
                (severity_pattern == "*" or severity_pattern == alert.severity.value)):
                return policy
        
        # Default routing based on severity
        if alert.severity in [AlertSeverity.CRITICAL, AlertSeverity.HIGH]:
            return "critical_24x7"
        else:
            return "business_hours"
    
    async def _create_incidents(self, alert: AlertData, policy_name: str) -> List[RoutingResult]:
        """Create incident(s) in external systems based on policy"""
        policy = self.escalation_policies[policy_name]
        results = []
        
        providers = []
        if policy["provider"] == "both":
            providers = ["pagerduty", "opsgenie"]
        else:
            providers = [policy["provider"]]
        
        # Create incidents in parallel
        tasks = []
        for provider in providers:
            task = self._create_provider_incident(alert, provider, policy)
            tasks.append(task)
        
        incident_results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for i, result in enumerate(incident_results):
            if isinstance(result, Exception):
                results.append(RoutingResult(
                    alert_id=alert.id,
                    provider=providers[i],
                    incident_id=None,
                    escalation_policy=policy_name,
                    success=False,
                    error=str(result)
                ))
            else:
                results.append(result)
        
        return results
    
    async def _create_provider_incident(self, alert: AlertData, provider: str, policy: Dict) -> RoutingResult:
        """Create incident in specific provider"""
        try:
            if provider == "pagerduty":
                incident_id = await self.incident_manager.create_pagerduty_incident(alert, policy)
            elif provider == "opsgenie":
                incident_id = await self.incident_manager.create_opsgenie_incident(alert, policy)
            else:
                raise ValueError(f"Unknown provider: {provider}")
            
            return RoutingResult(
                alert_id=alert.id,
                provider=provider,
                incident_id=incident_id,
                escalation_policy=policy,
                success=True
            )
            
        except Exception as e:
            logger.error("Failed to create incident", provider=provider, error=str(e))
            return RoutingResult(
                alert_id=alert.id,
                provider=provider,
                incident_id=None,
                escalation_policy=policy,
                success=False,
                error=str(e)
            )
EOF

# Incident Manager - Integration with external systems
cat > src/integrations/incident_manager.py << 'EOF'
"""
Incident Manager - Integration with PagerDuty and OpsGenie APIs
Handles incident creation, updates, and synchronization
"""

import asyncio
import json
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any

import httpx
import structlog
from core.config import get_settings

logger = structlog.get_logger()

class IncidentManager:
    """Manages incidents across multiple external systems"""
    
    def __init__(self, pagerduty_api_key: str, opsgenie_api_key: str):
        self.settings = get_settings()
        self.pagerduty_api_key = pagerduty_api_key
        self.opsgenie_api_key = opsgenie_api_key
        self.active_incidents = {}
        
        # HTTP clients with proper configuration
        self.pagerduty_client = None
        self.opsgenie_client = None
    
    async def initialize(self):
        """Initialize HTTP clients and validate connectivity"""
        timeout = httpx.Timeout(10.0, connect=5.0)
        
        self.pagerduty_client = httpx.AsyncClient(
            base_url="https://api.pagerduty.com",
            headers={
                "Authorization": f"Token token={self.pagerduty_api_key}",
                "Content-Type": "application/json",
                "Accept": "application/vnd.pagerduty+json;version=2"
            },
            timeout=timeout
        )
        
        self.opsgenie_client = httpx.AsyncClient(
            base_url="https://api.opsgenie.com/v2",
            headers={
                "Authorization": f"GenieKey {self.opsgenie_api_key}",
                "Content-Type": "application/json"
            },
            timeout=timeout
        )
        
        # Test connectivity
        await self._test_connectivity()
        logger.info("Incident manager initialized successfully")
    
    async def cleanup(self):
        """Cleanup HTTP clients"""
        if self.pagerduty_client:
            await self.pagerduty_client.aclose()
        if self.opsgenie_client:
            await self.opsgenie_client.aclose()
    
    async def _test_connectivity(self):
        """Test connectivity to external APIs"""
        try:
            # Test PagerDuty
            if self.settings.enable_pagerduty:
                response = await self.pagerduty_client.get("/users", params={"limit": 1})
                if response.status_code == 200:
                    logger.info("PagerDuty connectivity verified")
                else:
                    logger.warning("PagerDuty connectivity issues", status=response.status_code)
            
            # Test OpsGenie  
            if self.settings.enable_opsgenie:
                response = await self.opsgenie_client.get("/account")
                if response.status_code == 200:
                    logger.info("OpsGenie connectivity verified")
                else:
                    logger.warning("OpsGenie connectivity issues", status=response.status_code)
                    
        except Exception as e:
            logger.error("Connectivity test failed", error=str(e))
    
    async def create_pagerduty_incident(self, alert_data, policy: Dict) -> str:
        """Create incident in PagerDuty"""
        if not self.settings.enable_pagerduty:
            raise Exception("PagerDuty integration disabled")
        
        # Map internal severity to PagerDuty severity
        severity_mapping = {
            "critical": "critical",
            "high": "error", 
            "medium": "warning",
            "low": "info",
            "info": "info"
        }
        
        incident_payload = {
            "incident": {
                "type": "incident",
                "title": alert_data.title,
                "service": {
                    "id": "PSERVICE",  # Default service ID for demo
                    "type": "service_reference"
                },
                "priority": {
                    "id": "P1" if alert_data.severity.value == "critical" else "P2",
                    "type": "priority_reference"
                },
                "urgency": "high" if alert_data.severity.value in ["critical", "high"] else "low",
                "body": {
                    "type": "incident_body",
                    "details": json.dumps({
                        "description": alert_data.description,
                        "source": alert_data.source.value,
                        "service_name": alert_data.service_name,
                        "metadata": alert_data.metadata,
                        "tags": alert_data.tags
                    }, indent=2)
                }
            }
        }
        
        try:
            response = await self.pagerduty_client.post("/incidents", json=incident_payload)
            response.raise_for_status()
            
            result = response.json()
            incident_id = result["incident"]["id"]
            
            # Store incident locally
            self.active_incidents[incident_id] = {
                "provider": "pagerduty",
                "alert_id": alert_data.id,
                "created_at": datetime.now(timezone.utc),
                "status": "triggered"
            }
            
            logger.info("PagerDuty incident created", 
                       incident_id=incident_id, 
                       alert_id=alert_data.id)
            
            return incident_id
            
        except httpx.HTTPStatusError as e:
            logger.error("PagerDuty API error", 
                        status=e.response.status_code,
                        response=e.response.text)
            raise Exception(f"PagerDuty API error: {e.response.status_code}")
        except Exception as e:
            logger.error("PagerDuty incident creation failed", error=str(e))
            raise
    
    async def create_opsgenie_incident(self, alert_data, policy: Dict) -> str:
        """Create alert in OpsGenie"""
        if not self.settings.enable_opsgenie:
            raise Exception("OpsGenie integration disabled")
        
        # Map internal severity to OpsGenie priority
        priority_mapping = {
            "critical": "P1",
            "high": "P2",
            "medium": "P3", 
            "low": "P4",
            "info": "P5"
        }
        
        alert_payload = {
            "message": alert_data.title,
            "description": alert_data.description,
            "priority": priority_mapping.get(alert_data.severity.value, "P3"),
            "source": alert_data.source.value,
            "entity": alert_data.service_name,
            "alias": f"alert_{alert_data.id}",
            "details": {
                "service_name": alert_data.service_name,
                "team": alert_data.team,
                "metadata": json.dumps(alert_data.metadata),
                "tags": ",".join(alert_data.tags)
            },
            "tags": alert_data.tags
        }
        
        try:
            response = await self.opsgenie_client.post("/alerts", json=alert_payload)
            response.raise_for_status()
            
            result = response.json()
            alert_id = result["requestId"]
            
            # Store incident locally
            self.active_incidents[alert_id] = {
                "provider": "opsgenie",
                "alert_id": alert_data.id,
                "created_at": datetime.now(timezone.utc),
                "status": "open"
            }
            
            logger.info("OpsGenie alert created",
                       incident_id=alert_id,
                       alert_id=alert_data.id)
            
            return alert_id
            
        except httpx.HTTPStatusError as e:
            logger.error("OpsGenie API error",
                        status=e.response.status_code, 
                        response=e.response.text)
            raise Exception(f"OpsGenie API error: {e.response.status_code}")
        except Exception as e:
            logger.error("OpsGenie alert creation failed", error=str(e))
            raise
    
    async def get_all_incidents(self) -> Dict[str, List[Dict]]:
        """Get incidents from all providers"""
        pagerduty_incidents = []
        opsgenie_incidents = []
        
        try:
            if self.settings.enable_pagerduty and self.pagerduty_client:
                pd_response = await self.pagerduty_client.get("/incidents", params={"limit": 50})
                if pd_response.status_code == 200:
                    pagerduty_incidents = pd_response.json().get("incidents", [])
        except Exception as e:
            logger.error("Failed to fetch PagerDuty incidents", error=str(e))
        
        try:
            if self.settings.enable_opsgenie and self.opsgenie_client:
                og_response = await self.opsgenie_client.get("/alerts", params={"limit": 50})
                if og_response.status_code == 200:
                    opsgenie_incidents = og_response.json().get("data", [])
        except Exception as e:
            logger.error("Failed to fetch OpsGenie alerts", error=str(e))
        
        return {
            "pagerduty": pagerduty_incidents,
            "opsgenie": opsgenie_incidents,
            "local_incidents": list(self.active_incidents.values())
        }
EOF

# Webhook Handler for bidirectional communication
cat > src/webhooks/webhook_handler.py << 'EOF'
"""
Webhook Handler - Process webhooks from PagerDuty and OpsGenie
Handles acknowledgments, status updates, and incident synchronization
"""

import json
import hmac
import hashlib
from datetime import datetime
from typing import Dict, Any

import structlog
from fastapi import HTTPException
from core.config import get_settings

logger = structlog.get_logger()

class WebhookHandler:
    """Handles incoming webhooks from external incident management systems"""
    
    def __init__(self, incident_manager, alert_router):
        self.incident_manager = incident_manager
        self.alert_router = alert_router
        self.settings = get_settings()
        
    async def handle_pagerduty_webhook(self, body: bytes, headers: Dict[str, str]) -> Dict[str, Any]:
        """Process PagerDuty webhook"""
        try:
            # Validate webhook signature if configured
            if self.settings.enable_webhook_validation and self.settings.pagerduty_webhook_secret:
                self._validate_pagerduty_signature(body, headers)
            
            # Parse webhook payload
            payload = json.loads(body)
            messages = payload.get("messages", [])
            
            processed_events = []
            for message in messages:
                event_result = await self._process_pagerduty_event(message)
                processed_events.append(event_result)
            
            logger.info("Processed PagerDuty webhook", events=len(processed_events))
            
            return {
                "status": "success",
                "processed_events": len(processed_events),
                "events": processed_events
            }
            
        except Exception as e:
            logger.error("Failed to process PagerDuty webhook", error=str(e))
            raise HTTPException(status_code=400, detail=str(e))
    
    async def handle_opsgenie_webhook(self, body: bytes, headers: Dict[str, str]) -> Dict[str, Any]:
        """Process OpsGenie webhook"""
        try:
            # Validate webhook signature if configured
            if self.settings.enable_webhook_validation and self.settings.opsgenie_webhook_secret:
                self._validate_opsgenie_signature(body, headers)
            
            # Parse webhook payload
            payload = json.loads(body)
            
            event_result = await self._process_opsgenie_event(payload)
            
            logger.info("Processed OpsGenie webhook", event_type=payload.get("action"))
            
            return {
                "status": "success", 
                "event": event_result
            }
            
        except Exception as e:
            logger.error("Failed to process OpsGenie webhook", error=str(e))
            raise HTTPException(status_code=400, detail=str(e))
    
    def _validate_pagerduty_signature(self, body: bytes, headers: Dict[str, str]):
        """Validate PagerDuty webhook signature"""
        signature = headers.get("x-pagerduty-signature")
        if not signature:
            raise ValueError("Missing PagerDuty signature")
        
        expected = hmac.new(
            self.settings.pagerduty_webhook_secret.encode(),
            body,
            hashlib.sha256
        ).hexdigest()
        
        if not hmac.compare_digest(f"v1={expected}", signature):
            raise ValueError("Invalid PagerDuty signature")
    
    def _validate_opsgenie_signature(self, body: bytes, headers: Dict[str, str]):
        """Validate OpsGenie webhook signature"""
        signature = headers.get("x-opsgenie-signature")
        if not signature:
            raise ValueError("Missing OpsGenie signature")
        
        expected = hashlib.sha256(
            (self.settings.opsgenie_webhook_secret + body.decode()).encode()
        ).hexdigest()
        
        if not hmac.compare_digest(expected, signature):
            raise ValueError("Invalid OpsGenie signature")
    
    async def _process_pagerduty_event(self, message: Dict[str, Any]) -> Dict[str, Any]:
        """Process individual PagerDuty event"""
        event_type = message.get("event")
        incident = message.get("incident", {})
        incident_id = incident.get("id")
        
        if not incident_id:
            return {"status": "skipped", "reason": "no_incident_id"}
        
        # Update local incident tracking
        if incident_id in self.incident_manager.active_incidents:
            self.incident_manager.active_incidents[incident_id]["last_updated"] = datetime.now()
            self.incident_manager.active_incidents[incident_id]["status"] = incident.get("status")
        
        # Process different event types
        if event_type == "incident.acknowledged":
            await self._handle_incident_acknowledged(incident_id, "pagerduty", incident)
        elif event_type == "incident.resolved":
            await self._handle_incident_resolved(incident_id, "pagerduty", incident)
        elif event_type == "incident.escalated":
            await self._handle_incident_escalated(incident_id, "pagerduty", incident)
        
        return {
            "status": "processed",
            "event_type": event_type,
            "incident_id": incident_id
        }
    
    async def _process_opsgenie_event(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Process OpsGenie webhook event"""
        action = payload.get("action")
        alert = payload.get("alert", {})
        alert_id = alert.get("alertId")
        
        if not alert_id:
            return {"status": "skipped", "reason": "no_alert_id"}
        
        # Update local incident tracking
        if alert_id in self.incident_manager.active_incidents:
            self.incident_manager.active_incidents[alert_id]["last_updated"] = datetime.now()
            self.incident_manager.active_incidents[alert_id]["status"] = alert.get("status")
        
        # Process different actions
        if action == "Acknowledged":
            await self._handle_incident_acknowledged(alert_id, "opsgenie", alert)
        elif action == "Closed":
            await self._handle_incident_resolved(alert_id, "opsgenie", alert)
        elif action == "Escalated":
            await self._handle_incident_escalated(alert_id, "opsgenie", alert)
        
        return {
            "status": "processed",
            "action": action,
            "alert_id": alert_id
        }
    
    async def _handle_incident_acknowledged(self, incident_id: str, provider: str, incident_data: Dict):
        """Handle incident acknowledgment"""
        logger.info("Incident acknowledged", 
                   incident_id=incident_id, 
                   provider=provider)
        
        # Update incident status and stop escalation
        if incident_id in self.incident_manager.active_incidents:
            self.incident_manager.active_incidents[incident_id]["acknowledged"] = True
            self.incident_manager.active_incidents[incident_id]["acknowledged_by"] = incident_data.get("acknowledged_by")
    
    async def _handle_incident_resolved(self, incident_id: str, provider: str, incident_data: Dict):
        """Handle incident resolution"""
        logger.info("Incident resolved", 
                   incident_id=incident_id,
                   provider=provider)
        
        # Mark incident as resolved and trigger post-incident workflows
        if incident_id in self.incident_manager.active_incidents:
            self.incident_manager.active_incidents[incident_id]["resolved"] = True
            self.incident_manager.active_incidents[incident_id]["resolved_by"] = incident_data.get("resolved_by")
    
    async def _handle_incident_escalated(self, incident_id: str, provider: str, incident_data: Dict):
        """Handle incident escalation"""
        logger.info("Incident escalated",
                   incident_id=incident_id,
                   provider=provider)
        
        # Update escalation tracking
        if incident_id in self.incident_manager.active_incidents:
            escalations = self.incident_manager.active_incidents[incident_id].get("escalations", 0)
            self.incident_manager.active_incidents[incident_id]["escalations"] = escalations + 1
EOF

# Health Monitor for system health tracking
cat > src/monitoring/health_monitor.py << 'EOF'
"""
Health Monitor - Monitor integration health and performance metrics
Tracks API connectivity, response times, and system health
"""

import asyncio
import time
from datetime import datetime, timedelta
from typing import Dict, Any
from collections import deque, defaultdict

import structlog

logger = structlog.get_logger()

class HealthMonitor:
    """Monitors system health and integration performance"""
    
    def __init__(self, incident_manager):
        self.incident_manager = incident_manager
        self.metrics = {
            "alerts_processed": 0,
            "incidents_created": 0,
            "api_errors": defaultdict(int),
            "response_times": defaultdict(deque),
            "webhook_events": 0,
            "system_status": "healthy"
        }
        self.health_checks = {}
        self.monitoring_task = None
        
    async def start_monitoring(self):
        """Start background health monitoring"""
        self.monitoring_task = asyncio.create_task(self._monitor_loop())
        logger.info("Health monitoring started")
    
    async def stop_monitoring(self):
        """Stop health monitoring"""
        if self.monitoring_task:
            self.monitoring_task.cancel()
            try:
                await self.monitoring_task
            except asyncio.CancelledError:
                pass
        logger.info("Health monitoring stopped")
    
    async def _monitor_loop(self):
        """Background monitoring loop"""
        while True:
            try:
                await self._perform_health_checks()
                await asyncio.sleep(60)  # Check every minute
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error("Health monitoring error", error=str(e))
                await asyncio.sleep(60)
    
    async def _perform_health_checks(self):
        """Perform periodic health checks"""
        current_time = datetime.now()
        
        # Check PagerDuty connectivity
        pd_health = await self._check_pagerduty_health()
        self.health_checks["pagerduty"] = {
            "healthy": pd_health,
            "last_check": current_time,
            "response_time_ms": 0  # Would measure actual response time
        }
        
        # Check OpsGenie connectivity  
        og_health = await self._check_opsgenie_health()
        self.health_checks["opsgenie"] = {
            "healthy": og_health,
            "last_check": current_time,
            "response_time_ms": 0
        }
        
        # Update overall system status
        all_healthy = all(check["healthy"] for check in self.health_checks.values())
        self.metrics["system_status"] = "healthy" if all_healthy else "degraded"
        
        logger.debug("Health check completed", 
                    pagerduty=pd_health,
                    opsgenie=og_health)
    
    async def _check_pagerduty_health(self) -> bool:
        """Check PagerDuty API health"""
        try:
            if not self.incident_manager.pagerduty_client:
                return False
            
            start_time = time.time()
            response = await self.incident_manager.pagerduty_client.get("/users", params={"limit": 1})
            response_time = time.time() - start_time
            
            # Track response time
            self.metrics["response_times"]["pagerduty"].append(response_time * 1000)
            # Keep only last 100 measurements
            if len(self.metrics["response_times"]["pagerduty"]) > 100:
                self.metrics["response_times"]["pagerduty"].popleft()
            
            return response.status_code == 200
            
        except Exception as e:
            self.metrics["api_errors"]["pagerduty"] += 1
            logger.debug("PagerDuty health check failed", error=str(e))
            return False
    
    async def _check_opsgenie_health(self) -> bool:
        """Check OpsGenie API health"""
        try:
            if not self.incident_manager.opsgenie_client:
                return False
            
            start_time = time.time()
            response = await self.incident_manager.opsgenie_client.get("/account")
            response_time = time.time() - start_time
            
            # Track response time
            self.metrics["response_times"]["opsgenie"].append(response_time * 1000)
            if len(self.metrics["response_times"]["opsgenie"]) > 100:
                self.metrics["response_times"]["opsgenie"].popleft()
            
            return response.status_code == 200
            
        except Exception as e:
            self.metrics["api_errors"]["opsgenie"] += 1
            logger.debug("OpsGenie health check failed", error=str(e))
            return False
    
    async def get_health_status(self) -> Dict[str, Any]:
        """Get current system health status"""
        return {
            "system_status": self.metrics["system_status"],
            "timestamp": datetime.now().isoformat(),
            "integrations": self.health_checks,
            "active_incidents": len(self.incident_manager.active_incidents),
            "uptime_checks": {
                "pagerduty": self.health_checks.get("pagerduty", {}).get("healthy", False),
                "opsgenie": self.health_checks.get("opsgenie", {}).get("healthy", False)
            }
        }
    
    async def get_metrics(self) -> Dict[str, Any]:
        """Get detailed system metrics"""
        # Calculate average response times
        avg_response_times = {}
        for provider, times in self.metrics["response_times"].items():
            if times:
                avg_response_times[f"{provider}_avg_ms"] = sum(times) / len(times)
            else:
                avg_response_times[f"{provider}_avg_ms"] = 0
        
        return {
            "alerts_processed": self.metrics["alerts_processed"],
            "incidents_created": self.metrics["incidents_created"],
            "webhook_events": self.metrics["webhook_events"],
            "api_errors": dict(self.metrics["api_errors"]),
            "average_response_times": avg_response_times,
            "active_incidents": len(self.incident_manager.active_incidents),
            "system_status": self.metrics["system_status"],
            "timestamp": datetime.now().isoformat()
        }
    
    def record_alert_processed(self):
        """Record alert processing metric"""
        self.metrics["alerts_processed"] += 1
    
    def record_incident_created(self):
        """Record incident creation metric"""
        self.metrics["incidents_created"] += 1
    
    def record_webhook_event(self):
        """Record webhook event metric"""
        self.metrics["webhook_events"] += 1
EOF

# Create React frontend package.json
echo "🌐 Creating React frontend..."
cat > frontend/package.json << 'EOF'
{
  "name": "incident-management-dashboard",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.23.1",
    "axios": "^1.7.0",
    "recharts": "^2.12.7",
    "@mui/material": "^5.15.19",
    "@mui/icons-material": "^5.15.19",
    "@emotion/react": "^11.11.4",
    "@emotion/styled": "^11.11.5",
    "date-fns": "^3.6.0",
    "ws": "^8.17.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "devDependencies": {
    "react-scripts": "^5.0.1",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0"
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
  }
}
EOF

# Create main React App component
mkdir -p frontend/src/components
cat > frontend/src/App.js << 'EOF'
import React, { useState, useEffect } from 'react';
import {
  Container,
  Grid,
  Paper,
  Typography,
  Card,
  CardContent,
  Box,
  Chip,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Alert,
  AlertTitle,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  TextField,
  MenuItem,
  FormControl,
  InputLabel,
  Select
} from '@mui/material';
import { 
  Warning as WarningIcon,
  CheckCircle as CheckIcon,
  Error as ErrorIcon,
  Notifications as NotificationsIcon 
} from '@mui/icons-material';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import axios from 'axios';
import './App.css';

const API_BASE = 'http://localhost:8000/api/v1';

function App() {
  const [healthStatus, setHealthStatus] = useState({});
  const [metrics, setMetrics] = useState({});
  const [incidents, setIncidents] = useState([]);
  const [alertDialogOpen, setAlertDialogOpen] = useState(false);
  const [newAlert, setNewAlert] = useState({
    title: '',
    description: '',
    source: 'application',
    severity: 'medium',
    service_name: '',
    tags: ''
  });

  useEffect(() => {
    fetchHealthStatus();
    fetchMetrics();
    fetchIncidents();
    
    // Refresh data every 30 seconds
    const interval = setInterval(() => {
      fetchHealthStatus();
      fetchMetrics();
      fetchIncidents();
    }, 30000);
    
    return () => clearInterval(interval);
  }, []);

  const fetchHealthStatus = async () => {
    try {
      const response = await axios.get(`${API_BASE}/health`);
      setHealthStatus(response.data);
    } catch (error) {
      console.error('Failed to fetch health status:', error);
    }
  };

  const fetchMetrics = async () => {
    try {
      const response = await axios.get(`${API_BASE}/metrics`);
      setMetrics(response.data);
    } catch (error) {
      console.error('Failed to fetch metrics:', error);
    }
  };

  const fetchIncidents = async () => {
    try {
      const response = await axios.get(`${API_BASE}/incidents`);
      // Combine incidents from all providers
      const allIncidents = [
        ...(response.data.pagerduty || []).map(i => ({...i, provider: 'PagerDuty'})),
        ...(response.data.opsgenie || []).map(i => ({...i, provider: 'OpsGenie'})),
        ...(response.data.local_incidents || []).map(i => ({...i, provider: 'Local'}))
      ];
      setIncidents(allIncidents);
    } catch (error) {
      console.error('Failed to fetch incidents:', error);
    }
  };

  const handleCreateAlert = async () => {
    try {
      const alertData = {
        ...newAlert,
        tags: newAlert.tags.split(',').map(t => t.trim()).filter(t => t),
        timestamp: new Date().toISOString()
      };
      
      await axios.post(`${API_BASE}/alerts`, alertData);
      
      setAlertDialogOpen(false);
      setNewAlert({
        title: '',
        description: '',
        source: 'application',
        severity: 'medium',
        service_name: '',
        tags: ''
      });
      
      // Refresh data
      fetchIncidents();
      fetchMetrics();
    } catch (error) {
      console.error('Failed to create alert:', error);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'healthy': return 'success';
      case 'degraded': return 'warning';
      case 'unhealthy': return 'error';
      default: return 'default';
    }
  };

  const getSeverityColor = (severity) => {
    switch (severity) {
      case 'critical': return '#f44336';
      case 'high': return '#ff9800';
      case 'medium': return '#2196f3';
      case 'low': return '#4caf50';
      default: return '#9e9e9e';
    }
  };

  // Mock chart data
  const chartData = [
    { time: '00:00', alerts: 12, incidents: 2 },
    { time: '04:00', alerts: 8, incidents: 1 },
    { time: '08:00', alerts: 25, incidents: 4 },
    { time: '12:00', alerts: 18, incidents: 3 },
    { time: '16:00', alerts: 32, incidents: 6 },
    { time: '20:00', alerts: 15, incidents: 2 }
  ];

  const severityData = [
    { name: 'Critical', value: 5, color: '#f44336' },
    { name: 'High', value: 12, color: '#ff9800' },
    { name: 'Medium', value: 23, color: '#2196f3' },
    { name: 'Low', value: 15, color: '#4caf50' }
  ];

  return (
    <div className="App">
      <Container maxWidth="xl" sx={{ mt: 4, mb: 4 }}>
        <Typography variant="h3" gutterBottom sx={{ mb: 4, fontWeight: 'bold', color: '#1976d2' }}>
          🚨 Incident Management Dashboard
        </Typography>

        {/* System Health Status */}
        <Grid container spacing={3} sx={{ mb: 4 }}>
          <Grid item xs={12} md={3}>
            <Card sx={{ background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)', color: 'white' }}>
              <CardContent>
                <Box display="flex" alignItems="center">
                  <CheckIcon sx={{ mr: 1 }} />
                  <Typography variant="h6">System Status</Typography>
                </Box>
                <Typography variant="h4" sx={{ mt: 1 }}>
                  {healthStatus.system_status || 'Unknown'}
                </Typography>
                <Chip 
                  label={healthStatus.system_status || 'Unknown'} 
                  color={getStatusColor(healthStatus.system_status)}
                  sx={{ mt: 1 }}
                />
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} md={3}>
            <Card sx={{ background: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)', color: 'white' }}>
              <CardContent>
                <Box display="flex" alignItems="center">
                  <NotificationsIcon sx={{ mr: 1 }} />
                  <Typography variant="h6">Active Incidents</Typography>
                </Box>
                <Typography variant="h4" sx={{ mt: 1 }}>
                  {healthStatus.active_incidents || 0}
                </Typography>
                <Typography variant="body2" sx={{ mt: 1 }}>
                  Across all providers
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} md={3}>
            <Card sx={{ background: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)', color: 'white' }}>
              <CardContent>
                <Box display="flex" alignItems="center">
                  <WarningIcon sx={{ mr: 1 }} />
                  <Typography variant="h6">Alerts Processed</Typography>
                </Box>
                <Typography variant="h4" sx={{ mt: 1 }}>
                  {metrics.alerts_processed || 0}
                </Typography>
                <Typography variant="body2" sx={{ mt: 1 }}>
                  Total processed today
                </Typography>
              </CardContent>
            </Card>
          </Grid>

          <Grid item xs={12} md={3}>
            <Card sx={{ background: 'linear-gradient(135deg, #fa709a 0%, #fee140 100%)', color: 'white' }}>
              <CardContent>
                <Box display="flex" alignItems="center">
                  <ErrorIcon sx={{ mr: 1 }} />
                  <Typography variant="h6">API Errors</Typography>
                </Box>
                <Typography variant="h4" sx={{ mt: 1 }}>
                  {Object.values(metrics.api_errors || {}).reduce((a, b) => a + b, 0)}
                </Typography>
                <Typography variant="body2" sx={{ mt: 1 }}>
                  Across all providers
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* Integration Health */}
        <Grid container spacing={3} sx={{ mb: 4 }}>
          <Grid item xs={12} md={6}>
            <Paper sx={{ p: 3, borderRadius: 2, boxShadow: 3 }}>
              <Typography variant="h6" gutterBottom>Integration Health</Typography>
              <Box sx={{ mt: 2 }}>
                <Box display="flex" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
                  <Typography variant="body1">PagerDuty</Typography>
                  <Chip 
                    label={healthStatus.uptime_checks?.pagerduty ? 'Healthy' : 'Down'} 
                    color={healthStatus.uptime_checks?.pagerduty ? 'success' : 'error'}
                  />
                </Box>
                <Box display="flex" justifyContent="space-between" alignItems="center">
                  <Typography variant="body1">OpsGenie</Typography>
                  <Chip 
                    label={healthStatus.uptime_checks?.opsgenie ? 'Healthy' : 'Down'} 
                    color={healthStatus.uptime_checks?.opsgenie ? 'success' : 'error'}
                  />
                </Box>
              </Box>
            </Paper>
          </Grid>

          <Grid item xs={12} md={6}>
            <Paper sx={{ p: 3, borderRadius: 2, boxShadow: 3 }}>
              <Typography variant="h6" gutterBottom>Response Times</Typography>
              <Box sx={{ mt: 2 }}>
                <Typography variant="body2" color="textSecondary">
                  PagerDuty: {metrics.average_response_times?.pagerduty_avg_ms?.toFixed(1) || 0}ms
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  OpsGenie: {metrics.average_response_times?.opsgenie_avg_ms?.toFixed(1) || 0}ms
                </Typography>
              </Box>
            </Paper>
          </Grid>
        </Grid>

        {/* Charts */}
        <Grid container spacing={3} sx={{ mb: 4 }}>
          <Grid item xs={12} md={8}>
            <Paper sx={{ p: 3, borderRadius: 2, boxShadow: 3 }}>
              <Typography variant="h6" gutterBottom>Alert & Incident Trends</Typography>
              <ResponsiveContainer width="100%" height={300}>
                <LineChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="time" />
                  <YAxis />
                  <Tooltip />
                  <Line type="monotone" dataKey="alerts" stroke="#2196f3" strokeWidth={2} />
                  <Line type="monotone" dataKey="incidents" stroke="#f44336" strokeWidth={2} />
                </LineChart>
              </ResponsiveContainer>
            </Paper>
          </Grid>

          <Grid item xs={12} md={4}>
            <Paper sx={{ p: 3, borderRadius: 2, boxShadow: 3 }}>
              <Typography variant="h6" gutterBottom>Alert Severity Distribution</Typography>
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={severityData}
                    cx="50%"
                    cy="50%"
                    outerRadius={80}
                    dataKey="value"
                    label
                  >
                    {severityData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </Paper>
          </Grid>
        </Grid>

        {/* Create Alert Button */}
        <Box sx={{ mb: 4, textAlign: 'center' }}>
          <Button 
            variant="contained" 
            color="primary" 
            size="large"
            onClick={() => setAlertDialogOpen(true)}
            sx={{ borderRadius: 3, px: 4 }}
          >
            🚨 Create Test Alert
          </Button>
        </Box>

        {/* Recent Incidents Table */}
        <Paper sx={{ p: 3, borderRadius: 2, boxShadow: 3 }}>
          <Typography variant="h6" gutterBottom>Recent Incidents</Typography>
          <TableContainer>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell><strong>Provider</strong></TableCell>
                  <TableCell><strong>Title</strong></TableCell>
                  <TableCell><strong>Status</strong></TableCell>
                  <TableCell><strong>Created</strong></TableCell>
                  <TableCell><strong>Service</strong></TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {incidents.slice(0, 10).map((incident, index) => (
                  <TableRow key={index}>
                    <TableCell>
                      <Chip 
                        label={incident.provider} 
                        size="small"
                        color={incident.provider === 'PagerDuty' ? 'primary' : 'secondary'}
                      />
                    </TableCell>
                    <TableCell>{incident.title || incident.message || 'N/A'}</TableCell>
                    <TableCell>
                      <Chip 
                        label={incident.status || 'unknown'} 
                        size="small"
                        color={incident.status === 'resolved' ? 'success' : 'warning'}
                      />
                    </TableCell>
                    <TableCell>{incident.created_at || incident.createdAt || 'N/A'}</TableCell>
                    <TableCell>{incident.service?.summary || incident.entity || 'N/A'}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </Paper>

        {/* Create Alert Dialog */}
        <Dialog open={alertDialogOpen} onClose={() => setAlertDialogOpen(false)} maxWidth="md" fullWidth>
          <DialogTitle>Create Test Alert</DialogTitle>
          <DialogContent>
            <Grid container spacing={2} sx={{ mt: 1 }}>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Alert Title"
                  value={newAlert.title}
                  onChange={(e) => setNewAlert({...newAlert, title: e.target.value})}
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  multiline
                  rows={3}
                  label="Description"
                  value={newAlert.description}
                  onChange={(e) => setNewAlert({...newAlert, description: e.target.value})}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <FormControl fullWidth>
                  <InputLabel>Source</InputLabel>
                  <Select
                    value={newAlert.source}
                    onChange={(e) => setNewAlert({...newAlert, source: e.target.value})}
                  >
                    <MenuItem value="database">Database</MenuItem>
                    <MenuItem value="api">API</MenuItem>
                    <MenuItem value="security">Security</MenuItem>
                    <MenuItem value="infrastructure">Infrastructure</MenuItem>
                    <MenuItem value="application">Application</MenuItem>
                  </Select>
                </FormControl>
              </Grid>
              <Grid item xs={12} md={6}>
                <FormControl fullWidth>
                  <InputLabel>Severity</InputLabel>
                  <Select
                    value={newAlert.severity}
                    onChange={(e) => setNewAlert({...newAlert, severity: e.target.value})}
                  >
                    <MenuItem value="critical">Critical</MenuItem>
                    <MenuItem value="high">High</MenuItem>
                    <MenuItem value="medium">Medium</MenuItem>
                    <MenuItem value="low">Low</MenuItem>
                    <MenuItem value="info">Info</MenuItem>
                  </Select>
                </FormControl>
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Service Name"
                  value={newAlert.service_name}
                  onChange={(e) => setNewAlert({...newAlert, service_name: e.target.value})}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Tags (comma separated)"
                  value={newAlert.tags}
                  onChange={(e) => setNewAlert({...newAlert, tags: e.target.value})}
                />
              </Grid>
              <Grid item xs={12} sx={{ mt: 2 }}>
                <Button 
                  variant="contained" 
                  color="primary" 
                  onClick={handleCreateAlert}
                  fullWidth
                  size="large"
                >
                  Create Alert
                </Button>
              </Grid>
            </Grid>
          </DialogContent>
        </Dialog>
      </Container>
    </div>
  );
}

export default App;
EOF

# Create CSS styles for the React app
cat > frontend/src/App.css << 'EOF'
.App {
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  background-attachment: fixed;
}

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

.MuiPaper-root {
  background: rgba(255, 255, 255, 0.95) !important;
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.MuiCard-root {
  border-radius: 16px !important;
  box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37) !important;
}

.MuiButton-contained {
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2) !important;
  transition: all 0.3s ease !important;
}

.MuiButton-contained:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3) !important;
}

.MuiTableContainer-root {
  border-radius: 12px;
}

.MuiTableHead-root {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.MuiTableHead-root .MuiTableCell-root {
  color: white !important;
  font-weight: bold !important;
}

.recharts-wrapper {
  border-radius: 12px;
}
EOF

# Create React index files
cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';

const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
    background: {
      default: '#f5f5f5',
    },
  },
  typography: {
    fontFamily: '"Roboto", "Helvetica", "Arial", sans-serif',
    h3: {
      fontWeight: 700,
    },
    h6: {
      fontWeight: 600,
    },
  },
  components: {
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 16,
          boxShadow: '0 8px 32px rgba(31, 38, 135, 0.37)',
        },
      },
    },
  },
});

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <App />
    </ThemeProvider>
  </React.StrictMode>
);
EOF

cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Incident Management Dashboard" />
    <title>Incident Management Dashboard</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap" rel="stylesheet">
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

# Create comprehensive test suite
echo "🧪 Creating test files..."

# Unit tests
cat > tests/unit/test_alert_router.py << 'EOF'
import pytest
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

from src.core.alert_router import AlertRouter, AlertData, AlertSeverity, AlertSource

@pytest.fixture
async def alert_router():
    incident_manager = AsyncMock()
    router = AlertRouter(incident_manager)
    await router.load_escalation_policies()
    return router

@pytest.mark.asyncio
async def test_alert_classification(alert_router):
    """Test alert classification logic"""
    alert_data = {
        "id": "test_alert_001",
        "title": "Database Connection Failed",
        "description": "Unable to connect to primary database",
        "source": "database",
        "severity": "critical",
        "service_name": "payment-service",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    
    result = await alert_router.process_alert(alert_data)
    
    assert result["success"] is True
    assert result["alert_id"] == "test_alert_001"
    assert result["processing_time_ms"] > 0

@pytest.mark.asyncio
async def test_routing_policy_selection(alert_router):
    """Test routing policy selection based on alert characteristics"""
    # Critical database alert should use critical_24x7 policy
    alert = AlertData(
        id="test_001",
        title="Test",
        description="Test",
        source=AlertSource.DATABASE,
        severity=AlertSeverity.CRITICAL,
        timestamp=datetime.now(timezone.utc),
        metadata={},
        tags=[],
        service_name="test-service"
    )
    
    policy = alert_router._get_routing_policy(alert)
    assert policy == "critical_24x7"

@pytest.mark.asyncio
async def test_service_catalog_enhancement(alert_router):
    """Test service catalog-based alert enhancement"""
    alert = AlertData(
        id="test_001",
        title="Test Alert",
        description="Test",
        source=AlertSource.APPLICATION,
        severity=AlertSeverity.MEDIUM,
        timestamp=datetime.now(timezone.utc),
        metadata={},
        tags=[],
        service_name="payment-service",  # Critical service in catalog
        team=None
    )
    
    enhanced_alert = await alert_router._classify_alert(alert)
    
    # Should be upgraded to HIGH severity due to critical service
    assert enhanced_alert.severity == AlertSeverity.HIGH
    assert enhanced_alert.team == "payments"
    assert "service-critical" in enhanced_alert.tags
EOF

cat > tests/unit/test_incident_manager.py << 'EOF'
import pytest
from unittest.mock import AsyncMock, MagicMock
import httpx

from src.integrations.incident_manager import IncidentManager
from src.core.alert_router import AlertData, AlertSeverity, AlertSource

@pytest.fixture
async def incident_manager():
    manager = IncidentManager("test_pd_key", "test_og_key")
    # Mock HTTP clients
    manager.pagerduty_client = AsyncMock()
    manager.opsgenie_client = AsyncMock()
    return manager

@pytest.mark.asyncio
async def test_pagerduty_incident_creation(incident_manager):
    """Test PagerDuty incident creation"""
    # Mock successful API response
    mock_response = MagicMock()
    mock_response.json.return_value = {"incident": {"id": "INCIDENT123"}}
    incident_manager.pagerduty_client.post.return_value = mock_response
    
    alert_data = AlertData(
        id="test_001",
        title="Test Critical Alert",
        description="Test description",
        source=AlertSource.DATABASE,
        severity=AlertSeverity.CRITICAL,
        timestamp=datetime.now(timezone.utc),
        metadata={},
        tags=["test"],
        service_name="test-service"
    )
    
    incident_id = await incident_manager.create_pagerduty_incident(alert_data, {})
    
    assert incident_id == "INCIDENT123"
    assert incident_id in incident_manager.active_incidents
    assert incident_manager.active_incidents[incident_id]["provider"] == "pagerduty"

@pytest.mark.asyncio
async def test_opsgenie_alert_creation(incident_manager):
    """Test OpsGenie alert creation"""
    # Mock successful API response
    mock_response = MagicMock()
    mock_response.json.return_value = {"requestId": "ALERT456"}
    incident_manager.opsgenie_client.post.return_value = mock_response
    
    alert_data = AlertData(
        id="test_002",
        title="Test High Alert",
        description="Test description",
        source=AlertSource.API,
        severity=AlertSeverity.HIGH,
        timestamp=datetime.now(timezone.utc),
        metadata={},
        tags=["api", "high"],
        service_name="api-gateway"
    )
    
    alert_id = await incident_manager.create_opsgenie_incident(alert_data, {})
    
    assert alert_id == "ALERT456"
    assert alert_id in incident_manager.active_incidents
    assert incident_manager.active_incidents[alert_id]["provider"] == "opsgenie"

@pytest.mark.asyncio
async def test_api_error_handling(incident_manager):
    """Test API error handling"""
    # Mock HTTP error
    incident_manager.pagerduty_client.post.side_effect = httpx.HTTPStatusError(
        "API Error", request=MagicMock(), response=MagicMock()
    )
    
    alert_data = AlertData(
        id="test_003",
        title="Test Alert",
        description="Test",
        source=AlertSource.APPLICATION,
        severity=AlertSeverity.MEDIUM,
        timestamp=datetime.now(timezone.utc),
        metadata={},
        tags=[],
        service_name="test-service"
    )
    
    with pytest.raises(Exception):
        await incident_manager.create_pagerduty_incident(alert_data, {})
EOF

# Integration tests
cat > tests/integration/test_full_workflow.py << 'EOF'
import pytest
import asyncio
from datetime import datetime, timezone

from src.core.alert_router import AlertRouter
from src.integrations.incident_manager import IncidentManager
from src.monitoring.health_monitor import HealthMonitor

@pytest.mark.asyncio
async def test_end_to_end_alert_processing():
    """Test complete alert processing workflow"""
    # Initialize components
    incident_manager = IncidentManager("test_key", "test_key")
    alert_router = AlertRouter(incident_manager)
    health_monitor = HealthMonitor(incident_manager)
    
    await alert_router.load_escalation_policies()
    
    # Test alert data
    alert_data = {
        "id": "integration_test_001",
        "title": "Integration Test Critical Alert",
        "description": "Testing end-to-end alert processing",
        "source": "database",
        "severity": "critical",
        "service_name": "payment-service",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "metadata": {"test": "integration"},
        "tags": ["integration", "test"]
    }
    
    # Process the alert
    result = await alert_router.process_alert(alert_data)
    
    # Verify processing results
    assert result is not None
    assert "alert_id" in result
    assert "processing_time_ms" in result
    assert "routing_results" in result
    
    # Verify health monitoring
    health_status = await health_monitor.get_health_status()
    assert health_status is not None
    assert "system_status" in health_status

@pytest.mark.asyncio
async def test_concurrent_alert_processing():
    """Test processing multiple alerts concurrently"""
    incident_manager = IncidentManager("test_key", "test_key")
    alert_router = AlertRouter(incident_manager)
    
    await alert_router.load_escalation_policies()
    
    # Create multiple alerts
    alerts = []
    for i in range(10):
        alert_data = {
            "id": f"concurrent_test_{i:03d}",
            "title": f"Concurrent Test Alert {i}",
            "description": f"Testing concurrent processing - alert {i}",
            "source": "application",
            "severity": "medium",
            "service_name": f"service-{i}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        alerts.append(alert_data)
    
    # Process alerts concurrently
    tasks = [alert_router.process_alert(alert) for alert in alerts]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    # Verify all alerts were processed successfully
    successful_results = [r for r in results if not isinstance(r, Exception)]
    assert len(successful_results) == 10
    
    for result in successful_results:
        assert result.get("success") is not False  # Could be True or None for demo mode

@pytest.mark.asyncio
async def test_webhook_processing():
    """Test webhook event processing"""
    incident_manager = IncidentManager("test_key", "test_key")
    alert_router = AlertRouter(incident_manager)
    
    from src.webhooks.webhook_handler import WebhookHandler
    webhook_handler = WebhookHandler(incident_manager, alert_router)
    
    # Test PagerDuty webhook payload
    pd_payload = {
        "messages": [{
            "event": "incident.acknowledged",
            "incident": {
                "id": "INCIDENT123",
                "status": "acknowledged",
                "acknowledged_by": {"summary": "Test User"}
            }
        }]
    }
    
    import json
    result = await webhook_handler.handle_pagerduty_webhook(
        json.dumps(pd_payload).encode(),
        {}
    )
    
    assert result["status"] == "success"
    assert result["processed_events"] == 1
EOF

# Load tests  
cat > tests/load/test_performance.py << 'EOF'
import pytest
import asyncio
import time
from datetime import datetime, timezone

from src.core.alert_router import AlertRouter
from src.integrations.incident_manager import IncidentManager

@pytest.mark.asyncio
async def test_high_volume_alert_processing():
    """Test system performance under high alert volume"""
    incident_manager = IncidentManager("test_key", "test_key")
    alert_router = AlertRouter(incident_manager)
    
    await alert_router.load_escalation_policies()
    
    # Generate high volume of alerts
    num_alerts = 100
    alerts = []
    
    for i in range(num_alerts):
        alert_data = {
            "id": f"load_test_{i:04d}",
            "title": f"Load Test Alert {i}",
            "description": f"High volume load test - alert {i}",
            "source": "application",
            "severity": "medium",
            "service_name": f"load-test-service-{i % 5}",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "metadata": {"load_test": True, "batch": i // 10}
        }
        alerts.append(alert_data)
    
    # Process alerts with timing
    start_time = time.time()
    
    # Process in batches to avoid overwhelming the system
    batch_size = 10
    for i in range(0, num_alerts, batch_size):
        batch = alerts[i:i+batch_size]
        tasks = [alert_router.process_alert(alert) for alert in batch]
        await asyncio.gather(*tasks, return_exceptions=True)
        
        # Small delay between batches
        await asyncio.sleep(0.1)
    
    end_time = time.time()
    processing_time = end_time - start_time
    
    # Performance assertions
    alerts_per_second = num_alerts / processing_time
    
    print(f"Processed {num_alerts} alerts in {processing_time:.2f} seconds")
    print(f"Throughput: {alerts_per_second:.2f} alerts/second")
    
    # Should handle at least 10 alerts per second
    assert alerts_per_second > 10, f"Performance too low: {alerts_per_second:.2f} alerts/second"

@pytest.mark.asyncio
async def test_memory_usage_stability():
    """Test memory usage remains stable under sustained load"""
    import psutil
    import os
    
    process = psutil.Process(os.getpid())
    initial_memory = process.memory_info().rss / 1024 / 1024  # MB
    
    incident_manager = IncidentManager("test_key", "test_key")
    alert_router = AlertRouter(incident_manager)
    
    await alert_router.load_escalation_policies()
    
    # Process alerts continuously for a period
    num_iterations = 50
    
    for iteration in range(num_iterations):
        alert_data = {
            "id": f"memory_test_{iteration}",
            "title": f"Memory Test Alert {iteration}",
            "description": "Memory usage stability test",
            "source": "application",
            "severity": "low",
            "service_name": "memory-test-service",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        await alert_router.process_alert(alert_data)
        
        # Check memory every 10 iterations
        if iteration % 10 == 0:
            current_memory = process.memory_info().rss / 1024 / 1024  # MB
            memory_increase = current_memory - initial_memory
            print(f"Iteration {iteration}: Memory usage: {current_memory:.1f} MB (+{memory_increase:.1f} MB)")
            
            # Memory should not increase by more than 50MB
            assert memory_increase < 50, f"Memory leak detected: {memory_increase:.1f} MB increase"
EOF

# Create configuration files
cat > config/.env.example << 'EOF'
# PagerDuty Configuration
PAGERDUTY_API_KEY=your_pagerduty_api_key_here
PAGERDUTY_WEBHOOK_SECRET=your_webhook_secret_here

# OpsGenie Configuration  
OPSGENIE_API_KEY=your_opsgenie_api_key_here
OPSGENIE_WEBHOOK_SECRET=your_webhook_secret_here

# Database
DATABASE_URL=sqlite:///./incidents.db
REDIS_URL=redis://localhost:6379

# Feature Flags
ENABLE_PAGERDUTY=true
ENABLE_OPSGENIE=true
ENABLE_WEBHOOK_VALIDATION=false
EOF

# Copy example to actual .env for demo
cp config/.env.example .env

# Create escalation policies configuration
cat > config/escalation_policies.yaml << 'EOF'
escalation_policies:
  critical_24x7:
    provider: pagerduty
    escalation_timeout_minutes: 5
    teams:
      - oncall-primary
      - oncall-secondary
    conditions:
      - severity: critical
      - source: database
      - after_hours: true
  
  business_hours:
    provider: opsgenie
    escalation_timeout_minutes: 15
    teams:
      - support-team
    conditions:
      - severity: [medium, low]
      - business_hours: true
  
  security_alerts:
    provider: both
    escalation_timeout_minutes: 2
    teams:
      - security-team
      - oncall-primary
    conditions:
      - source: security
      - severity: any

service_catalog:
  payment-service:
    team: payments
    criticality: critical
    escalation_policy: critical_24x7
  
  user-service:
    team: identity
    criticality: high
    escalation_policy: critical_24x7
  
  recommendation-service:
    team: ml
    criticality: medium
    escalation_policy: business_hours
EOF

# Docker configuration
cat > docker/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY config/ ./config/
COPY .env ./

# Copy frontend build
COPY frontend/build ./frontend/build/

EXPOSE 8000

CMD ["python", "-m", "src.main"]
EOF

cat > .dockerignore << 'EOF'
.git
.gitignore
README.md
venv/
node_modules/
frontend/src/
frontend/public/
tests/
logs/
*.log
__pycache__/
*.pyc
.env.example
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  incident-management:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "8000:8000"
    depends_on:
      - redis
    environment:
      - REDIS_URL=redis://redis:6379
      - DATABASE_URL=sqlite:///./incidents.db
      - PAGERDUTY_API_KEY=demo_pagerduty_key
      - OPSGENIE_API_KEY=demo_opsgenie_key
      - ENABLE_WEBHOOK_VALIDATION=false
    volumes:
      - ./logs:/app/logs
      - incident_data:/app/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  redis_data:
  incident_data:
EOF

# Build scripts
echo "🔨 Creating build scripts..."

cat > build.sh << 'EOF'
#!/bin/bash

echo "🚀 Building Day 137: PagerDuty/OpsGenie Integration System"
echo "========================================================="

# Activate virtual environment
source venv/bin/activate

echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

echo "🌐 Building React frontend..."
cd frontend
npm install
npm run build
cd ..

echo "🧪 Running tests..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
python -m pytest tests/ -v --tb=short

echo "✅ Build completed successfully!"
echo ""
echo "Next steps:"
echo "  ./start.sh    - Start the application"
echo "  ./stop.sh     - Stop the application"
echo "  ./test.sh     - Run comprehensive tests"
EOF

cat > start.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Incident Management System..."

# Start with Docker Compose
if command -v docker-compose &> /dev/null; then
    echo "Starting services with Docker Compose..."
    docker-compose up -d
    
    echo "⏳ Waiting for services to start..."
    sleep 10
    
    echo "✅ Services started successfully!"
    echo ""
    echo "🌐 Dashboard: http://localhost:8000"
    echo "📊 Health Check: http://localhost:8000/api/v1/health"
    echo "📋 Metrics: http://localhost:8000/api/v1/metrics"
    echo ""
    echo "View logs with: docker-compose logs -f incident-management"
else
    echo "Starting services locally..."
    
    # Start Redis in background
    redis-server --daemonize yes
    
    # Activate virtual environment and start FastAPI
    source venv/bin/activate
    export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
    uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload &
    
    echo "⏳ Waiting for services to start..."
    sleep 5
    
    echo "✅ Services started successfully!"
    echo ""
    echo "🌐 Dashboard: http://localhost:8000"
    echo ""
    echo "Stop with: ./stop.sh"
fi
EOF

cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Incident Management System..."

if command -v docker-compose &> /dev/null; then
    docker-compose down
    echo "✅ Docker services stopped"
else
    # Kill uvicorn process
    pkill -f "uvicorn src.main:app"
    
    # Stop Redis
    redis-cli shutdown
    
    echo "✅ Local services stopped"
fi
EOF

cat > test.sh << 'EOF'
#!/bin/bash

echo "🧪 Running Comprehensive Test Suite"
echo "===================================="

source venv/bin/activate
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

echo "1️⃣  Running unit tests..."
python -m pytest tests/unit/ -v

echo ""
echo "2️⃣  Running integration tests..."
python -m pytest tests/integration/ -v

echo ""
echo "3️⃣  Running load tests..."
python -m pytest tests/load/ -v

echo ""
echo "4️⃣  Testing API endpoints..."
if curl -s http://localhost:8000/api/v1/health > /dev/null 2>&1; then
    echo "✅ Health endpoint working"
    curl -s http://localhost:8000/api/v1/health | python -m json.tool
else
    echo "❌ Health endpoint not accessible"
fi

echo ""
echo "5️⃣  Testing alert creation..."
curl -X POST http://localhost:8000/api/v1/alerts \
    -H "Content-Type: application/json" \
    -d '{
        "title": "Test Alert from Script",
        "description": "Automated test alert",
        "source": "application",
        "severity": "medium", 
        "service_name": "test-service",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%fZ)'"
    }' | python -m json.tool

echo ""
echo "✅ All tests completed!"
EOF

# Make scripts executable
chmod +x build.sh start.sh stop.sh test.sh

echo "📁 Verifying project structure..."
find . -name "*.py" | head -10
echo ""

echo "🔍 Verifying Python syntax..."
python -m py_compile src/main.py
python -m py_compile src/core/alert_router.py
python -m py_compile src/integrations/incident_manager.py
echo "✅ Python syntax validation passed"

echo "📦 Installing Node.js dependencies..."
cd frontend
npm install --silent
cd ..

echo "🌐 Building React frontend..."
cd frontend
npm run build
cd ..

echo "🧪 Running initial tests..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
python -m pytest tests/unit/test_alert_router.py::test_routing_policy_selection -v

echo ""
echo "🎉 Implementation completed successfully!"
echo "========================================"
echo ""
echo "📁 Project Structure:"
echo "├── src/                     # Python backend source code"
echo "├── frontend/                # React dashboard"
echo "├── tests/                   # Comprehensive test suite"  
echo "├── config/                  # Configuration files"
echo "├── docker/                  # Container configuration"
echo "└── scripts/                 # Build and utility scripts"
echo ""
echo "🚀 Quick Start Commands:"
echo "  ./build.sh                 # Build everything"
echo "  ./start.sh                 # Start services"  
echo "  ./stop.sh                  # Stop services"
echo "  ./test.sh                  # Run all tests"
echo ""