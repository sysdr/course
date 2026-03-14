#!/bin/bash
# Day 129: Structured Logging Helpers Implementation Script
# Creates a complete structured logging system with validation and context injection

set -e  # Exit on any error

echo "🚀 Day 129: Building Structured Logging Helpers System"
echo "============================================================"

# Create project structure
echo "📁 Creating project structure..."
mkdir -p structured-logging-helpers/{src/{core,validators,serializers,context,web},tests,config,logs,docker}
cd structured-logging-helpers

# Create Python package files
touch src/__init__.py
touch src/core/__init__.py
touch src/validators/__init__.py
touch src/serializers/__init__.py
touch src/context/__init__.py
touch src/web/__init__.py
touch tests/__init__.py

echo "✅ Project structure created"

# Create requirements.txt with Python 3.11 compatible libraries
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
pydantic==2.5.0
jsonschema==4.20.0
structlog==23.2.0
python-multipart==0.0.6
aiofiles==23.2.1
pytest==7.4.3
pytest-asyncio==0.21.1
pytest-cov==4.1.0
requests==2.31.0
websockets==12.0
jinja2==3.1.2
typing-extensions==4.8.0
psutil==5.9.6
EOF

echo "📦 Requirements file created"

# Create virtual environment and install dependencies
python3 -m venv venv
source venv/bin/activate
echo "🐍 Virtual environment created and activated"

pip install --upgrade pip
pip install -r requirements.txt
echo "📦 Dependencies installed"

# Create core structured logging helper
cat > src/core/structured_logger.py << 'EOF'
"""Core structured logging helper with validation and context injection."""
import json
import time
import uuid
from typing import Dict, Any, Optional, List
from datetime import datetime, timezone
import asyncio
from dataclasses import dataclass, asdict
from enum import Enum


class LogLevel(Enum):
    DEBUG = "debug"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


@dataclass
class LogEntry:
    message: str
    level: LogLevel
    timestamp: str
    service_name: str
    trace_id: str
    fields: Dict[str, Any]
    context: Dict[str, Any]


class StructuredLogger:
    """High-performance structured logger with validation and context injection."""
    
    def __init__(self, service_name: str):
        self.service_name = service_name
        self.context_providers = []
        self.validators = []
        self.serialization_cache = {}
        
    def add_context_provider(self, provider):
        """Add automatic context injection."""
        self.context_providers.append(provider)
        
    def add_validator(self, validator):
        """Add field validation."""
        self.validators.append(validator)
        
    def _generate_trace_id(self) -> str:
        """Generate unique trace ID."""
        return str(uuid.uuid4())
        
    def _inject_context(self) -> Dict[str, Any]:
        """Inject context from all providers."""
        context = {}
        for provider in self.context_providers:
            try:
                provider_context = provider.get_context()
                context.update(provider_context)
            except Exception as e:
                # Context injection should never break logging
                context['context_error'] = str(e)
        return context
        
    def _validate_fields(self, fields: Dict[str, Any]) -> Dict[str, Any]:
        """Validate and normalize fields."""
        validated_fields = fields.copy()
        
        for validator in self.validators:
            try:
                validated_fields = validator.validate(validated_fields)
            except Exception as e:
                # Add validation error but don't fail
                validated_fields['validation_error'] = str(e)
                
        return validated_fields
        
    def _create_log_entry(self, level: LogLevel, message: str, **fields) -> LogEntry:
        """Create structured log entry with all processing."""
        timestamp = datetime.now(timezone.utc).isoformat()
        trace_id = fields.pop('trace_id', self._generate_trace_id())
        
        # Process fields through validators
        validated_fields = self._validate_fields(fields)
        
        # Inject context
        context = self._inject_context()
        
        return LogEntry(
            message=message,
            level=level,
            timestamp=timestamp,
            service_name=self.service_name,
            trace_id=trace_id,
            fields=validated_fields,
            context=context
        )
        
    def debug(self, message: str, **fields):
        """Log debug message."""
        return self._log(LogLevel.DEBUG, message, **fields)
        
    def info(self, message: str, **fields):
        """Log info message."""
        return self._log(LogLevel.INFO, message, **fields)
        
    def warning(self, message: str, **fields):
        """Log warning message."""
        return self._log(LogLevel.WARNING, message, **fields)
        
    def error(self, message: str, **fields):
        """Log error message."""
        return self._log(LogLevel.ERROR, message, **fields)
        
    def critical(self, message: str, **fields):
        """Log critical message."""
        return self._log(LogLevel.CRITICAL, message, **fields)
        
    def _log(self, level: LogLevel, message: str, **fields) -> LogEntry:
        """Internal logging method."""
        entry = self._create_log_entry(level, message, **fields)
        
        # Convert to JSON for output
        entry_dict = asdict(entry)
        entry_dict['level'] = entry.level.value
        
        # Print structured JSON
        print(json.dumps(entry_dict, indent=2))
        
        return entry


# Performance-optimized JSON serializer
class FastJSONSerializer:
    """High-performance JSON serialization for structured logs."""
    
    def __init__(self):
        self.template_cache = {}
        
    def serialize(self, log_entry: LogEntry) -> str:
        """Serialize log entry to JSON with caching optimization."""
        entry_dict = asdict(log_entry)
        entry_dict['level'] = log_entry.level.value
        
        # Use template caching for common log structures
        template_key = self._get_template_key(entry_dict)
        
        if template_key in self.template_cache:
            template = self.template_cache[template_key]
            return self._fill_template(template, entry_dict)
        else:
            json_str = json.dumps(entry_dict, separators=(',', ':'))
            self.template_cache[template_key] = json_str
            return json_str
            
    def _get_template_key(self, entry_dict: Dict) -> str:
        """Generate cache key for log structure."""
        field_keys = sorted(entry_dict.get('fields', {}).keys())
        context_keys = sorted(entry_dict.get('context', {}).keys())
        return f"{entry_dict['level']}:{','.join(field_keys)}:{','.join(context_keys)}"
        
    def _fill_template(self, template: str, data: Dict) -> str:
        """Fill template with actual data (simplified version)."""
        return json.dumps(data, separators=(',', ':'))
EOF

# Create field validators
cat > src/validators/field_validators.py << 'EOF'
"""Field validation system for structured logging."""
from typing import Dict, Any, Union, List
from datetime import datetime
import re


class FieldValidator:
    """Base class for field validators."""
    
    def validate(self, fields: Dict[str, Any]) -> Dict[str, Any]:
        """Validate and normalize fields."""
        raise NotImplementedError


class TypeValidator(FieldValidator):
    """Validates field types and converts when possible."""
    
    def __init__(self):
        self.type_rules = {
            'user_id': int,
            'amount': float,
            'email': str,
            'timestamp': str,
            'success': bool,
            'response_time': float,
            'status_code': int
        }
        
    def validate(self, fields: Dict[str, Any]) -> Dict[str, Any]:
        """Validate and convert field types."""
        validated = fields.copy()
        
        for field_name, field_value in fields.items():
            if field_name in self.type_rules:
                expected_type = self.type_rules[field_name]
                try:
                    validated[field_name] = expected_type(field_value)
                except (ValueError, TypeError):
                    validated[f"{field_name}_validation_error"] = f"Expected {expected_type.__name__}, got {type(field_value).__name__}"
                    
        return validated


class RequiredFieldsValidator(FieldValidator):
    """Ensures required fields are present."""
    
    def __init__(self, required_fields: List[str]):
        self.required_fields = required_fields
        
    def validate(self, fields: Dict[str, Any]) -> Dict[str, Any]:
        """Check for required fields."""
        validated = fields.copy()
        missing_fields = []
        
        for field in self.required_fields:
            if field not in fields or fields[field] is None:
                missing_fields.append(field)
                
        if missing_fields:
            validated['missing_required_fields'] = missing_fields
            
        return validated


class EmailValidator(FieldValidator):
    """Validates email field format."""
    
    def __init__(self):
        self.email_pattern = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        
    def validate(self, fields: Dict[str, Any]) -> Dict[str, Any]:
        """Validate email format."""
        validated = fields.copy()
        
        if 'email' in fields:
            email = fields['email']
            if isinstance(email, str) and not self.email_pattern.match(email):
                validated['email_validation_error'] = "Invalid email format"
                
        return validated


class RangeValidator(FieldValidator):
    """Validates numeric fields are within acceptable ranges."""
    
    def __init__(self):
        self.range_rules = {
            'amount': (0, 1000000),  # $0 to $1M
            'response_time': (0, 30),  # 0 to 30 seconds
            'status_code': (100, 599),  # HTTP status codes
            'age': (0, 150)  # Human age limits
        }
        
    def validate(self, fields: Dict[str, Any]) -> Dict[str, Any]:
        """Validate numeric ranges."""
        validated = fields.copy()
        
        for field_name, field_value in fields.items():
            if field_name in self.range_rules:
                min_val, max_val = self.range_rules[field_name]
                try:
                    numeric_value = float(field_value)
                    if not (min_val <= numeric_value <= max_val):
                        validated[f"{field_name}_range_error"] = f"Value {numeric_value} outside range [{min_val}, {max_val}]"
                except (ValueError, TypeError):
                    validated[f"{field_name}_type_error"] = f"Could not convert to numeric: {field_value}"
                    
        return validated


# Validator factory for easy setup
class ValidatorFactory:
    """Factory for creating common validator combinations."""
    
    @staticmethod
    def create_web_api_validators() -> List[FieldValidator]:
        """Create validators for web API logging."""
        return [
            TypeValidator(),
            RequiredFieldsValidator(['trace_id']),
            EmailValidator(),
            RangeValidator()
        ]
        
    @staticmethod
    def create_payment_validators() -> List[FieldValidator]:
        """Create validators for payment processing logs."""
        return [
            TypeValidator(),
            RequiredFieldsValidator(['user_id', 'amount', 'transaction_id']),
            RangeValidator()
        ]
        
    @staticmethod
    def create_user_activity_validators() -> List[FieldValidator]:
        """Create validators for user activity logs."""
        return [
            TypeValidator(),
            RequiredFieldsValidator(['user_id', 'action']),
            EmailValidator()
        ]
EOF

# Create context providers
cat > src/context/context_providers.py << 'EOF'
"""Context injection providers for automatic log enrichment."""
import os
import socket
import time
from typing import Dict, Any
from datetime import datetime
import threading


class ContextProvider:
    """Base class for context providers."""
    
    def get_context(self) -> Dict[str, Any]:
        """Return context dictionary."""
        raise NotImplementedError


class EnvironmentContextProvider(ContextProvider):
    """Provides environment-based context."""
    
    def __init__(self):
        self.static_context = {
            'hostname': socket.gethostname(),
            'pid': os.getpid(),
            'python_version': os.sys.version.split()[0]
        }
        
    def get_context(self) -> Dict[str, Any]:
        """Get environment context."""
        context = self.static_context.copy()
        context.update({
            'timestamp_ms': int(time.time() * 1000),
            'thread_id': threading.get_ident()
        })
        return context


class ApplicationContextProvider(ContextProvider):
    """Provides application-specific context."""
    
    def __init__(self, app_name: str, version: str, environment: str = "development"):
        self.app_context = {
            'app_name': app_name,
            'version': version,
            'environment': environment
        }
        
    def get_context(self) -> Dict[str, Any]:
        """Get application context."""
        return self.app_context.copy()


class RequestContextProvider(ContextProvider):
    """Provides HTTP request context (thread-local storage)."""
    
    def __init__(self):
        self.local = threading.local()
        
    def set_request_context(self, request_id: str, user_id: str = None, 
                          ip_address: str = None, user_agent: str = None):
        """Set request context for current thread."""
        self.local.request_context = {
            'request_id': request_id,
            'user_id': user_id,
            'ip_address': ip_address,
            'user_agent': user_agent
        }
        
    def get_context(self) -> Dict[str, Any]:
        """Get request context from thread-local storage."""
        if hasattr(self.local, 'request_context'):
            return {k: v for k, v in self.local.request_context.items() if v is not None}
        return {}
        
    def clear_context(self):
        """Clear request context."""
        if hasattr(self.local, 'request_context'):
            delattr(self.local, 'request_context')


class PerformanceContextProvider(ContextProvider):
    """Provides performance metrics context."""
    
    def __init__(self):
        self.start_time = time.time()
        
    def get_context(self) -> Dict[str, Any]:
        """Get performance context."""
        return {
            'uptime_seconds': int(time.time() - self.start_time),
            'memory_mb': self._get_memory_usage()
        }
        
    def _get_memory_usage(self) -> int:
        """Get current memory usage in MB."""
        try:
            import psutil
            process = psutil.Process(os.getpid())
            return int(process.memory_info().rss / 1024 / 1024)
        except ImportError:
            # Fallback if psutil not available
            return 0


# Context manager for easy setup
class ContextManager:
    """Manages multiple context providers."""
    
    def __init__(self):
        self.providers = []
        
    def add_provider(self, provider: ContextProvider):
        """Add a context provider."""
        self.providers.append(provider)
        
    def get_all_context(self) -> Dict[str, Any]:
        """Get combined context from all providers."""
        combined_context = {}
        
        for provider in self.providers:
            try:
                provider_context = provider.get_context()
                combined_context.update(provider_context)
            except Exception as e:
                combined_context['context_provider_error'] = str(e)
                
        return combined_context
        
    @classmethod
    def create_web_app_context(cls, app_name: str, version: str):
        """Create context manager for web applications."""
        manager = cls()
        manager.add_provider(EnvironmentContextProvider())
        manager.add_provider(ApplicationContextProvider(app_name, version))
        manager.add_provider(RequestContextProvider())
        manager.add_provider(PerformanceContextProvider())
        return manager
EOF

# Create web dashboard
cat > src/web/dashboard.py << 'EOF'
"""Real-time structured logging dashboard."""
from fastapi import FastAPI, WebSocket, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
import json
import asyncio
from typing import List, Dict, Any
import time
from datetime import datetime


class LoggingDashboard:
    """Real-time dashboard for structured logging helpers."""
    
    def __init__(self):
        self.app = FastAPI(title="Structured Logging Dashboard")
        self.active_connections: List[WebSocket] = []
        self.log_stats = {
            'total_logs': 0,
            'logs_by_level': {'debug': 0, 'info': 0, 'warning': 0, 'error': 0, 'critical': 0},
            'validation_errors': 0,
            'context_injections': 0,
            'serialization_cache_hits': 0
        }
        self.recent_logs = []
        self.setup_routes()
        
    def setup_routes(self):
        """Setup FastAPI routes."""
        
        @self.app.get("/", response_class=HTMLResponse)
        async def dashboard_home():
            return self.get_dashboard_html()
            
        @self.app.websocket("/ws")
        async def websocket_endpoint(websocket: WebSocket):
            await websocket.accept()
            self.active_connections.append(websocket)
            try:
                while True:
                    await websocket.receive_text()
            except:
                self.active_connections.remove(websocket)
                
        @self.app.get("/api/stats")
        async def get_stats():
            return self.log_stats
            
        @self.app.get("/api/logs")
        async def get_recent_logs():
            return self.recent_logs[-50:]  # Last 50 logs
            
        @self.app.post("/api/test-log")
        async def test_log(request: Request):
            data = await request.json()
            await self.process_test_log(data)
            return {"status": "processed"}
            
    async def process_test_log(self, log_data: Dict[str, Any]):
        """Process a test log entry."""
        self.log_stats['total_logs'] += 1
        
        level = log_data.get('level', 'info')
        if level in self.log_stats['logs_by_level']:
            self.log_stats['logs_by_level'][level] += 1
            
        # Check for validation errors
        if any('validation_error' in key for key in log_data.get('fields', {}).keys()):
            self.log_stats['validation_errors'] += 1
            
        # Check for context injection
        if log_data.get('context'):
            self.log_stats['context_injections'] += 1
            
        # Add to recent logs
        log_data['processed_at'] = datetime.now().isoformat()
        self.recent_logs.append(log_data)
        
        # Keep only last 100 logs
        if len(self.recent_logs) > 100:
            self.recent_logs = self.recent_logs[-100:]
            
        # Broadcast to connected clients
        await self.broadcast_update({
            'type': 'new_log',
            'log': log_data,
            'stats': self.log_stats
        })
        
    async def broadcast_update(self, message: Dict[str, Any]):
        """Broadcast update to all connected WebSocket clients."""
        if self.active_connections:
            message_json = json.dumps(message)
            disconnected = []
            
            for connection in self.active_connections:
                try:
                    await connection.send_text(message_json)
                except:
                    disconnected.append(connection)
                    
            # Remove disconnected clients
            for connection in disconnected:
                self.active_connections.remove(connection)
                
    def get_dashboard_html(self) -> str:
        """Return dashboard HTML."""
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Structured Logging Dashboard</title>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                
                body {
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    color: #333;
                }
                
                .container {
                    max-width: 1400px;
                    margin: 0 auto;
                    padding: 20px;
                }
                
                .header {
                    background: rgba(255, 255, 255, 0.95);
                    padding: 20px;
                    border-radius: 15px;
                    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                    margin-bottom: 20px;
                    backdrop-filter: blur(10px);
                }
                
                .header h1 {
                    color: #4a5568;
                    font-size: 2.5em;
                    font-weight: 700;
                    text-align: center;
                    margin-bottom: 10px;
                }
                
                .header p {
                    text-align: center;
                    color: #718096;
                    font-size: 1.1em;
                }
                
                .dashboard-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                    gap: 20px;
                    margin-bottom: 20px;
                }
                
                .card {
                    background: rgba(255, 255, 255, 0.95);
                    border-radius: 15px;
                    padding: 20px;
                    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                    backdrop-filter: blur(10px);
                    transition: transform 0.3s ease;
                }
                
                .card:hover {
                    transform: translateY(-5px);
                }
                
                .card h3 {
                    color: #4a5568;
                    margin-bottom: 15px;
                    font-size: 1.3em;
                    font-weight: 600;
                }
                
                .stat-grid {
                    display: grid;
                    grid-template-columns: repeat(2, 1fr);
                    gap: 15px;
                }
                
                .stat-item {
                    text-align: center;
                    padding: 15px;
                    background: linear-gradient(45deg, #f7fafc, #edf2f7);
                    border-radius: 10px;
                    border: 2px solid #e2e8f0;
                }
                
                .stat-value {
                    font-size: 2em;
                    font-weight: bold;
                    color: #2d3748;
                }
                
                .stat-label {
                    color: #718096;
                    font-size: 0.9em;
                    margin-top: 5px;
                }
                
                .log-entry {
                    background: #f8f9fa;
                    border-left: 4px solid #3182ce;
                    padding: 12px;
                    margin-bottom: 10px;
                    border-radius: 8px;
                    font-family: 'Courier New', monospace;
                    font-size: 0.9em;
                }
                
                .log-entry.error {
                    border-left-color: #e53e3e;
                    background: #fed7d7;
                }
                
                .log-entry.warning {
                    border-left-color: #d69e2e;
                    background: #fef5e7;
                }
                
                .test-panel {
                    background: rgba(255, 255, 255, 0.95);
                    border-radius: 15px;
                    padding: 20px;
                    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                }
                
                .test-buttons {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
                    gap: 10px;
                    margin-top: 15px;
                }
                
                .test-btn {
                    padding: 12px 20px;
                    border: none;
                    border-radius: 8px;
                    cursor: pointer;
                    font-weight: 600;
                    transition: all 0.3s ease;
                }
                
                .test-btn.info {
                    background: linear-gradient(45deg, #3182ce, #2c5282);
                    color: white;
                }
                
                .test-btn.warning {
                    background: linear-gradient(45deg, #d69e2e, #b7791f);
                    color: white;
                }
                
                .test-btn.error {
                    background: linear-gradient(45deg, #e53e3e, #c53030);
                    color: white;
                }
                
                .test-btn:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
                }
                
                .connection-status {
                    padding: 8px 15px;
                    border-radius: 20px;
                    font-size: 0.9em;
                    font-weight: 600;
                    display: inline-block;
                }
                
                .connected {
                    background: #c6f6d5;
                    color: #22543d;
                }
                
                .disconnected {
                    background: #fed7d7;
                    color: #742a2a;
                }
                
                .logs-container {
                    max-height: 400px;
                    overflow-y: auto;
                    background: #f8f9fa;
                    border-radius: 10px;
                    padding: 15px;
                }
                
                @keyframes pulse {
                    0% { transform: scale(1); }
                    50% { transform: scale(1.05); }
                    100% { transform: scale(1); }
                }
                
                .pulse {
                    animation: pulse 0.5s ease-in-out;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🔧 Structured Logging Dashboard</h1>
                    <p>Real-time monitoring of structured log processing with validation and context injection</p>
                    <div style="text-align: center; margin-top: 15px;">
                        <span id="connection-status" class="connection-status disconnected">⚠️ Connecting...</span>
                    </div>
                </div>
                
                <div class="dashboard-grid">
                    <div class="card">
                        <h3>📊 Processing Statistics</h3>
                        <div class="stat-grid">
                            <div class="stat-item">
                                <div class="stat-value" id="total-logs">0</div>
                                <div class="stat-label">Total Logs</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-value" id="validation-errors">0</div>
                                <div class="stat-label">Validation Errors</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-value" id="context-injections">0</div>
                                <div class="stat-label">Context Injections</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-value" id="cache-hits">0</div>
                                <div class="stat-label">Cache Hits</div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="card">
                        <h3>📈 Log Level Distribution</h3>
                        <div id="level-chart" style="height: 200px;"></div>
                    </div>
                </div>
                
                <div class="test-panel">
                    <h3>🧪 Test Structured Logging</h3>
                    <p>Generate test logs to see validation and context injection in action</p>
                    <div class="test-buttons">
                        <button class="test-btn info" onclick="sendTestLog('info')">📘 Info Log</button>
                        <button class="test-btn warning" onclick="sendTestLog('warning')">⚠️ Warning Log</button>
                        <button class="test-btn error" onclick="sendTestLog('error')">🚨 Error Log</button>
                        <button class="test-btn info" onclick="sendTestLog('validation')">🔍 Validation Test</button>
                    </div>
                </div>
                
                <div class="card" style="margin-top: 20px;">
                    <h3>📝 Recent Log Entries</h3>
                    <div id="logs-container" class="logs-container">
                        <p style="color: #718096; text-align: center; padding: 20px;">
                            No logs yet. Click the test buttons above to generate some!
                        </p>
                    </div>
                </div>
            </div>
            
            <script>
                let ws;
                let stats = {
                    total_logs: 0,
                    logs_by_level: {debug: 0, info: 0, warning: 0, error: 0, critical: 0},
                    validation_errors: 0,
                    context_injections: 0,
                    serialization_cache_hits: 0
                };
                
                function connectWebSocket() {
                    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                    ws = new WebSocket(`${protocol}//${window.location.host}/ws`);
                    
                    ws.onopen = function() {
                        document.getElementById('connection-status').className = 'connection-status connected';
                        document.getElementById('connection-status').textContent = '✅ Connected';
                    };
                    
                    ws.onclose = function() {
                        document.getElementById('connection-status').className = 'connection-status disconnected';
                        document.getElementById('connection-status').textContent = '❌ Disconnected';
                        setTimeout(connectWebSocket, 3000);
                    };
                    
                    ws.onmessage = function(event) {
                        const data = JSON.parse(event.data);
                        if (data.type === 'new_log') {
                            updateStats(data.stats);
                            addLogEntry(data.log);
                        }
                    };
                }
                
                function updateStats(newStats) {
                    stats = newStats;
                    document.getElementById('total-logs').textContent = stats.total_logs;
                    document.getElementById('validation-errors').textContent = stats.validation_errors;
                    document.getElementById('context-injections').textContent = stats.context_injections;
                    document.getElementById('cache-hits').textContent = stats.serialization_cache_hits;
                    
                    // Pulse effect on update
                    document.querySelector('.stat-grid').classList.add('pulse');
                    setTimeout(() => document.querySelector('.stat-grid').classList.remove('pulse'), 500);
                    
                    updateLevelChart();
                }
                
                function updateLevelChart() {
                    const levels = Object.keys(stats.logs_by_level);
                    const values = Object.values(stats.logs_by_level);
                    
                    const data = [{
                        x: levels,
                        y: values,
                        type: 'bar',
                        marker: {
                            color: ['#3182ce', '#38a169', '#d69e2e', '#e53e3e', '#9f7aea']
                        }
                    }];
                    
                    const layout = {
                        margin: { t: 10, r: 10, b: 30, l: 30 },
                        paper_bgcolor: 'rgba(0,0,0,0)',
                        plot_bgcolor: 'rgba(0,0,0,0)',
                        font: { size: 11 }
                    };
                    
                    Plotly.newPlot('level-chart', data, layout, {displayModeBar: false});
                }
                
                function addLogEntry(log) {
                    const container = document.getElementById('logs-container');
                    
                    // Clear "no logs" message
                    if (container.children.length === 1 && container.children[0].tagName === 'P') {
                        container.innerHTML = '';
                    }
                    
                    const entry = document.createElement('div');
                    entry.className = `log-entry ${log.level}`;
                    entry.innerHTML = `
                        <strong>${log.timestamp}</strong> [${log.level.toUpperCase()}] ${log.message}
                        <br><small>Service: ${log.service_name} | Trace: ${log.trace_id}</small>
                        ${log.fields && Object.keys(log.fields).length > 0 ? 
                            `<br><small>Fields: ${JSON.stringify(log.fields)}</small>` : ''}
                    `;
                    
                    container.insertBefore(entry, container.firstChild);
                    
                    // Keep only last 20 entries visible
                    while (container.children.length > 20) {
                        container.removeChild(container.lastChild);
                    }
                }
                
                async function sendTestLog(type) {
                    const testLogs = {
                        info: {
                            level: 'info',
                            message: 'User logged in successfully',
                            fields: {
                                user_id: 12345,
                                email: 'user@example.com',
                                ip_address: '192.168.1.100'
                            }
                        },
                        warning: {
                            level: 'warning',
                            message: 'High response time detected',
                            fields: {
                                response_time: 2.5,
                                endpoint: '/api/users',
                                status_code: 200
                            }
                        },
                        error: {
                            level: 'error',
                            message: 'Payment processing failed',
                            fields: {
                                user_id: 67890,
                                amount: 99.99,
                                error_code: 'CARD_DECLINED'
                            }
                        },
                        validation: {
                            level: 'info',
                            message: 'Test validation errors',
                            fields: {
                                user_id: 'invalid_id',  // Should be int
                                email: 'invalid-email',  // Invalid format
                                amount: -50,  // Invalid range
                                response_time: 999  // Out of range
                            }
                        }
                    };
                    
                    const logData = testLogs[type];
                    logData.service_name = 'test-service';
                    logData.trace_id = 'test-' + Date.now();
                    logData.timestamp = new Date().toISOString();
                    logData.context = {
                        hostname: 'localhost',
                        environment: 'development'
                    };
                    
                    try {
                        const response = await fetch('/api/test-log', {
                            method: 'POST',
                            headers: {'Content-Type': 'application/json'},
                            body: JSON.stringify(logData)
                        });
                        
                        if (!response.ok) {
                            console.error('Failed to send test log');
                        }
                    } catch (error) {
                        console.error('Error sending test log:', error);
                    }
                }
                
                // Initialize
                connectWebSocket();
                updateLevelChart();
            </script>
        </body>
        </html>
        """


# Create dashboard instance
dashboard = LoggingDashboard()
app = dashboard.app

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Create main application
cat > src/main.py << 'EOF'
"""Main application demonstrating structured logging helpers."""
import asyncio
import random
import time
from core.structured_logger import StructuredLogger, LogLevel
from validators.field_validators import ValidatorFactory
from context.context_providers import ContextManager, EnvironmentContextProvider, ApplicationContextProvider


class StructuredLoggingDemo:
    """Demonstration of structured logging helpers."""
    
    def __init__(self):
        # Create logger with service name
        self.logger = StructuredLogger("demo-service")
        
        # Setup validators
        validators = ValidatorFactory.create_web_api_validators()
        for validator in validators:
            self.logger.add_validator(validator)
            
        # Setup context providers
        context_manager = ContextManager.create_web_app_context("structured-logging-demo", "1.0.0")
        for provider in context_manager.providers:
            self.logger.add_context_provider(provider)
            
        print("🚀 Structured Logging Demo Initialized")
        print("=" * 50)
        
    def demonstrate_basic_logging(self):
        """Show basic structured logging."""
        print("\n📝 Basic Structured Logging:")
        print("-" * 30)
        
        self.logger.info("User authentication successful", 
                        user_id=12345, 
                        email="john.doe@example.com",
                        login_method="oauth")
                        
        self.logger.warning("High response time detected",
                           endpoint="/api/users",
                           response_time=2.5,
                           status_code=200)
                           
        self.logger.error("Payment processing failed",
                         user_id=67890,
                         amount=99.99,
                         error_code="INSUFFICIENT_FUNDS")
                         
    def demonstrate_validation(self):
        """Show field validation in action."""
        print("\n🔍 Field Validation Demo:")
        print("-" * 30)
        
        # Valid fields
        self.logger.info("Valid user registration",
                        user_id=12345,
                        email="valid@example.com",
                        amount=50.0)
                        
        # Invalid fields (will show validation errors)
        self.logger.info("Invalid field examples",
                        user_id="not_a_number",  # Should be int
                        email="invalid-email",   # Invalid format
                        amount=-100)             # Negative amount
                        
    def demonstrate_context_injection(self):
        """Show automatic context injection."""
        print("\n🎯 Context Injection Demo:")
        print("-" * 30)
        
        self.logger.info("Order processing started",
                        order_id="ORD-001",
                        customer_type="premium")
                        
        # Context is automatically injected (hostname, PID, etc.)
        
    def demonstrate_performance_logging(self):
        """Show performance-related logging."""
        print("\n⚡ Performance Logging Demo:")
        print("-" * 30)
        
        # Simulate API call timing
        start_time = time.time()
        time.sleep(0.1)  # Simulate work
        duration = time.time() - start_time
        
        self.logger.info("API call completed",
                        endpoint="/api/orders",
                        method="GET",
                        response_time=duration,
                        status_code=200,
                        response_size=1024)
                        
    def simulate_real_world_scenario(self):
        """Simulate a real-world application scenario."""
        print("\n🌍 Real-World Simulation:")
        print("-" * 30)
        
        scenarios = [
            {
                "action": "user_login",
                "level": "info",
                "fields": {"user_id": random.randint(1000, 9999), "success": True}
            },
            {
                "action": "payment_processed", 
                "level": "info",
                "fields": {"amount": round(random.uniform(10, 500), 2), "currency": "USD"}
            },
            {
                "action": "api_error",
                "level": "error", 
                "fields": {"status_code": 500, "error": "Database timeout"}
            },
            {
                "action": "cache_miss",
                "level": "warning",
                "fields": {"cache_key": f"user:{random.randint(1000, 9999)}", "ttl": 300}
            }
        ]
        
        for scenario in scenarios:
            if scenario["level"] == "info":
                self.logger.info(f"{scenario['action']} event", **scenario["fields"])
            elif scenario["level"] == "warning":
                self.logger.warning(f"{scenario['action']} event", **scenario["fields"])
            elif scenario["level"] == "error":
                self.logger.error(f"{scenario['action']} event", **scenario["fields"])
                
            time.sleep(0.5)  # Small delay between logs
            
    def run_comprehensive_demo(self):
        """Run all demonstrations."""
        print("🎬 Starting Comprehensive Structured Logging Demo")
        print("=" * 60)
        
        self.demonstrate_basic_logging()
        time.sleep(1)
        
        self.demonstrate_validation()
        time.sleep(1)
        
        self.demonstrate_context_injection()
        time.sleep(1)
        
        self.demonstrate_performance_logging()
        time.sleep(1)
        
        self.simulate_real_world_scenario()
        
        print("\n✅ Demo Complete!")
        print("=" * 60)


if __name__ == "__main__":
    demo = StructuredLoggingDemo()
    demo.run_comprehensive_demo()
EOF

# Create comprehensive tests
cat > tests/test_structured_logger.py << 'EOF'
"""Tests for structured logging helpers."""
import pytest
import json
from datetime import datetime
from src.core.structured_logger import StructuredLogger, LogLevel
from src.validators.field_validators import TypeValidator, EmailValidator, RequiredFieldsValidator
from src.context.context_providers import EnvironmentContextProvider, ApplicationContextProvider


class TestStructuredLogger:
    """Test structured logger functionality."""
    
    def setup_method(self):
        """Setup test logger."""
        self.logger = StructuredLogger("test-service")
        
    def test_basic_logging(self):
        """Test basic log creation."""
        entry = self.logger.info("Test message", user_id=123, action="login")
        
        assert entry.message == "Test message"
        assert entry.level == LogLevel.INFO
        assert entry.service_name == "test-service"
        assert entry.fields["user_id"] == 123
        assert entry.fields["action"] == "login"
        assert entry.trace_id is not None
        
    def test_log_levels(self):
        """Test all log levels."""
        debug_entry = self.logger.debug("Debug message")
        info_entry = self.logger.info("Info message")
        warning_entry = self.logger.warning("Warning message")
        error_entry = self.logger.error("Error message")
        critical_entry = self.logger.critical("Critical message")
        
        assert debug_entry.level == LogLevel.DEBUG
        assert info_entry.level == LogLevel.INFO
        assert warning_entry.level == LogLevel.WARNING
        assert error_entry.level == LogLevel.ERROR
        assert critical_entry.level == LogLevel.CRITICAL
        
    def test_context_injection(self):
        """Test automatic context injection."""
        # Add context provider
        env_provider = EnvironmentContextProvider()
        self.logger.add_context_provider(env_provider)
        
        entry = self.logger.info("Test with context")
        
        assert "hostname" in entry.context
        assert "pid" in entry.context
        assert "timestamp_ms" in entry.context
        
    def test_field_validation(self):
        """Test field validation."""
        # Add validators
        self.logger.add_validator(TypeValidator())
        self.logger.add_validator(EmailValidator())
        
        # Valid fields
        entry = self.logger.info("Valid test", user_id=123, email="test@example.com")
        assert entry.fields["user_id"] == 123
        assert entry.fields["email"] == "test@example.com"
        
        # Invalid fields
        entry = self.logger.info("Invalid test", user_id="not_a_number", email="invalid-email")
        assert "user_id_validation_error" in entry.fields
        assert "email_validation_error" in entry.fields


class TestFieldValidators:
    """Test field validation system."""
    
    def test_type_validator(self):
        """Test type validation and conversion."""
        validator = TypeValidator()
        
        # Valid conversion
        fields = {"user_id": "123", "amount": "45.67"}
        validated = validator.validate(fields)
        assert validated["user_id"] == 123
        assert validated["amount"] == 45.67
        
        # Invalid conversion
        fields = {"user_id": "not_a_number"}
        validated = validator.validate(fields)
        assert "user_id_validation_error" in validated
        
    def test_email_validator(self):
        """Test email format validation."""
        validator = EmailValidator()
        
        # Valid email
        fields = {"email": "test@example.com"}
        validated = validator.validate(fields)
        assert "email_validation_error" not in validated
        
        # Invalid email
        fields = {"email": "invalid-email"}
        validated = validator.validate(fields)
        assert "email_validation_error" in validated
        
    def test_required_fields_validator(self):
        """Test required fields validation."""
        validator = RequiredFieldsValidator(["user_id", "action"])
        
        # All required fields present
        fields = {"user_id": 123, "action": "login", "optional": "value"}
        validated = validator.validate(fields)
        assert "missing_required_fields" not in validated
        
        # Missing required fields
        fields = {"optional": "value"}
        validated = validator.validate(fields)
        assert "missing_required_fields" in validated
        assert validated["missing_required_fields"] == ["user_id", "action"]


class TestContextProviders:
    """Test context injection providers."""
    
    def test_environment_context_provider(self):
        """Test environment context."""
        provider = EnvironmentContextProvider()
        context = provider.get_context()
        
        assert "hostname" in context
        assert "pid" in context
        assert "python_version" in context
        assert "timestamp_ms" in context
        
    def test_application_context_provider(self):
        """Test application context."""
        provider = ApplicationContextProvider("test-app", "1.0.0", "production")
        context = provider.get_context()
        
        assert context["app_name"] == "test-app"
        assert context["version"] == "1.0.0"
        assert context["environment"] == "production"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create integration tests
cat > tests/test_integration.py << 'EOF'
"""Integration tests for structured logging system."""
import pytest
import asyncio
import json
from src.core.structured_logger import StructuredLogger
from src.validators.field_validators import ValidatorFactory
from src.context.context_providers import ContextManager


class TestIntegration:
    """Integration tests for complete system."""
    
    def setup_method(self):
        """Setup integrated system."""
        self.logger = StructuredLogger("integration-test-service")
        
        # Add validators
        validators = ValidatorFactory.create_web_api_validators()
        for validator in validators:
            self.logger.add_validator(validator)
            
        # Add context providers
        context_manager = ContextManager.create_web_app_context("integration-test", "1.0.0")
        for provider in context_manager.providers:
            self.logger.add_context_provider(provider)
            
    def test_complete_log_processing(self):
        """Test complete log processing pipeline."""
        entry = self.logger.info(
            "User performed action",
            user_id=12345,
            email="test@example.com",
            action="purchase",
            amount=99.99,
            trace_id="test-trace-123"
        )
        
        # Verify basic structure
        assert entry.message == "User performed action"
        assert entry.service_name == "integration-test-service"
        assert entry.trace_id == "test-trace-123"
        
        # Verify validated fields
        assert entry.fields["user_id"] == 12345
        assert entry.fields["email"] == "test@example.com"
        assert entry.fields["amount"] == 99.99
        
        # Verify context injection
        assert "hostname" in entry.context
        assert "app_name" in entry.context
        assert entry.context["app_name"] == "integration-test"
        
    def test_validation_error_handling(self):
        """Test handling of validation errors."""
        entry = self.logger.error(
            "Processing failed",
            user_id="invalid",  # Should be int
            email="bad-email",  # Invalid format
            amount=-50          # Invalid range
        )
        
        # Should contain validation errors but not break logging
        assert "user_id_validation_error" in entry.fields
        assert "email_validation_error" in entry.fields
        assert "amount_range_error" in entry.fields
        
    def test_high_volume_logging(self):
        """Test performance under high volume."""
        import time
        
        start_time = time.time()
        num_logs = 100
        
        for i in range(num_logs):
            self.logger.info(
                f"High volume test {i}",
                iteration=i,
                user_id=i + 1000,
                action="test"
            )
            
        end_time = time.time()
        duration = end_time - start_time
        logs_per_second = num_logs / duration
        
        # Should handle at least 50 logs per second
        assert logs_per_second > 50
        print(f"Performance: {logs_per_second:.1f} logs/second")
        
    def test_context_provider_failure_handling(self):
        """Test graceful handling of context provider failures."""
        class FailingContextProvider:
            def get_context(self):
                raise Exception("Context provider failed")
                
        self.logger.add_context_provider(FailingContextProvider())
        
        # Should still log successfully
        entry = self.logger.info("Test with failing context provider")
        
        # Should contain error information
        assert "context_error" in entry.context
        
    def test_serialization_performance(self):
        """Test JSON serialization performance."""
        from src.core.structured_logger import FastJSONSerializer
        
        serializer = FastJSONSerializer()
        
        # Create test log entry
        entry = self.logger.info(
            "Serialization test",
            user_id=12345,
            data={"complex": {"nested": "structure"}},
            items=[1, 2, 3, 4, 5]
        )
        
        import time
        start_time = time.time()
        
        # Serialize 1000 times
        for _ in range(1000):
            json_str = serializer.serialize(entry)
            
        end_time = time.time()
        duration = end_time - start_time
        
        # Should be fast
        assert duration < 1.0  # Less than 1 second for 1000 serializations
        print(f"Serialization performance: {1000/duration:.1f} ops/second")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create performance tests
cat > tests/test_performance.py << 'EOF'
"""Performance tests for structured logging system."""
import pytest
import time
import threading
from concurrent.futures import ThreadPoolExecutor
from src.core.structured_logger import StructuredLogger
from src.validators.field_validators import ValidatorFactory


class TestPerformance:
    """Performance benchmarks for structured logging."""
    
    def setup_method(self):
        """Setup performance test environment."""
        self.logger = StructuredLogger("performance-test")
        
        # Add realistic validators
        validators = ValidatorFactory.create_web_api_validators()
        for validator in validators:
            self.logger.add_validator(validator)
            
    def test_single_thread_throughput(self):
        """Measure single-thread logging throughput."""
        num_logs = 1000
        start_time = time.time()
        
        for i in range(num_logs):
            self.logger.info(
                f"Performance test log {i}",
                user_id=i,
                action="test",
                timestamp=time.time()
            )
            
        end_time = time.time()
        duration = end_time - start_time
        throughput = num_logs / duration
        
        print(f"Single-thread throughput: {throughput:.1f} logs/second")
        assert throughput > 100  # Should handle at least 100 logs/second
        
    def test_multi_thread_throughput(self):
        """Measure multi-thread logging throughput."""
        num_threads = 4
        logs_per_thread = 250
        total_logs = num_threads * logs_per_thread
        
        def log_worker(thread_id):
            for i in range(logs_per_thread):
                self.logger.info(
                    f"Multi-thread test from thread {thread_id}",
                    thread_id=thread_id,
                    iteration=i,
                    user_id=thread_id * 1000 + i
                )
                
        start_time = time.time()
        
        with ThreadPoolExecutor(max_workers=num_threads) as executor:
            futures = [executor.submit(log_worker, i) for i in range(num_threads)]
            for future in futures:
                future.result()
                
        end_time = time.time()
        duration = end_time - start_time
        throughput = total_logs / duration
        
        print(f"Multi-thread throughput: {throughput:.1f} logs/second")
        assert throughput > 200  # Should handle at least 200 logs/second with 4 threads
        
    def test_memory_usage(self):
        """Test memory usage during high-volume logging."""
        import psutil
        import os
        
        process = psutil.Process(os.getpid())
        initial_memory = process.memory_info().rss
        
        # Generate many logs
        for i in range(5000):
            self.logger.info(
                f"Memory test log {i}",
                user_id=i,
                data={"key": f"value_{i}"},
                large_field="x" * 100  # Some larger data
            )
            
        final_memory = process.memory_info().rss
        memory_increase = final_memory - initial_memory
        
        print(f"Memory increase: {memory_increase / 1024 / 1024:.1f} MB for 5000 logs")
        # Should not use excessive memory (less than 50MB increase)
        assert memory_increase < 50 * 1024 * 1024
        
    def test_validation_overhead(self):
        """Measure overhead of field validation."""
        # Test without validation
        logger_no_validation = StructuredLogger("no-validation")
        
        num_logs = 1000
        
        # Time without validation
        start_time = time.time()
        for i in range(num_logs):
            logger_no_validation.info("Test", user_id=i, email=f"user{i}@example.com")
        no_validation_time = time.time() - start_time
        
        # Time with validation
        start_time = time.time()
        for i in range(num_logs):
            self.logger.info("Test", user_id=i, email=f"user{i}@example.com")
        validation_time = time.time() - start_time
        
        overhead_percent = ((validation_time - no_validation_time) / no_validation_time) * 100
        
        print(f"Validation overhead: {overhead_percent:.1f}%")
        # Validation should add less than 100% overhead
        assert overhead_percent < 100


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create Docker configuration
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY tests/ ./tests/
COPY config/ ./config/

# Create logs directory
RUN mkdir -p logs

# Expose web dashboard port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/api/stats || exit 1

# Default command
CMD ["python", "-m", "src.web.dashboard"]
EOF

# Create Docker Compose
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  structured-logging:
    build: .
    ports:
      - "8000:8000"
    environment:
      - PYTHONPATH=/app
    volumes:
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/stats"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
EOF

# Create Docker ignore
cat > .dockerignore << 'EOF'
venv/
__pycache__/
*.pyc
*.pyo
*.pyd
.pytest_cache/
.coverage
.git/
README.md
build.sh
start.sh
stop.sh
EOF

# Create build script
cat > build.sh << 'EOF'
#!/bin/bash
# Build script for structured logging helpers

echo "🔨 Building Structured Logging Helpers System"
echo "=============================================="

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "📦 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v --tb=short

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Tests failed!"
    exit 1
fi

# Build documentation
echo "📚 Generating documentation..."
python -c "
from src.core.structured_logger import StructuredLogger
from src.validators.field_validators import ValidatorFactory
print('✅ Core modules imported successfully')
"

echo "🎉 Build completed successfully!"
EOF

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash
# Start script for structured logging helpers

echo "🚀 Starting Structured Logging Helpers System"
echo "=============================================="

# Activate virtual environment
source venv/bin/activate

# Set Python path
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Start web dashboard in background
echo "🌐 Starting web dashboard..."
python src/web/dashboard.py &
DASHBOARD_PID=$!

# Wait for dashboard to start
sleep 3

# Run demonstration
echo "🎬 Running demonstration..."
python src/main.py

echo ""
echo "🌐 Web Dashboard: http://localhost:8000"
echo "📊 Dashboard PID: $DASHBOARD_PID"
echo ""
echo "Use 'kill $DASHBOARD_PID' to stop the dashboard"
echo "Or run: ./stop.sh"
EOF

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash
# Stop script for structured logging helpers

echo "🛑 Stopping Structured Logging Helpers System"
echo "============================================="

# Kill any Python processes on port 8000
PIDS=$(lsof -ti:8000)
if [ ! -z "$PIDS" ]; then
    echo "🔪 Stopping dashboard processes..."
    kill $PIDS
    echo "✅ Dashboard stopped"
else
    echo "ℹ️  No dashboard processes found"
fi

# Kill any remaining demo processes
pkill -f "src/main.py" 2>/dev/null || true

echo "✅ All processes stopped"
EOF

# Make scripts executable
chmod +x build.sh start.sh stop.sh

echo "🔨 Running build process..."
./build.sh

echo ""
echo "🎉 Build completed successfully!"
echo ""
echo "🚀 To start the system:"
echo "   ./start.sh"
echo ""
echo "🌐 To access the web dashboard:"
echo "   http://localhost:8000"
echo ""
echo "🧪 To run tests:"
echo "   source venv/bin/activate && python -m pytest tests/ -v"
echo ""
echo "🐳 To run with Docker:"
echo "   docker-compose up --build"
echo ""
echo "🛑 To stop the system:"
echo "   ./stop.sh"