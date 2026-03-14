#!/bin/bash

# Day 135: Slack Notification Integration - Complete Implementation
# Module 5: Integration and Ecosystem | Week 20: External System Integration

set -e

echo "🚀 Day 135: Building Slack Notification Integration for Log Processing System"
echo "=================================================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p day135-slack-integration/{src/{backend/{services,models,utils,config},frontend/{components,pages,hooks,utils}},tests/{unit,integration},config,scripts,docker,docs,public}

cd day135-slack-integration

# Create requirements.txt with latest May 2025 libraries
cat > requirements.txt << 'EOF'
fastapi==0.110.2
uvicorn==0.29.0
slack-sdk==3.27.1
redis==5.0.4
pydantic==2.7.1
asyncio-mqtt==0.16.1
aiohttp==3.9.5
pytest==8.2.0
pytest-asyncio==0.23.6
python-dotenv==1.0.1
schedule==1.2.1
tenacity==8.3.0
structlog==24.1.0
prometheus-client==0.20.0
websockets==12.0
cryptography==42.0.5
EOF

# Create package.json for React frontend
cat > package.json << 'EOF'
{
  "name": "slack-integration-dashboard",
  "version": "1.0.0",
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-scripts": "5.0.1",
    "axios": "^1.6.8",
    "socket.io-client": "^4.7.5",
    "react-router-dom": "^6.23.0",
    "@mui/material": "^5.15.15",
    "@mui/icons-material": "^5.15.15",
    "@emotion/react": "^11.11.4",
    "@emotion/styled": "^11.11.5",
    "recharts": "^2.12.2",
    "date-fns": "^3.6.0"
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

# Create environment configuration
cat > .env << 'EOF'
# Slack Configuration
SLACK_BOT_TOKEN=xoxb-your-bot-token-here
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
SLACK_APP_TOKEN=xapp-your-app-token-here

# Redis Configuration
REDIS_URL=redis://localhost:6379/0

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
DEBUG=True

# Alert Configuration
MAX_ALERTS_PER_MINUTE=60
DEDUPLICATION_WINDOW_MINUTES=5
DEFAULT_CHANNEL=#alerts
CRITICAL_CHANNEL=#critical-alerts
EOF

# Create main configuration
cat > src/backend/config/config.py << 'EOF'
from pydantic import BaseSettings
from typing import Dict, List
import os

class Settings(BaseSettings):
    # Slack Configuration
    slack_bot_token: str = os.getenv("SLACK_BOT_TOKEN", "")
    slack_webhook_url: str = os.getenv("SLACK_WEBHOOK_URL", "")
    slack_app_token: str = os.getenv("SLACK_APP_TOKEN", "")
    
    # Redis Configuration
    redis_url: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    
    # API Configuration
    api_host: str = os.getenv("API_HOST", "0.0.0.0")
    api_port: int = int(os.getenv("API_PORT", "8000"))
    debug: bool = os.getenv("DEBUG", "True").lower() == "true"
    
    # Alert Configuration
    max_alerts_per_minute: int = int(os.getenv("MAX_ALERTS_PER_MINUTE", "60"))
    deduplication_window_minutes: int = int(os.getenv("DEDUPLICATION_WINDOW_MINUTES", "5"))
    default_channel: str = os.getenv("DEFAULT_CHANNEL", "#alerts")
    critical_channel: str = os.getenv("CRITICAL_CHANNEL", "#critical-alerts")
    
    # Channel Routing Configuration
    channel_routing: Dict[str, str] = {
        "payment": "#payments-team",
        "database": "#database-team", 
        "api": "#backend-team",
        "frontend": "#frontend-team",
        "security": "#security-team"
    }
    
    # Severity Levels
    severity_channels: Dict[str, List[str]] = {
        "critical": ["#critical-alerts", "#on-call"],
        "error": ["#alerts"],
        "warning": ["#monitoring"],
        "info": ["#notifications"]
    }

    class Config:
        env_file = ".env"

settings = Settings()
EOF

# Create alert models
cat > src/backend/models/alert.py << 'EOF'
from pydantic import BaseModel
from typing import Dict, List, Optional, Any
from datetime import datetime
from enum import Enum

class AlertSeverity(str, Enum):
    CRITICAL = "critical"
    ERROR = "error"
    WARNING = "warning"
    INFO = "info"

class AlertStatus(str, Enum):
    PENDING = "pending"
    SENT = "sent"
    ACKNOWLEDGED = "acknowledged"
    RESOLVED = "resolved"
    FAILED = "failed"

class LogAlert(BaseModel):
    id: str
    title: str
    message: str
    severity: AlertSeverity
    service: str
    component: str
    timestamp: datetime
    metadata: Dict[str, Any]
    affected_users: Optional[int] = None
    runbook_url: Optional[str] = None
    dashboard_url: Optional[str] = None
    raw_logs: List[str] = []

class SlackMessage(BaseModel):
    channel: str
    text: str
    blocks: List[Dict[str, Any]] = []
    thread_ts: Optional[str] = None
    attachments: List[Dict[str, Any]] = []

class NotificationStatus(BaseModel):
    alert_id: str
    status: AlertStatus
    channel: str
    message_ts: Optional[str] = None
    sent_at: Optional[datetime] = None
    acknowledged_at: Optional[datetime] = None
    acknowledged_by: Optional[str] = None
    error_message: Optional[str] = None
EOF

# Create Slack service
cat > src/backend/services/slack_service.py << 'EOF'
import asyncio
import json
import hashlib
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from slack_sdk.web.async_client import AsyncWebClient
from slack_sdk.errors import SlackApiError
import redis
import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

from ..models.alert import LogAlert, SlackMessage, NotificationStatus, AlertStatus, AlertSeverity
from ..config.config import settings

logger = structlog.get_logger(__name__)

class SlackService:
    def __init__(self):
        self.client = AsyncWebClient(token=settings.slack_bot_token)
        self.redis_client = redis.from_url(settings.redis_url)
        self.rate_limiter = RateLimiter(settings.max_alerts_per_minute)
        self.deduplicator = AlertDeduplicator(settings.deduplication_window_minutes)
        
    async def send_alert(self, alert: LogAlert) -> NotificationStatus:
        """Send alert to appropriate Slack channel(s)"""
        try:
            # Check deduplication
            if self.deduplicator.is_duplicate(alert):
                logger.info("Skipping duplicate alert", alert_id=alert.id)
                return NotificationStatus(
                    alert_id=alert.id,
                    status=AlertStatus.PENDING,
                    channel="duplicate"
                )
            
            # Rate limiting
            if not await self.rate_limiter.allow_request():
                logger.warning("Rate limit exceeded, queuing alert", alert_id=alert.id)
                await self._queue_alert(alert)
                return NotificationStatus(
                    alert_id=alert.id,
                    status=AlertStatus.PENDING,
                    channel="queued"
                )
            
            # Determine target channels
            channels = self._resolve_channels(alert)
            
            # Format message
            slack_message = self._format_alert_message(alert)
            
            # Send to channels
            notification_statuses = []
            for channel in channels:
                status = await self._send_to_channel(alert, slack_message, channel)
                notification_statuses.append(status)
            
            # Store notification record
            await self._store_notification(alert, notification_statuses)
            
            return notification_statuses[0] if notification_statuses else NotificationStatus(
                alert_id=alert.id,
                status=AlertStatus.FAILED,
                channel="none"
            )
            
        except Exception as e:
            logger.error("Failed to send alert", alert_id=alert.id, error=str(e))
            return NotificationStatus(
                alert_id=alert.id,
                status=AlertStatus.FAILED,
                channel="error",
                error_message=str(e)
            )
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10)
    )
    async def _send_to_channel(self, alert: LogAlert, message: SlackMessage, channel: str) -> NotificationStatus:
        """Send message to specific Slack channel with retry logic"""
        try:
            response = await self.client.chat_postMessage(
                channel=channel,
                text=message.text,
                blocks=message.blocks,
                attachments=message.attachments
            )
            
            return NotificationStatus(
                alert_id=alert.id,
                status=AlertStatus.SENT,
                channel=channel,
                message_ts=response["ts"],
                sent_at=datetime.now()
            )
            
        except SlackApiError as e:
            if e.response["error"] == "channel_not_found":
                logger.warning("Channel not found, using default", channel=channel)
                return await self._send_to_channel(alert, message, settings.default_channel)
            raise
    
    def _resolve_channels(self, alert: LogAlert) -> List[str]:
        """Determine which channels should receive this alert"""
        channels = []
        
        # Service-based routing
        service_channel = settings.channel_routing.get(alert.service)
        if service_channel:
            channels.append(service_channel)
        
        # Severity-based routing
        severity_channels = settings.severity_channels.get(alert.severity.value, [])
        channels.extend(severity_channels)
        
        # Default channel if no specific routing
        if not channels:
            channels.append(settings.default_channel)
        
        return list(set(channels))  # Remove duplicates
    
    def _format_alert_message(self, alert: LogAlert) -> SlackMessage:
        """Format alert as Slack message with blocks and interactions"""
        
        # Determine color based on severity
        color_map = {
            AlertSeverity.CRITICAL: "#ff0000",
            AlertSeverity.ERROR: "#ff9900", 
            AlertSeverity.WARNING: "#ffcc00",
            AlertSeverity.INFO: "#36a64f"
        }
        
        # Create rich message blocks
        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"🚨 {alert.severity.value.upper()}: {alert.title}"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": alert.message
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*Service:*\n{alert.service}"
                    },
                    {
                        "type": "mrkdwn", 
                        "text": f"*Component:*\n{alert.component}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Time:*\n{alert.timestamp.strftime('%Y-%m-%d %H:%M:%S UTC')}"
                    }
                ]
            }
        ]
        
        # Add affected users if available
        if alert.affected_users:
            blocks.append({
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"👥 *Affected Users:* {alert.affected_users:,}"
                }
            })
        
        # Add action buttons
        actions = {
            "type": "actions",
            "elements": [
                {
                    "type": "button",
                    "text": {
                        "type": "plain_text",
                        "text": "Acknowledge"
                    },
                    "style": "primary",
                    "action_id": f"ack_{alert.id}",
                    "value": alert.id
                }
            ]
        }
        
        # Add links if available
        if alert.dashboard_url or alert.runbook_url:
            links = []
            if alert.dashboard_url:
                links.append({
                    "type": "button",
                    "text": {
                        "type": "plain_text",
                        "text": "📊 Dashboard"
                    },
                    "url": alert.dashboard_url,
                    "action_id": f"dashboard_{alert.id}"
                })
            
            if alert.runbook_url:
                links.append({
                    "type": "button",
                    "text": {
                        "type": "plain_text", 
                        "text": "📖 Runbook"
                    },
                    "url": alert.runbook_url,
                    "action_id": f"runbook_{alert.id}"
                })
            
            actions["elements"].extend(links)
        
        blocks.append(actions)
        
        return SlackMessage(
            channel="",  # Will be set by caller
            text=f"{alert.severity.value.upper()}: {alert.title} - {alert.message}",
            blocks=blocks
        )
    
    async def handle_interaction(self, payload: Dict) -> Dict:
        """Handle Slack interactive components (button clicks)"""
        try:
            action_id = payload["actions"][0]["action_id"]
            user_id = payload["user"]["id"]
            
            if action_id.startswith("ack_"):
                alert_id = action_id.replace("ack_", "")
                await self._acknowledge_alert(alert_id, user_id)
                
                return {
                    "response_type": "ephemeral",
                    "text": f"✅ Alert {alert_id} acknowledged by <@{user_id}>"
                }
            
            return {"response_type": "ephemeral", "text": "Unknown action"}
            
        except Exception as e:
            logger.error("Failed to handle interaction", error=str(e))
            return {"response_type": "ephemeral", "text": "Failed to process action"}
    
    async def _acknowledge_alert(self, alert_id: str, user_id: str):
        """Mark alert as acknowledged"""
        key = f"alert_status:{alert_id}"
        status_data = {
            "status": AlertStatus.ACKNOWLEDGED.value,
            "acknowledged_by": user_id,
            "acknowledged_at": datetime.now().isoformat()
        }
        self.redis_client.hset(key, mapping=status_data)
        logger.info("Alert acknowledged", alert_id=alert_id, user=user_id)
    
    async def _queue_alert(self, alert: LogAlert):
        """Queue alert for later delivery"""
        queue_key = "alert_queue"
        alert_data = alert.json()
        self.redis_client.lpush(queue_key, alert_data)
    
    async def _store_notification(self, alert: LogAlert, statuses: List[NotificationStatus]):
        """Store notification records in Redis"""
        for status in statuses:
            key = f"notification:{alert.id}:{status.channel}"
            data = status.dict()
            self.redis_client.hset(key, mapping=data)
            self.redis_client.expire(key, 86400 * 7)  # 7 days retention

class RateLimiter:
    def __init__(self, requests_per_minute: int):
        self.requests_per_minute = requests_per_minute
        self.redis_client = redis.from_url(settings.redis_url)
    
    async def allow_request(self) -> bool:
        """Check if request is within rate limit"""
        key = "slack_rate_limit"
        pipe = self.redis_client.pipeline()
        pipe.incr(key)
        pipe.expire(key, 60)
        results = pipe.execute()
        
        current_count = results[0]
        return current_count <= self.requests_per_minute

class AlertDeduplicator:
    def __init__(self, window_minutes: int):
        self.window_minutes = window_minutes
        self.redis_client = redis.from_url(settings.redis_url)
    
    def is_duplicate(self, alert: LogAlert) -> bool:
        """Check if alert is a duplicate within the time window"""
        # Create hash of alert content
        content_hash = hashlib.md5(
            f"{alert.service}:{alert.component}:{alert.title}".encode()
        ).hexdigest()
        
        key = f"alert_dedup:{content_hash}"
        
        if self.redis_client.exists(key):
            return True
        
        # Set with expiration
        self.redis_client.setex(key, self.window_minutes * 60, "1")
        return False
EOF

# Create alert generator (for testing)
cat > src/backend/services/alert_generator.py << 'EOF'
import random
import uuid
from datetime import datetime
from typing import List
from ..models.alert import LogAlert, AlertSeverity

class AlertGenerator:
    """Generate sample alerts for testing"""
    
    SERVICES = ["payment", "database", "api", "frontend", "security"]
    COMPONENTS = ["processor", "gateway", "cache", "auth", "validator"]
    
    ALERT_TEMPLATES = {
        AlertSeverity.CRITICAL: [
            "Service completely unavailable",
            "Database connection pool exhausted", 
            "Payment processing failed for all transactions",
            "Security breach detected"
        ],
        AlertSeverity.ERROR: [
            "High error rate detected",
            "Memory usage above 90%",
            "Failed to process user requests",
            "Database timeout errors"
        ],
        AlertSeverity.WARNING: [
            "Response time degradation",
            "Disk space running low",
            "Unusual traffic pattern detected",
            "Cache miss rate elevated"
        ],
        AlertSeverity.INFO: [
            "Deployment completed successfully",
            "Scheduled maintenance starting",
            "Configuration updated",
            "Health check passed"
        ]
    }
    
    def generate_alert(self, severity: AlertSeverity = None) -> LogAlert:
        """Generate a random alert"""
        if not severity:
            severity = random.choice(list(AlertSeverity))
        
        service = random.choice(self.SERVICES)
        component = random.choice(self.COMPONENTS)
        title = random.choice(self.ALERT_TEMPLATES[severity])
        
        alert = LogAlert(
            id=str(uuid.uuid4()),
            title=title,
            message=f"Alert detected in {service} {component}: {title}",
            severity=severity,
            service=service,
            component=component,
            timestamp=datetime.now(),
            metadata={
                "correlation_id": str(uuid.uuid4()),
                "source": "log_processor",
                "environment": "production"
            },
            affected_users=random.randint(1, 1000) if severity in [AlertSeverity.CRITICAL, AlertSeverity.ERROR] else None,
            dashboard_url=f"https://dashboard.example.com/{service}",
            runbook_url=f"https://runbook.example.com/{service}_{component}",
            raw_logs=[
                f"ERROR: {title} at {datetime.now().isoformat()}",
                f"Stack trace: sample error in {component}",
                f"Request ID: {uuid.uuid4()}"
            ]
        )
        
        return alert
    
    def generate_batch(self, count: int) -> List[LogAlert]:
        """Generate multiple alerts"""
        return [self.generate_alert() for _ in range(count)]
EOF

# Create FastAPI application
cat > src/backend/main.py << 'EOF'
from fastapi import FastAPI, HTTPException, Request, BackgroundTasks
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import redis
import json
import structlog
from typing import List, Dict
from datetime import datetime

from .services.slack_service import SlackService
from .services.alert_generator import AlertGenerator
from .models.alert import LogAlert, AlertSeverity, NotificationStatus
from .config.config import settings

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.JSONRenderer()
    ],
    wrapper_class=structlog.stdlib.LoggerFactory(),
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger(__name__)

app = FastAPI(
    title="Slack Notification Integration",
    description="Real-time Slack notifications for distributed log processing",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
slack_service = SlackService()
alert_generator = AlertGenerator()
redis_client = redis.from_url(settings.redis_url)

@app.on_event("startup")
async def startup_event():
    logger.info("Starting Slack Integration Service")
    
    # Test Redis connection
    try:
        redis_client.ping()
        logger.info("Redis connection established")
    except Exception as e:
        logger.error("Failed to connect to Redis", error=str(e))

@app.post("/api/alerts/send")
async def send_alert(alert: LogAlert, background_tasks: BackgroundTasks):
    """Send alert to Slack"""
    try:
        logger.info("Received alert", alert_id=alert.id, severity=alert.severity)
        
        background_tasks.add_task(process_alert, alert)
        
        return {
            "status": "accepted",
            "alert_id": alert.id,
            "message": "Alert queued for processing"
        }
    except Exception as e:
        logger.error("Failed to queue alert", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to process alert")

async def process_alert(alert: LogAlert):
    """Process alert in background"""
    try:
        status = await slack_service.send_alert(alert)
        logger.info("Alert processed", alert_id=alert.id, status=status.status)
    except Exception as e:
        logger.error("Failed to process alert", alert_id=alert.id, error=str(e))

@app.post("/api/alerts/test")
async def generate_test_alert(severity: AlertSeverity = AlertSeverity.INFO):
    """Generate and send test alert"""
    try:
        alert = alert_generator.generate_alert(severity)
        status = await slack_service.send_alert(alert)
        
        return {
            "alert": alert.dict(),
            "status": status.dict()
        }
    except Exception as e:
        logger.error("Failed to generate test alert", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to generate test alert")

@app.post("/api/slack/interactions")
async def handle_slack_interaction(request: Request):
    """Handle Slack interactive components"""
    try:
        form = await request.form()
        payload = json.loads(form["payload"])
        
        response = await slack_service.handle_interaction(payload)
        return JSONResponse(content=response)
        
    except Exception as e:
        logger.error("Failed to handle Slack interaction", error=str(e))
        return JSONResponse(content={"text": "Failed to process interaction"})

@app.get("/api/stats")
async def get_stats():
    """Get notification statistics"""
    try:
        # Get rate limit stats
        rate_limit_key = "slack_rate_limit"
        current_rate = redis_client.get(rate_limit_key) or 0
        
        # Get recent alerts
        alert_keys = redis_client.keys("notification:*")
        recent_alerts = len(alert_keys)
        
        # Get queue depth
        queue_depth = redis_client.llen("alert_queue")
        
        return {
            "current_rate_per_minute": int(current_rate),
            "max_rate_per_minute": settings.max_alerts_per_minute,
            "recent_notifications": recent_alerts,
            "queued_alerts": queue_depth,
            "deduplication_window_minutes": settings.deduplication_window_minutes,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error("Failed to get stats", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to get statistics")

@app.get("/api/notifications/recent")
async def get_recent_notifications(limit: int = 50):
    """Get recent notification history"""
    try:
        notification_keys = redis_client.keys("notification:*")
        notifications = []
        
        for key in notification_keys[:limit]:
            data = redis_client.hgetall(key)
            if data:
                notifications.append({
                    "key": key.decode(),
                    "alert_id": data.get(b"alert_id", b"").decode(),
                    "status": data.get(b"status", b"").decode(),
                    "channel": data.get(b"channel", b"").decode(),
                    "sent_at": data.get(b"sent_at", b"").decode(),
                })
        
        return {
            "notifications": notifications,
            "total": len(notifications)
        }
    except Exception as e:
        logger.error("Failed to get recent notifications", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to get notifications")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Check Redis connection
        redis_client.ping()
        
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "services": {
                "redis": "connected",
                "slack": "configured" if settings.slack_bot_token else "not_configured"
            }
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }

# Serve React app in production
if not settings.debug:
    app.mount("/", StaticFiles(directory="build", html=True), name="static")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=settings.api_host, port=settings.api_port)
EOF

# Create React Dashboard App
cat > src/frontend/App.js << 'EOF'
import React, { useState, useEffect } from 'react';
import { 
  Container, 
  Grid, 
  Card, 
  CardContent, 
  Typography, 
  Button, 
  Box,
  Alert,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  LinearProgress,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  FormControl,
  InputLabel,
  Select,
  MenuItem
} from '@mui/material';
import { 
  Notifications,
  Send,
  TrendingUp,
  Warning,
  CheckCircle,
  Error as ErrorIcon,
  Info
} from '@mui/icons-material';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import axios from 'axios';

const API_BASE = process.env.REACT_APP_API_URL || 'http://localhost:8000';

function App() {
  const [stats, setStats] = useState(null);
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(false);
  const [testDialogOpen, setTestDialogOpen] = useState(false);
  const [testSeverity, setTestSeverity] = useState('info');
  const [alertHistory, setAlertHistory] = useState([]);

  // Fetch statistics
  const fetchStats = async () => {
    try {
      const response = await axios.get(`${API_BASE}/api/stats`);
      setStats(response.data);
    } catch (error) {
      console.error('Failed to fetch stats:', error);
    }
  };

  // Fetch recent notifications
  const fetchNotifications = async () => {
    try {
      const response = await axios.get(`${API_BASE}/api/notifications/recent`);
      setNotifications(response.data.notifications);
    } catch (error) {
      console.error('Failed to fetch notifications:', error);
    }
  };

  // Send test alert
  const sendTestAlert = async () => {
    setLoading(true);
    try {
      const response = await axios.post(`${API_BASE}/api/alerts/test?severity=${testSeverity}`);
      setAlertHistory(prev => [response.data, ...prev.slice(0, 9)]);
      setTestDialogOpen(false);
      
      // Refresh data
      setTimeout(() => {
        fetchStats();
        fetchNotifications();
      }, 1000);
      
    } catch (error) {
      console.error('Failed to send test alert:', error);
    } finally {
      setLoading(false);
    }
  };

  // Auto-refresh data
  useEffect(() => {
    fetchStats();
    fetchNotifications();
    
    const interval = setInterval(() => {
      fetchStats();
      fetchNotifications();
    }, 10000); // Refresh every 10 seconds
    
    return () => clearInterval(interval);
  }, []);

  const getSeverityColor = (severity) => {
    const colors = {
      critical: 'error',
      error: 'warning', 
      warning: 'info',
      info: 'success'
    };
    return colors[severity] || 'default';
  };

  const getSeverityIcon = (severity) => {
    const icons = {
      critical: <ErrorIcon />,
      error: <Warning />,
      warning: <Info />,
      info: <CheckCircle />
    };
    return icons[severity] || <Info />;
  };

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h3" component="h1" gutterBottom>
          🔔 Slack Integration Dashboard
        </Typography>
        <Typography variant="subtitle1" color="text.secondary">
          Real-time notifications for distributed log processing
        </Typography>
      </Box>

      {/* Statistics Cards */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)', color: 'white' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box>
                  <Typography variant="h4" component="div">
                    {stats?.current_rate_per_minute || 0}
                  </Typography>
                  <Typography variant="body2">
                    Alerts/Min
                  </Typography>
                </Box>
                <TrendingUp sx={{ fontSize: 40, opacity: 0.8 }} />
              </Box>
              {stats && (
                <LinearProgress 
                  variant="determinate" 
                  value={(stats.current_rate_per_minute / stats.max_rate_per_minute) * 100}
                  sx={{ mt: 2, bgcolor: 'rgba(255,255,255,0.2)' }}
                />
              )}
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ background: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)', color: 'white' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box>
                  <Typography variant="h4" component="div">
                    {stats?.recent_notifications || 0}
                  </Typography>
                  <Typography variant="body2">
                    Recent Notifications
                  </Typography>
                </Box>
                <Notifications sx={{ fontSize: 40, opacity: 0.8 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ background: 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)', color: 'white' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box>
                  <Typography variant="h4" component="div">
                    {stats?.queued_alerts || 0}
                  </Typography>
                  <Typography variant="body2">
                    Queued Alerts
                  </Typography>
                </Box>
                <Warning sx={{ fontSize: 40, opacity: 0.8 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card sx={{ background: 'linear-gradient(135deg, #43e97b 0%, #38f9d7 100%)', color: 'white' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box>
                  <Typography variant="h4" component="div">
                    {stats?.deduplication_window_minutes || 0}m
                  </Typography>
                  <Typography variant="body2">
                    Dedup Window
                  </Typography>
                </Box>
                <CheckCircle sx={{ fontSize: 40, opacity: 0.8 }} />
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Controls */}
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Box sx={{ display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
            <Button 
              variant="contained" 
              startIcon={<Send />}
              onClick={() => setTestDialogOpen(true)}
              disabled={loading}
              sx={{ background: 'linear-gradient(45deg, #FE6B8B 30%, #FF8E53 90%)' }}
            >
              Send Test Alert
            </Button>
            <Button 
              variant="outlined" 
              onClick={fetchStats}
              disabled={loading}
            >
              Refresh Stats
            </Button>
            {stats && (
              <Alert severity="info" sx={{ ml: 'auto' }}>
                Rate Limit: {stats.current_rate_per_minute}/{stats.max_rate_per_minute} per minute
              </Alert>
            )}
          </Box>
        </CardContent>
      </Card>

      {/* Recent Test Alerts */}
      {alertHistory.length > 0 && (
        <Card sx={{ mb: 4 }}>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              🧪 Recent Test Alerts
            </Typography>
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Severity</TableCell>
                    <TableCell>Service</TableCell>
                    <TableCell>Title</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Channel</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {alertHistory.map((alert, index) => (
                    <TableRow key={index}>
                      <TableCell>
                        <Chip 
                          icon={getSeverityIcon(alert.alert.severity)}
                          label={alert.alert.severity.toUpperCase()}
                          color={getSeverityColor(alert.alert.severity)}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>{alert.alert.service}</TableCell>
                      <TableCell>{alert.alert.title}</TableCell>
                      <TableCell>
                        <Chip 
                          label={alert.status.status}
                          color={alert.status.status === 'sent' ? 'success' : 'default'}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>{alert.status.channel}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>
      )}

      {/* Recent Notifications */}
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            📋 Recent Notifications
          </Typography>
          <TableContainer component={Paper} elevation={0}>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Alert ID</TableCell>
                  <TableCell>Status</TableCell>
                  <TableCell>Channel</TableCell>
                  <TableCell>Sent At</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {notifications.map((notification, index) => (
                  <TableRow key={index}>
                    <TableCell>
                      <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                        {notification.alert_id.substring(0, 8)}...
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Chip 
                        label={notification.status}
                        color={notification.status === 'sent' ? 'success' : 'default'}
                        size="small"
                      />
                    </TableCell>
                    <TableCell>{notification.channel}</TableCell>
                    <TableCell>
                      {notification.sent_at ? 
                        new Date(notification.sent_at).toLocaleString() : 
                        'Not sent'
                      }
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </CardContent>
      </Card>

      {/* Test Alert Dialog */}
      <Dialog open={testDialogOpen} onClose={() => setTestDialogOpen(false)}>
        <DialogTitle>Send Test Alert</DialogTitle>
        <DialogContent>
          <FormControl fullWidth sx={{ mt: 2 }}>
            <InputLabel>Severity</InputLabel>
            <Select
              value={testSeverity}
              onChange={(e) => setTestSeverity(e.target.value)}
              label="Severity"
            >
              <MenuItem value="info">Info</MenuItem>
              <MenuItem value="warning">Warning</MenuItem>
              <MenuItem value="error">Error</MenuItem>
              <MenuItem value="critical">Critical</MenuItem>
            </Select>
          </FormControl>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setTestDialogOpen(false)}>Cancel</Button>
          <Button onClick={sendTestAlert} variant="contained" disabled={loading}>
            Send Alert
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}

export default App;
EOF

# Create React index.js
cat > src/frontend/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import App from './App';

const theme = createTheme({
  palette: {
    mode: 'light',
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

# Create HTML template
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Slack Integration Dashboard" />
    <title>Slack Integration Dashboard</title>
    <link
      rel="stylesheet"
      href="https://fonts.googleapis.com/css?family=Roboto:300,400,500,700&display=swap"
    />
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

# Create comprehensive test suite
cat > tests/test_slack_integration.py << 'EOF'
import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch
from datetime import datetime
import json

from src.backend.models.alert import LogAlert, AlertSeverity, AlertStatus
from src.backend.services.slack_service import SlackService, RateLimiter, AlertDeduplicator

@pytest.fixture
def sample_alert():
    return LogAlert(
        id="test-alert-123",
        title="Test Alert",
        message="This is a test alert message",
        severity=AlertSeverity.ERROR,
        service="payment",
        component="processor",
        timestamp=datetime.now(),
        metadata={"test": True},
        dashboard_url="https://dashboard.example.com",
        runbook_url="https://runbook.example.com"
    )

@pytest.fixture
def mock_slack_service():
    with patch('src.backend.services.slack_service.AsyncWebClient') as mock_client, \
         patch('src.backend.services.slack_service.redis.from_url') as mock_redis:
        
        mock_redis.return_value.ping.return_value = True
        service = SlackService()
        service.client.chat_postMessage = AsyncMock(return_value={"ts": "1234567890.123456"})
        return service

class TestSlackService:
    @pytest.mark.asyncio
    async def test_send_alert_success(self, mock_slack_service, sample_alert):
        """Test successful alert sending"""
        status = await mock_slack_service.send_alert(sample_alert)
        
        assert status.alert_id == sample_alert.id
        assert status.status == AlertStatus.SENT
        mock_slack_service.client.chat_postMessage.assert_called_once()

    @pytest.mark.asyncio 
    async def test_channel_resolution(self, mock_slack_service, sample_alert):
        """Test proper channel resolution based on service"""
        channels = mock_slack_service._resolve_channels(sample_alert)
        
        # Should include service-specific channel for payment service
        assert "#payments-team" in channels
        # Should include severity-specific channel for error
        assert "#alerts" in channels

    def test_message_formatting(self, mock_slack_service, sample_alert):
        """Test Slack message formatting"""
        message = mock_slack_service._format_alert_message(sample_alert)
        
        assert message.text.startswith("ERROR:")
        assert len(message.blocks) > 0
        
        # Check for action buttons
        action_block = next((block for block in message.blocks if block["type"] == "actions"), None)
        assert action_block is not None
        assert any(element["action_id"].startswith("ack_") for element in action_block["elements"])

    @pytest.mark.asyncio
    async def test_interaction_handling(self, mock_slack_service):
        """Test handling of Slack interactions"""
        payload = {
            "actions": [{"action_id": "ack_test-alert-123", "value": "test-alert-123"}],
            "user": {"id": "U123456"}
        }
        
        response = await mock_slack_service.handle_interaction(payload)
        
        assert response["response_type"] == "ephemeral"
        assert "acknowledged" in response["text"]

class TestRateLimiter:
    def test_rate_limiting(self):
        """Test rate limiting functionality"""
        with patch('src.backend.services.slack_service.redis.from_url') as mock_redis:
            mock_redis.return_value.pipeline.return_value.execute.return_value = [5, True]
            
            limiter = RateLimiter(requests_per_minute=10)
            result = asyncio.run(limiter.allow_request())
            
            assert result is True

    def test_rate_limit_exceeded(self):
        """Test rate limit exceeded scenario"""
        with patch('src.backend.services.slack_service.redis.from_url') as mock_redis:
            mock_redis.return_value.pipeline.return_value.execute.return_value = [15, True]
            
            limiter = RateLimiter(requests_per_minute=10)
            result = asyncio.run(limiter.allow_request())
            
            assert result is False

class TestAlertDeduplicator:
    def test_duplicate_detection(self, sample_alert):
        """Test duplicate alert detection"""
        with patch('src.backend.services.slack_service.redis.from_url') as mock_redis:
            mock_redis.return_value.exists.return_value = True
            
            deduplicator = AlertDeduplicator(window_minutes=5)
            is_duplicate = deduplicator.is_duplicate(sample_alert)
            
            assert is_duplicate is True

    def test_new_alert_detection(self, sample_alert):
        """Test new alert detection"""
        with patch('src.backend.services.slack_service.redis.from_url') as mock_redis:
            mock_redis.return_value.exists.return_value = False
            
            deduplicator = AlertDeduplicator(window_minutes=5)
            is_duplicate = deduplicator.is_duplicate(sample_alert)
            
            assert is_duplicate is False
            mock_redis.return_value.setex.assert_called_once()

class TestIntegration:
    @pytest.mark.asyncio
    async def test_end_to_end_alert_flow(self, sample_alert):
        """Test complete alert processing flow"""
        with patch('src.backend.services.slack_service.AsyncWebClient') as mock_client, \
             patch('src.backend.services.slack_service.redis.from_url') as mock_redis:
            
            # Setup mocks
            mock_redis.return_value.ping.return_value = True
            mock_redis.return_value.exists.return_value = False  # Not duplicate
            mock_redis.return_value.pipeline.return_value.execute.return_value = [1, True]  # Within rate limit
            
            mock_client.return_value.chat_postMessage = AsyncMock(
                return_value={"ts": "1234567890.123456"}
            )
            
            # Create service and send alert
            service = SlackService()
            status = await service.send_alert(sample_alert)
            
            # Verify results
            assert status.status == AlertStatus.SENT
            assert status.message_ts == "1234567890.123456"
            mock_client.return_value.chat_postMessage.assert_called_once()

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create integration test
cat > tests/test_api_integration.py << 'EOF'
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, AsyncMock

from src.backend.main import app

@pytest.fixture
def client():
    return TestClient(app)

class TestAPIIntegration:
    def test_health_check(self, client):
        """Test health check endpoint"""
        with patch('src.backend.main.redis_client') as mock_redis:
            mock_redis.ping.return_value = True
            
            response = client.get("/health")
            
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "healthy"
            assert "services" in data

    def test_get_stats(self, client):
        """Test statistics endpoint"""
        with patch('src.backend.main.redis_client') as mock_redis:
            mock_redis.get.return_value = "5"
            mock_redis.keys.return_value = ["key1", "key2", "key3"]
            mock_redis.llen.return_value = 2
            
            response = client.get("/api/stats")
            
            assert response.status_code == 200
            data = response.json()
            assert "current_rate_per_minute" in data
            assert "recent_notifications" in data
            assert "queued_alerts" in data

    def test_send_alert(self, client):
        """Test alert sending endpoint"""
        alert_data = {
            "id": "test-123",
            "title": "Test Alert",
            "message": "Test message",
            "severity": "error",
            "service": "test-service",
            "component": "test-component",
            "timestamp": "2025-05-20T10:00:00Z",
            "metadata": {}
        }
        
        response = client.post("/api/alerts/send", json=alert_data)
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "accepted"
        assert data["alert_id"] == "test-123"

    def test_generate_test_alert(self, client):
        """Test test alert generation"""
        with patch('src.backend.main.slack_service') as mock_service:
            mock_service.send_alert = AsyncMock(return_value=type('obj', (object,), {
                'dict': lambda: {"status": "sent", "channel": "#test"}
            })())
            
            response = client.post("/api/alerts/test?severity=warning")
            
            assert response.status_code == 200
            data = response.json()
            assert "alert" in data
            assert "status" in data
            assert data["alert"]["severity"] == "warning"

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create Docker files
cat > Dockerfile << 'EOF'
# Multi-stage Dockerfile for Slack Integration
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend
COPY package.json ./
RUN npm install --silent
COPY src/frontend/ ./src/
COPY public/ ./public/
RUN npm run build

FROM python:3.11-slim AS backend

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/backend/ ./src/backend/
COPY --from=frontend-builder /app/frontend/build ./build

# Create non-root user
RUN useradd --create-home --shell /bin/bash app
USER app

EXPOSE 8000

CMD ["python", "-m", "src.backend.main"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes

  slack-integration:
    build: .
    ports:
      - "8000:8000"
    environment:
      - REDIS_URL=redis://redis:6379/0
      - API_HOST=0.0.0.0
      - API_PORT=8000
    depends_on:
      - redis
    volumes:
      - ./.env:/app/.env:ro

volumes:
  redis_data:
EOF

cat > .dockerignore << 'EOF'
node_modules
.git
.gitignore
README.md
.env
.pytest_cache
__pycache__
*.pyc
*.pyo
*.pyd
.Python
build
develop-eggs
dist
downloads
eggs
.eggs
lib
lib64
parts
sdist
var
wheels
*.egg-info
.installed.cfg
*.egg
EOF

# Create build script
cat > build.sh << 'EOF'
#!/bin/bash

echo "🏗️  Building Day 135: Slack Integration System"
echo "=============================================="

# Create virtual environment
echo "📦 Creating Python virtual environment..."
python3.11 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "📥 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Install Node.js dependencies for frontend
echo "📥 Installing Node.js dependencies..."
if command -v npm &> /dev/null; then
    npm install
else
    echo "⚠️  Node.js not found. Frontend will not be built."
fi

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v

# Check syntax
echo "🔍 Checking Python syntax..."
python -m py_compile src/backend/main.py
python -m py_compile src/backend/services/slack_service.py

echo "✅ Build completed successfully!"
echo ""
echo "Next steps:"
echo "1. Configure Slack credentials in .env file"
echo "2. Run: ./start.sh"
echo "3. Open: http://localhost:8000"
EOF

chmod +x build.sh

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Slack Integration System"
echo "===================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "⚠️  Virtual environment not found. Running build first..."
    ./build.sh
fi

# Activate virtual environment
source venv/bin/activate

# Start Redis if not running
if ! redis-cli ping &> /dev/null; then
    echo "🔴 Starting Redis server..."
    redis-server --daemonize yes
    sleep 2
fi

# Start backend
echo "🔵 Starting backend server..."
python -m src.backend.main &
BACKEND_PID=$!

# Build and serve frontend if npm is available
if command -v npm &> /dev/null; then
    echo "🟢 Building and starting frontend..."
    npm run build
    npx serve -s build -l 3000 &
    FRONTEND_PID=$!
fi

echo ""
echo "🎉 System started successfully!"
echo ""
echo "🔗 Backend API: http://localhost:8000"
echo "🔗 Frontend Dashboard: http://localhost:3000"
echo "🔗 API Documentation: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for interrupt
trap 'echo ""; echo "🛑 Stopping services..."; kill $BACKEND_PID 2>/dev/null; kill $FRONTEND_PID 2>/dev/null; exit 0' INT
wait
EOF

chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Slack Integration System"
echo "===================================="

# Kill backend processes
pkill -f "python -m src.backend.main"

# Kill frontend processes  
pkill -f "npx serve"

# Stop Redis if running
redis-cli shutdown 2>/dev/null || true

echo "✅ All services stopped"
EOF

chmod +x stop.sh

# Create demo script
cat > demo.py << 'EOF'
#!/usr/bin/env python3

import asyncio
import requests
import time
import json
from datetime import datetime

API_BASE = "http://localhost:8000"

def check_health():
    """Check if the API is running"""
    try:
        response = requests.get(f"{API_BASE}/health")
        return response.status_code == 200
    except:
        return False

def send_test_alerts():
    """Send a series of test alerts"""
    severities = ["info", "warning", "error", "critical"]
    
    print("🚀 Sending test alerts...")
    
    for i, severity in enumerate(severities):
        print(f"📧 Sending {severity} alert...")
        
        try:
            response = requests.post(f"{API_BASE}/api/alerts/test?severity={severity}")
            if response.status_code == 200:
                data = response.json()
                print(f"   ✅ Sent: {data['alert']['title']}")
                print(f"   📍 Status: {data['status']['status']}")
                print(f"   📢 Channel: {data['status']['channel']}")
            else:
                print(f"   ❌ Failed: {response.status_code}")
        except Exception as e:
            print(f"   ❌ Error: {e}")
        
        time.sleep(2)  # Rate limiting

def get_stats():
    """Get current system statistics"""
    try:
        response = requests.get(f"{API_BASE}/api/stats")
        if response.status_code == 200:
            stats = response.json()
            print("\n📊 Current Statistics:")
            print(f"   Rate: {stats['current_rate_per_minute']}/{stats['max_rate_per_minute']} per minute")
            print(f"   Recent notifications: {stats['recent_notifications']}")
            print(f"   Queued alerts: {stats['queued_alerts']}")
            print(f"   Dedup window: {stats['deduplication_window_minutes']} minutes")
        else:
            print(f"❌ Failed to get stats: {response.status_code}")
    except Exception as e:
        print(f"❌ Error getting stats: {e}")

def main():
    print("🎭 Slack Integration Demo")
    print("========================")
    
    # Check if API is running
    if not check_health():
        print("❌ API is not running. Please start the system first:")
        print("   ./start.sh")
        return
    
    print("✅ API is running")
    
    # Get initial stats
    get_stats()
    
    # Send test alerts
    send_test_alerts()
    
    # Get final stats
    print("\n" + "="*50)
    get_stats()
    
    print("\n🎉 Demo completed!")
    print("\n📊 Check the dashboard at: http://localhost:3000")
    print("📋 View API docs at: http://localhost:8000/docs")

if __name__ == "__main__":
    main()
EOF

chmod +x demo.py

# Create README
cat > README.md << 'EOF'
# Day 135: Slack Notification Integration

Real-time Slack notifications for distributed log processing systems.

## Quick Start

1. **Configure Slack**: Update `.env` with your Slack credentials
2. **Build**: `./build.sh`
3. **Start**: `./start.sh`
4. **Demo**: `python demo.py`

## Features

- Real-time alert routing to Slack channels
- Intelligent deduplication and rate limiting
- Interactive message components
- Multi-severity alert handling
- Modern React dashboard
- Comprehensive testing suite

## Architecture

- **Backend**: FastAPI + Slack SDK
- **Frontend**: React + Material-UI
- **Storage**: Redis for caching and queuing
- **Deployment**: Docker + Docker Compose

## Configuration

Update `.env` file with your Slack app credentials:

```
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## Testing

```bash
python -m pytest tests/ -v
```

## Monitoring

- Dashboard: http://localhost:3000
- API Docs: http://localhost:8000/docs
- Health: http://localhost:8000/health
EOF

echo ""
echo "🎉 Implementation completed successfully!"
echo ""
echo "📁 Project structure created:"
find . -type f -name "*.py" -o -name "*.js" -o -name "*.sh" -o -name "*.yml" | head -20
echo "   ... and more"
echo ""
echo "🚀 Next steps:"
echo "1. Configure Slack credentials in .env file"
echo "2. Run: ./build.sh"
echo "3. Run: ./start.sh"
echo "4. Run: python demo.py"
echo "5. Open dashboard: http://localhost:3000"
echo ""
echo "✅ Day 135: Slack Integration - Ready for production!"