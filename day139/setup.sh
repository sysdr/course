#!/bin/bash

# Day 139: Webhook Integration System - Complete Implementation
# Building Universal Webhook Support for Distributed Log Processing

set -e

PROJECT_NAME="webhook-integration-system"
PYTHON_VERSION="python3"

echo "🚀 Day 139: Building Universal Webhook Integration System"
echo "============================================================"

# Create project structure
echo "📁 Creating project structure..."
mkdir -p ${PROJECT_NAME}/{backend,frontend,tests,docs,docker,scripts}
mkdir -p ${PROJECT_NAME}/backend/{src/{core,api,services,models,utils},config,logs}
mkdir -p ${PROJECT_NAME}/frontend/{src/{components,services,hooks,utils},public,build}
mkdir -p ${PROJECT_NAME}/tests/{unit,integration,e2e}
mkdir -p ${PROJECT_NAME}/docker/{backend,frontend}

cd ${PROJECT_NAME}

echo "📦 Creating Python virtual environment..."
${PYTHON_VERSION} -m venv venv
source venv/bin/activate

echo "📋 Creating backend requirements..."
cat > backend/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
sqlalchemy==2.0.23
pydantic==2.5.0
pydantic-settings==2.1.0
httpx==0.25.2
redis==5.0.1
cryptography>=41.0.0
python-jose==3.3.0
python-multipart==0.0.6
pytest==7.4.3
pytest-asyncio==0.21.1
aiofiles==23.2.1
jinja2==3.1.2
python-dotenv==1.0.0
structlog==23.2.0
tenacity==8.2.3
websockets==12.0
EOF

echo "🔧 Installing Python dependencies..."
pip install -r backend/requirements.txt

echo "⚙️ Creating backend configuration..."
cat > backend/config/config.py << 'EOF'
import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_name: str = "Webhook Integration System"
    database_url: str = "sqlite:///./webhook_system.db"
    redis_url: str = "redis://localhost:6379"
    secret_key: str = "webhook-system-secret-key-change-in-production"
    webhook_timeout: int = 30
    max_retry_attempts: int = 3
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    
    model_config = {"env_file": ".env"}

settings = Settings()
EOF

echo "🗄️ Creating database models..."
cat > backend/src/__init__.py << 'EOF'
# Package initialization
EOF
cat > backend/src/models/__init__.py << 'EOF'
# Models package
EOF
cat > backend/src/core/__init__.py << 'EOF'
# Core package
EOF
cat > backend/src/utils/__init__.py << 'EOF'
# Utils package
EOF
cat > backend/src/api/__init__.py << 'EOF'
# API package
EOF
cat > backend/src/models/webhook.py << 'EOF'
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, JSON
from sqlalchemy.orm import declarative_base
from sqlalchemy.sql import func
from datetime import datetime
import uuid

Base = declarative_base()

class WebhookEndpoint(Base):
    __tablename__ = "webhook_endpoints"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), nullable=False)
    url = Column(String(1024), nullable=False)
    method = Column(String(10), default="POST")
    auth_type = Column(String(50), default="none")  # none, bearer, api_key, hmac
    auth_config = Column(JSON, default={})
    payload_template = Column(Text, nullable=True)
    event_filters = Column(JSON, default=[])
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

class WebhookDelivery(Base):
    __tablename__ = "webhook_deliveries"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    endpoint_id = Column(String, nullable=False)
    event_data = Column(JSON, nullable=False)
    payload = Column(Text, nullable=False)
    status = Column(String(20), default="pending")  # pending, delivered, failed, retrying
    response_code = Column(Integer, nullable=True)
    response_body = Column(Text, nullable=True)
    attempt_count = Column(Integer, default=0)
    max_attempts = Column(Integer, default=3)
    next_retry = Column(DateTime, nullable=True)
    delivered_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
EOF

echo "🔄 Creating webhook service core..."
cat > backend/src/core/webhook_engine.py << 'EOF'
import sys
import os
# Add backend directory to Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import asyncio
import json
import hashlib
import hmac
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import httpx
from tenacity import retry, stop_after_attempt, wait_exponential
import structlog
from sqlalchemy.orm import Session

from src.models.webhook import WebhookEndpoint, WebhookDelivery
from src.utils.template_engine import TemplateEngine

logger = structlog.get_logger()

class WebhookEngine:
    def __init__(self, db_session: Session):
        self.db_session = db_session
        self.template_engine = TemplateEngine()
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def process_event(self, event_data: Dict) -> List[str]:
        """Process incoming event and trigger matching webhooks"""
        delivery_ids = []
        
        # Find matching webhook endpoints
        endpoints = self.db_session.query(WebhookEndpoint).filter(
            WebhookEndpoint.is_active == True
        ).all()
        
        for endpoint in endpoints:
            if self._matches_filters(event_data, endpoint.event_filters):
                delivery_id = await self._create_delivery(endpoint, event_data)
                delivery_ids.append(delivery_id)
                
                # Schedule immediate delivery attempt
                asyncio.create_task(self._deliver_webhook(delivery_id))
        
        return delivery_ids
    
    def _matches_filters(self, event_data: Dict, filters: List[Dict]) -> bool:
        """Check if event matches endpoint filters"""
        if not filters:
            return True
            
        for filter_rule in filters:
            field = filter_rule.get('field')
            operator = filter_rule.get('operator', 'equals')
            value = filter_rule.get('value')
            
            event_value = self._get_nested_field(event_data, field)
            
            if operator == 'equals' and event_value == value:
                return True
            elif operator == 'contains' and value in str(event_value):
                return True
            elif operator == 'greater_than' and float(event_value) > float(value):
                return True
            elif operator == 'regex':
                import re
                if re.match(value, str(event_value)):
                    return True
                    
        return False
    
    def _get_nested_field(self, data: Dict, field_path: str):
        """Extract nested field value using dot notation"""
        keys = field_path.split('.')
        value = data
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return None
        return value
    
    async def _create_delivery(self, endpoint: WebhookEndpoint, event_data: Dict) -> str:
        """Create delivery record and prepare payload"""
        # Transform payload using template
        payload = self.template_engine.transform(
            event_data, 
            endpoint.payload_template
        )
        
        delivery = WebhookDelivery(
            endpoint_id=endpoint.id,
            event_data=event_data,
            payload=json.dumps(payload),
            status="pending",
            max_attempts=3
        )
        
        self.db_session.add(delivery)
        self.db_session.commit()
        
        logger.info("Webhook delivery created", 
                   endpoint_name=endpoint.name, 
                   delivery_id=delivery.id)
        
        return delivery.id
    
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=2))
    async def _deliver_webhook(self, delivery_id: str):
        """Deliver webhook with retry logic"""
        delivery = self.db_session.query(WebhookDelivery).filter(
            WebhookDelivery.id == delivery_id
        ).first()
        
        if not delivery:
            logger.error("Delivery not found", delivery_id=delivery_id)
            return
            
        endpoint = self.db_session.query(WebhookEndpoint).filter(
            WebhookEndpoint.id == delivery.endpoint_id
        ).first()
        
        if not endpoint:
            logger.error("Endpoint not found", endpoint_id=delivery.endpoint_id)
            return
        
        try:
            delivery.attempt_count += 1
            delivery.status = "delivering"
            self.db_session.commit()
            
            # Prepare request
            headers = {"Content-Type": "application/json"}
            payload_data = json.loads(delivery.payload)
            
            # Add authentication
            self._add_authentication(headers, payload_data, endpoint)
            
            # Send request
            response = await self.client.request(
                method=endpoint.method,
                url=endpoint.url,
                json=payload_data,
                headers=headers
            )
            
            # Update delivery status
            delivery.status = "delivered" if response.is_success else "failed"
            delivery.response_code = response.status_code
            delivery.response_body = response.text[:1000]  # Truncate response
            
            if response.is_success:
                delivery.delivered_at = datetime.utcnow()
                logger.info("Webhook delivered successfully", 
                           delivery_id=delivery_id,
                           status_code=response.status_code)
            else:
                logger.warning("Webhook delivery failed", 
                              delivery_id=delivery_id,
                              status_code=response.status_code)
                
        except Exception as e:
            delivery.status = "failed"
            delivery.response_body = str(e)[:500]
            logger.error("Webhook delivery exception", 
                        delivery_id=delivery_id, 
                        error=str(e))
            
            # Schedule retry if attempts remaining
            if delivery.attempt_count < delivery.max_attempts:
                delivery.status = "retrying"
                retry_delay = 2 ** delivery.attempt_count  # Exponential backoff
                delivery.next_retry = datetime.utcnow() + timedelta(seconds=retry_delay)
                
        finally:
            delivery.updated_at = datetime.utcnow()
            self.db_session.commit()
    
    def _add_authentication(self, headers: Dict, payload: Dict, endpoint: WebhookEndpoint):
        """Add authentication to webhook request"""
        auth_config = endpoint.auth_config or {}
        
        if endpoint.auth_type == "bearer":
            token = auth_config.get("token")
            if token:
                headers["Authorization"] = f"Bearer {token}"
                
        elif endpoint.auth_type == "api_key":
            key = auth_config.get("key")
            header_name = auth_config.get("header", "X-API-Key")
            if key:
                headers[header_name] = key
                
        elif endpoint.auth_type == "hmac":
            secret = auth_config.get("secret")
            if secret:
                payload_str = json.dumps(payload, separators=(',', ':'))
                signature = hmac.new(
                    secret.encode(),
                    payload_str.encode(),
                    hashlib.sha256
                ).hexdigest()
                headers["X-Webhook-Signature"] = f"sha256={signature}"
EOF

echo "🎨 Creating template engine..."
cat > backend/src/utils/template_engine.py << 'EOF'
import json
from typing import Dict, Any
from datetime import datetime
import re

class TemplateEngine:
    """Simple template engine for webhook payload transformation"""
    
    def transform(self, event_data: Dict, template: str = None) -> Dict[str, Any]:
        """Transform event data using template or default format"""
        if not template:
            return self._default_transform(event_data)
        
        try:
            template_dict = json.loads(template)
            return self._apply_template(event_data, template_dict)
        except json.JSONDecodeError:
            # Fallback to default transformation
            return self._default_transform(event_data)
    
    def _default_transform(self, event_data: Dict) -> Dict[str, Any]:
        """Default webhook payload format"""
        return {
            "event_type": event_data.get("type", "log_event"),
            "timestamp": event_data.get("timestamp", datetime.utcnow().isoformat()),
            "severity": event_data.get("level", "info"),
            "message": event_data.get("message", ""),
            "source": event_data.get("source", "log_processor"),
            "metadata": event_data.get("metadata", {}),
            "webhook_id": event_data.get("event_id", ""),
            "system": "Distributed Log Processing System"
        }
    
    def _apply_template(self, event_data: Dict, template: Dict) -> Dict[str, Any]:
        """Apply template transformations"""
        result = {}
        
        for key, value in template.items():
            if isinstance(value, str):
                # Process template strings with placeholders
                result[key] = self._process_template_string(value, event_data)
            elif isinstance(value, dict):
                # Recursive processing for nested objects
                result[key] = self._apply_template(event_data, value)
            elif isinstance(value, list):
                # Process list templates
                result[key] = [self._apply_template(event_data, item) if isinstance(item, dict) 
                              else self._process_template_string(str(item), event_data) 
                              for item in value]
            else:
                result[key] = value
                
        return result
    
    def _process_template_string(self, template_str: str, event_data: Dict) -> Any:
        """Process template string with variable substitution"""
        # Find all {{variable}} patterns
        pattern = r'\{\{([^}]+)\}\}'
        
        def replace_var(match):
            var_path = match.group(1).strip()
            value = self._get_nested_value(event_data, var_path)
            return str(value) if value is not None else ""
        
        return re.sub(pattern, replace_var, template_str)
    
    def _get_nested_value(self, data: Dict, path: str) -> Any:
        """Get nested value using dot notation"""
        keys = path.split('.')
        current = data
        
        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return None
                
        return current
EOF

echo "🌐 Creating FastAPI application..."
cat > backend/src/api/main.py << 'EOF'
import sys
import os
# Add backend directory to Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel
from typing import Dict, List, Optional
import json
from datetime import datetime
import asyncio

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from src.models.webhook import Base, WebhookEndpoint, WebhookDelivery
from src.core.webhook_engine import WebhookEngine
from config.config import settings

# Database setup
engine = create_engine(settings.database_url, connect_args={"check_same_thread": False} if "sqlite" in settings.database_url else {})
Base.metadata.create_all(bind=engine)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

app = FastAPI(title=settings.app_name)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Pydantic models
class WebhookEndpointCreate(BaseModel):
    name: str
    url: str
    method: str = "POST"
    auth_type: str = "none"
    auth_config: Dict = {}
    payload_template: Optional[str] = None
    event_filters: List[Dict] = []

class LogEvent(BaseModel):
    type: str
    timestamp: str
    level: str
    message: str
    source: str
    metadata: Dict = {}

@app.get("/")
async def dashboard():
    """Serve dashboard HTML"""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Webhook Integration Dashboard</title>
        <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
        <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
        <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; padding: 20px; background: #f5f7fa; }
            .dashboard { max-width: 1200px; margin: 0 auto; }
            .header { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); margin-bottom: 30px; }
            .title { margin: 0; color: #2d3748; font-size: 28px; font-weight: 700; }
            .subtitle { margin: 5px 0 0; color: #718096; font-size: 16px; }
            .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 30px; }
            .card { background: white; padding: 25px; border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .card h3 { margin: 0 0 20px; color: #2d3748; font-size: 20px; }
            .form-group { margin-bottom: 20px; }
            .form-group label { display: block; margin-bottom: 8px; color: #4a5568; font-weight: 500; }
            .form-control { width: 100%; padding: 12px; border: 2px solid #e2e8f0; border-radius: 8px; font-size: 14px; }
            .form-control:focus { outline: none; border-color: #4299e1; }
            .btn { padding: 12px 20px; background: #4299e1; color: white; border: none; border-radius: 8px; font-weight: 500; cursor: pointer; }
            .btn:hover { background: #3182ce; }
            .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; margin-bottom: 25px; }
            .stat { background: #f7fafc; padding: 20px; border-radius: 10px; text-align: center; }
            .stat-value { font-size: 24px; font-weight: 700; color: #2d3748; }
            .stat-label { color: #718096; font-size: 14px; margin-top: 5px; }
            .webhook-list { margin-top: 25px; }
            .webhook-item { background: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; }
            .webhook-info h4 { margin: 0; color: #2d3748; }
            .webhook-info p { margin: 5px 0 0; color: #718096; font-size: 13px; }
            .status { padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 500; }
            .status-active { background: #c6f6d5; color: #22543d; }
            .status-inactive { background: #fed7d7; color: #742a2a; }
        </style>
    </head>
    <body>
        <div id="root"></div>
        <script type="text/babel">
            function Dashboard() {
                const [webhooks, setWebhooks] = React.useState([]);
                const [stats, setStats] = React.useState({ total: 0, active: 0, deliveries: 0 });
                const [formData, setFormData] = React.useState({
                    name: '', url: '', auth_type: 'none', auth_config: {}, event_filters: []
                });

                React.useEffect(() => {
                    fetchWebhooks();
                    fetchStats();
                    const interval = setInterval(fetchStats, 5000);
                    return () => clearInterval(interval);
                }, []);

                const fetchWebhooks = async () => {
                    try {
                        const response = await fetch('/api/webhooks');
                        const data = await response.json();
                        setWebhooks(data);
                    } catch (error) {
                        console.error('Error fetching webhooks:', error);
                    }
                };

                const fetchStats = async () => {
                    try {
                        const response = await fetch('/api/stats');
                        const data = await response.json();
                        setStats(data);
                    } catch (error) {
                        console.error('Error fetching stats:', error);
                    }
                };

                const handleSubmit = async (e) => {
                    e.preventDefault();
                    try {
                        const response = await fetch('/api/webhooks', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify(formData)
                        });
                        
                        if (response.ok) {
                            setFormData({ name: '', url: '', auth_type: 'none', auth_config: {}, event_filters: [] });
                            fetchWebhooks();
                            alert('Webhook created successfully!');
                        }
                    } catch (error) {
                        alert('Error creating webhook: ' + error.message);
                    }
                };

                const testWebhook = async () => {
                    try {
                        const response = await fetch('/api/test-event', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({
                                type: 'test_event',
                                timestamp: new Date().toISOString(),
                                level: 'info',
                                message: 'Test webhook delivery from dashboard',
                                source: 'webhook_dashboard',
                                metadata: { test: true }
                            })
                        });
                        
                        if (response.ok) {
                            alert('Test event sent to all active webhooks!');
                            fetchStats();
                        }
                    } catch (error) {
                        alert('Error sending test event: ' + error.message);
                    }
                };

                return React.createElement('div', { className: 'dashboard' }, [
                    React.createElement('div', { className: 'header', key: 'header' }, [
                        React.createElement('h1', { className: 'title', key: 'title' }, 'Webhook Integration System'),
                        React.createElement('p', { className: 'subtitle', key: 'subtitle' }, 'Universal webhook dispatcher for distributed log processing')
                    ]),
                    
                    React.createElement('div', { className: 'stats', key: 'stats' }, [
                        React.createElement('div', { className: 'stat', key: 'total' }, [
                            React.createElement('div', { className: 'stat-value', key: 'value' }, stats.total),
                            React.createElement('div', { className: 'stat-label', key: 'label' }, 'Total Webhooks')
                        ]),
                        React.createElement('div', { className: 'stat', key: 'active' }, [
                            React.createElement('div', { className: 'stat-value', key: 'value' }, stats.active),
                            React.createElement('div', { className: 'stat-label', key: 'label' }, 'Active Endpoints')
                        ]),
                        React.createElement('div', { className: 'stat', key: 'deliveries' }, [
                            React.createElement('div', { className: 'stat-value', key: 'value' }, stats.deliveries),
                            React.createElement('div', { className: 'stat-label', key: 'label' }, 'Deliveries Today')
                        ])
                    ]),

                    React.createElement('div', { className: 'grid', key: 'grid' }, [
                        React.createElement('div', { className: 'card', key: 'form' }, [
                            React.createElement('h3', { key: 'title' }, 'Add New Webhook'),
                            React.createElement('form', { onSubmit: handleSubmit, key: 'form' }, [
                                React.createElement('div', { className: 'form-group', key: 'name' }, [
                                    React.createElement('label', { key: 'label' }, 'Name'),
                                    React.createElement('input', {
                                        key: 'input',
                                        className: 'form-control',
                                        type: 'text',
                                        value: formData.name,
                                        onChange: e => setFormData({...formData, name: e.target.value}),
                                        required: true
                                    })
                                ]),
                                React.createElement('div', { className: 'form-group', key: 'url' }, [
                                    React.createElement('label', { key: 'label' }, 'Webhook URL'),
                                    React.createElement('input', {
                                        key: 'input',
                                        className: 'form-control',
                                        type: 'url',
                                        value: formData.url,
                                        onChange: e => setFormData({...formData, url: e.target.value}),
                                        required: true
                                    })
                                ]),
                                React.createElement('div', { className: 'form-group', key: 'auth' }, [
                                    React.createElement('label', { key: 'label' }, 'Authentication'),
                                    React.createElement('select', {
                                        key: 'select',
                                        className: 'form-control',
                                        value: formData.auth_type,
                                        onChange: e => setFormData({...formData, auth_type: e.target.value})
                                    }, [
                                        React.createElement('option', { key: 'none', value: 'none' }, 'None'),
                                        React.createElement('option', { key: 'bearer', value: 'bearer' }, 'Bearer Token'),
                                        React.createElement('option', { key: 'api_key', value: 'api_key' }, 'API Key'),
                                        React.createElement('option', { key: 'hmac', value: 'hmac' }, 'HMAC Signature')
                                    ])
                                ]),
                                React.createElement('button', { 
                                    key: 'submit', 
                                    type: 'submit', 
                                    className: 'btn' 
                                }, 'Create Webhook')
                            ])
                        ]),

                        React.createElement('div', { className: 'card', key: 'list' }, [
                            React.createElement('div', { key: 'header', style: { display: 'flex', justifyContent: 'space-between', alignItems: 'center' } }, [
                                React.createElement('h3', { key: 'title' }, 'Active Webhooks'),
                                React.createElement('button', { 
                                    key: 'test', 
                                    className: 'btn', 
                                    onClick: testWebhook,
                                    style: { padding: '8px 16px', fontSize: '14px' }
                                }, 'Test All')
                            ]),
                            React.createElement('div', { className: 'webhook-list', key: 'list' }, 
                                webhooks.map(webhook => 
                                    React.createElement('div', { className: 'webhook-item', key: webhook.id }, [
                                        React.createElement('div', { className: 'webhook-info', key: 'info' }, [
                                            React.createElement('h4', { key: 'name' }, webhook.name),
                                            React.createElement('p', { key: 'url' }, webhook.url)
                                        ]),
                                        React.createElement('span', { 
                                            key: 'status',
                                            className: `status ${webhook.is_active ? 'status-active' : 'status-inactive'}`
                                        }, webhook.is_active ? 'Active' : 'Inactive')
                                    ])
                                )
                            )
                        ])
                    ])
                ]);
            }

            ReactDOM.render(React.createElement(Dashboard), document.getElementById('root'));
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.post("/api/webhooks")
async def create_webhook(webhook: WebhookEndpointCreate, db: Session = Depends(get_db)):
    """Create new webhook endpoint"""
    db_webhook = WebhookEndpoint(
        name=webhook.name,
        url=webhook.url,
        method=webhook.method,
        auth_type=webhook.auth_type,
        auth_config=webhook.auth_config,
        payload_template=webhook.payload_template,
        event_filters=webhook.event_filters
    )
    
    db.add(db_webhook)
    db.commit()
    db.refresh(db_webhook)
    
    return {"id": db_webhook.id, "message": "Webhook created successfully"}

@app.get("/api/webhooks")
async def get_webhooks(db: Session = Depends(get_db)):
    """Get all webhook endpoints"""
    webhooks = db.query(WebhookEndpoint).all()
    return [
        {
            "id": w.id,
            "name": w.name,
            "url": w.url,
            "method": w.method,
            "auth_type": w.auth_type,
            "is_active": w.is_active,
            "created_at": w.created_at.isoformat()
        }
        for w in webhooks
    ]

@app.get("/api/stats")
async def get_stats(db: Session = Depends(get_db)):
    """Get webhook system statistics"""
    from sqlalchemy import func
    from datetime import date
    
    total_webhooks = db.query(WebhookEndpoint).count()
    active_webhooks = db.query(WebhookEndpoint).filter(WebhookEndpoint.is_active == True).count()
    
    # Count deliveries today
    today = date.today()
    deliveries_today = db.query(WebhookDelivery).filter(
        func.date(WebhookDelivery.created_at) == today
    ).count()
    
    return {
        "total": total_webhooks,
        "active": active_webhooks,
        "deliveries": deliveries_today
    }

@app.post("/api/events")
async def process_event(event: LogEvent, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """Process incoming log event and trigger webhooks"""
    webhook_engine = WebhookEngine(db)
    
    event_data = {
        "type": event.type,
        "timestamp": event.timestamp,
        "level": event.level,
        "message": event.message,
        "source": event.source,
        "metadata": event.metadata
    }
    
    # Process event asynchronously
    background_tasks.add_task(webhook_engine.process_event, event_data)
    
    return {"status": "accepted", "message": "Event processing initiated"}

@app.post("/api/test-event")
async def send_test_event(event: LogEvent, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """Send test event to all active webhooks"""
    webhook_engine = WebhookEngine(db)
    
    event_data = {
        "type": event.type,
        "timestamp": event.timestamp,
        "level": event.level,
        "message": event.message,
        "source": event.source,
        "metadata": event.metadata
    }
    
    delivery_ids = await webhook_engine.process_event(event_data)
    
    return {
        "status": "success", 
        "message": f"Test event sent to {len(delivery_ids)} webhook(s)",
        "deliveries": delivery_ids
    }

@app.get("/api/deliveries")
async def get_deliveries(limit: int = 50, db: Session = Depends(get_db)):
    """Get recent webhook deliveries"""
    deliveries = db.query(WebhookDelivery).order_by(
        WebhookDelivery.created_at.desc()
    ).limit(limit).all()
    
    return [
        {
            "id": d.id,
            "endpoint_id": d.endpoint_id,
            "status": d.status,
            "response_code": d.response_code,
            "attempt_count": d.attempt_count,
            "created_at": d.created_at.isoformat(),
            "delivered_at": d.delivered_at.isoformat() if d.delivered_at else None
        }
        for d in deliveries
    ]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

echo "🧪 Creating comprehensive tests..."
cat > tests/unit/test_webhook_engine.py << 'EOF'
import pytest
import json
from datetime import datetime
from unittest.mock import Mock, AsyncMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from backend.src.models.webhook import Base, WebhookEndpoint, WebhookDelivery
from backend.src.core.webhook_engine import WebhookEngine

@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    return SessionLocal()

@pytest.fixture
def sample_endpoint(db_session):
    endpoint = WebhookEndpoint(
        name="Test Slack Webhook",
        url="https://hooks.slack.com/test",
        method="POST",
        auth_type="none",
        payload_template=json.dumps({
            "text": "Alert: {{message}}",
            "username": "Log Processor",
            "channel": "#alerts"
        }),
        event_filters=[
            {"field": "level", "operator": "equals", "value": "error"}
        ]
    )
    db_session.add(endpoint)
    db_session.commit()
    return endpoint

@pytest.mark.asyncio
async def test_webhook_creation_and_filtering(db_session, sample_endpoint):
    """Test webhook endpoint creation and event filtering"""
    engine = WebhookEngine(db_session)
    
    # Test matching event
    matching_event = {
        "type": "log_event",
        "timestamp": datetime.utcnow().isoformat(),
        "level": "error",
        "message": "Database connection failed",
        "source": "api_service"
    }
    
    delivery_ids = await engine.process_event(matching_event)
    assert len(delivery_ids) == 1
    
    # Test non-matching event
    non_matching_event = {
        "type": "log_event",
        "timestamp": datetime.utcnow().isoformat(),
        "level": "info",
        "message": "Request processed successfully",
        "source": "api_service"
    }
    
    delivery_ids = await engine.process_event(non_matching_event)
    assert len(delivery_ids) == 0

def test_filter_matching_logic(db_session):
    """Test event filter matching logic"""
    engine = WebhookEngine(db_session)
    
    event_data = {
        "level": "error",
        "response_time": 1500,
        "service": "payment-api"
    }
    
    # Test equals filter
    equals_filter = [{"field": "level", "operator": "equals", "value": "error"}]
    assert engine._matches_filters(event_data, equals_filter) == True
    
    # Test contains filter
    contains_filter = [{"field": "service", "operator": "contains", "value": "payment"}]
    assert engine._matches_filters(event_data, contains_filter) == True
    
    # Test greater_than filter
    gt_filter = [{"field": "response_time", "operator": "greater_than", "value": "1000"}]
    assert engine._matches_filters(event_data, gt_filter) == True

@pytest.mark.asyncio
async def test_payload_transformation(db_session, sample_endpoint):
    """Test webhook payload transformation"""
    engine = WebhookEngine(db_session)
    
    event_data = {
        "type": "error_event",
        "timestamp": "2025-05-20T10:30:00Z",
        "level": "error",
        "message": "Payment processing failed",
        "source": "payment_service",
        "metadata": {"user_id": "12345", "amount": 99.99}
    }
    
    delivery_id = await engine._create_delivery(sample_endpoint, event_data)
    
    # Verify delivery was created
    delivery = db_session.query(WebhookDelivery).filter(
        WebhookDelivery.id == delivery_id
    ).first()
    
    assert delivery is not None
    assert delivery.endpoint_id == sample_endpoint.id
    
    # Verify payload transformation
    payload = json.loads(delivery.payload)
    assert payload["text"] == "Alert: Payment processing failed"
    assert payload["username"] == "Log Processor"
    assert payload["channel"] == "#alerts"

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

cat > tests/integration/test_webhook_api.py << 'EOF'
import pytest
import json
import asyncio
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from backend.src.api.main import app, get_db
from backend.src.models.webhook import Base

@pytest.fixture
def test_db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    
    def get_test_db():
        db = SessionLocal()
        try:
            yield db
        finally:
            db.close()
    
    return get_test_db

@pytest.fixture
def client(test_db):
    app.dependency_overrides[get_db] = test_db
    yield TestClient(app)
    app.dependency_overrides.clear()

def test_create_webhook_endpoint(client):
    """Test webhook endpoint creation via API"""
    webhook_data = {
        "name": "Test Slack Integration",
        "url": "https://hooks.slack.com/services/test",
        "method": "POST",
        "auth_type": "none",
        "payload_template": json.dumps({
            "text": "{{message}}",
            "channel": "#alerts"
        }),
        "event_filters": [
            {"field": "level", "operator": "equals", "value": "error"}
        ]
    }
    
    response = client.post("/api/webhooks", json=webhook_data)
    assert response.status_code == 200
    assert "id" in response.json()

def test_get_webhooks(client):
    """Test webhook listing via API"""
    # First create a webhook
    webhook_data = {
        "name": "Test Webhook",
        "url": "https://example.com/webhook",
        "method": "POST",
        "auth_type": "none"
    }
    
    client.post("/api/webhooks", json=webhook_data)
    
    # Then list webhooks
    response = client.get("/api/webhooks")
    assert response.status_code == 200
    webhooks = response.json()
    assert len(webhooks) == 1
    assert webhooks[0]["name"] == "Test Webhook"

def test_webhook_stats(client):
    """Test webhook statistics endpoint"""
    response = client.get("/api/stats")
    assert response.status_code == 200
    
    stats = response.json()
    assert "total" in stats
    assert "active" in stats
    assert "deliveries" in stats

def test_process_event(client):
    """Test event processing via API"""
    # Create webhook first
    webhook_data = {
        "name": "Test Event Handler",
        "url": "https://httpbin.org/post",
        "method": "POST",
        "auth_type": "none",
        "event_filters": [
            {"field": "level", "operator": "equals", "value": "error"}
        ]
    }
    
    client.post("/api/webhooks", json=webhook_data)
    
    # Send test event
    event_data = {
        "type": "error_event",
        "timestamp": "2025-05-20T10:30:00Z",
        "level": "error",
        "message": "Test error message",
        "source": "test_service",
        "metadata": {"test": True}
    }
    
    response = client.post("/api/events", json=event_data)
    assert response.status_code == 200
    assert response.json()["status"] == "accepted"

def test_dashboard_endpoint(client):
    """Test dashboard HTML endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    assert "Webhook Integration Dashboard" in response.text

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

echo "🐳 Creating Docker configuration..."
cat > docker/backend/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY backend/ .

# Create necessary directories
RUN mkdir -p logs

EXPOSE 8000

CMD ["python", "src/api/main.py"]
EOF

cat > .dockerignore << 'EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
venv/
.venv/
pip-log.txt
pip-delete-this-directory.txt
.tox/
.coverage
.cache
nosetests.xml
coverage.xml
*.cover
*.log
.git
.mypy_cache
.pytest_cache
.hypothesis
.DS_Store
node_modules/
.env
*.db
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  webhook-backend:
    build:
      context: .
      dockerfile: docker/backend/Dockerfile
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=sqlite:///./webhook_system.db
      - REDIS_URL=redis://redis:6379
    volumes:
      - ./backend/logs:/app/logs
      - ./backend/webhook_system.db:/app/webhook_system.db
    depends_on:
      - redis
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    restart: unless-stopped

  # Test webhook receiver for demonstrations
  webhook-receiver:
    image: kennethreitz/httpbin:latest
    ports:
      - "8080:80"
    restart: unless-stopped
EOF

echo "🔨 Creating build scripts..."
cat > build.sh << 'EOF'
#!/bin/bash

set -e

echo "🏗️  Building Webhook Integration System..."

# Create and activate virtual environment
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install dependencies
echo "📦 Installing dependencies..."
pip install --upgrade pip
pip install -r backend/requirements.txt

# Run database migrations
echo "🗄️  Setting up database..."
cd backend
python -c "
from sqlalchemy import create_engine
from src.models.webhook import Base
from config.config import settings
engine = create_engine(settings.database_url)
Base.metadata.create_all(bind=engine)
print('Database initialized successfully')
"
cd ..

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v

echo "✅ Build completed successfully!"
echo "🚀 Run './start.sh' to start the system"
echo "📊 Dashboard available at: http://localhost:8000"
EOF

cat > start.sh << 'EOF'
#!/bin/bash

set -e

echo "🚀 Starting Webhook Integration System..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Run './build.sh' first."
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Start the backend server
echo "🌐 Starting webhook backend server..."
cd backend
uvicorn src.api.main:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
cd ..

echo "✅ System started successfully!"
echo "📊 Dashboard: http://localhost:8000"
echo "📡 API: http://localhost:8000/api"
echo "🧪 Test receiver: http://localhost:8080 (if using Docker)"

# Wait for user input to stop
echo "Press Ctrl+C to stop the system..."
trap "kill $BACKEND_PID 2>/dev/null; exit 0" INT
wait
EOF

cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Webhook Integration System..."

# Kill Python processes
pkill -f "python.*main.py" 2>/dev/null || true

# Stop Docker containers
docker-compose down 2>/dev/null || true

echo "✅ System stopped successfully!"
EOF

chmod +x build.sh start.sh stop.sh

echo "🧪 Running comprehensive tests..."
source venv/bin/activate
python -m pytest tests/ -v

echo "🚀 Starting system demonstration..."
cd backend
uvicorn src.api.main:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
cd ..

# Wait for server to start
sleep 3

# Create sample webhook endpoints
echo "📡 Creating sample webhook endpoints..."
curl -X POST http://localhost:8000/api/webhooks \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Slack Error Notifications",
    "url": "https://httpbin.org/post",
    "method": "POST",
    "auth_type": "none",
    "payload_template": "{\"text\": \"🚨 Error Alert: {{message}}\", \"channel\": \"#alerts\", \"username\": \"Log Processor\"}",
    "event_filters": [{"field": "level", "operator": "equals", "value": "error"}]
  }' || true

curl -X POST http://localhost:8000/api/webhooks \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Performance Monitoring",
    "url": "https://httpbin.org/post",
    "method": "POST",
    "auth_type": "none",
    "payload_template": "{\"metric\": \"response_time\", \"value\": \"{{metadata.response_time}}\", \"service\": \"{{source}}\"}",
    "event_filters": [{"field": "type", "operator": "equals", "value": "performance"}]
  }' || true

# Send test events
echo "📨 Sending test events..."
curl -X POST http://localhost:8000/api/events \
  -H "Content-Type: application/json" \
  -d '{
    "type": "log_event",
    "timestamp": "2025-05-20T10:30:00Z",
    "level": "error",
    "message": "Database connection timeout",
    "source": "api_service",
    "metadata": {"response_time": 5000, "user_id": "12345"}
  }' || true

curl -X POST http://localhost:8000/api/events \
  -H "Content-Type: application/json" \
  -d '{
    "type": "performance",
    "timestamp": "2025-05-20T10:31:00Z",
    "level": "info",
    "message": "High response time detected",
    "source": "payment_service",
    "metadata": {"response_time": 2500, "endpoint": "/api/payments"}
  }' || true

sleep 2

# Display webhook statistics
echo "📊 Current webhook statistics:"
curl -s http://localhost:8000/api/stats | python -m json.tool || true

echo ""
echo "✅ Webhook Integration System Demo Complete!"
echo "============================================="
echo "📊 Dashboard: http://localhost:8000"
echo "📡 API Documentation: http://localhost:8000/docs"
echo "🔧 Test Webhook Receiver: http://localhost:8080"
echo ""
echo "🎯 Key Features Demonstrated:"
echo "   ✅ Webhook endpoint registration"
echo "   ✅ Event filtering and routing"
echo "   ✅ Payload transformation"
echo "   ✅ Real-time delivery tracking"
echo "   ✅ Modern web dashboard"
echo "   ✅ RESTful API interface"
echo ""
echo "🚀 Next Steps:"
echo "   • Add authentication tokens for production"
echo "   • Configure retry policies for failed deliveries"
echo "   • Integrate with your log processing pipeline"
echo "   • Set up monitoring and alerting"
echo ""
echo "⚡ Pro Tip: Use './start.sh' for regular operation"
echo "🛑 Use './stop.sh' to cleanly stop the system"

# Clean up
kill $BACKEND_PID 2>/dev/null || true

echo ""
echo "🎉 Implementation completed successfully!"
echo "All files created and verified ✅"