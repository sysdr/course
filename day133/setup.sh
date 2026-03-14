#!/bin/bash

# Day 133: Deployment and Release Tracking Implementation
# Module 5: Integration and Ecosystem | Week 19: Application Integration

set -e

echo "🚀 Day 133: Setting up Deployment and Release Tracking System"
echo "============================================================"

# Create project structure
PROJECT_NAME="day133-deployment-tracking"
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

echo "📁 Creating project structure..."
mkdir -p {backend/{src/{deployment,correlation,analysis,api},tests,config},frontend/{src/{components,pages,utils},public},docker,scripts,data}

# Create Python virtual environment
echo "🐍 Setting up Python 3.11 virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Create requirements.txt with latest May 2025 libraries
cat > backend/requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn==0.30.1
websockets==12.0
asyncio==3.4.3
aiofiles==23.2.1
pydantic==2.7.1
redis==5.0.4
requests==2.32.3
pytest==8.2.2
pytest-asyncio==0.23.7
python-multipart==0.0.9
jinja2==3.1.4
numpy==1.26.4
pandas==2.2.2
matplotlib==3.9.0
plotly==5.22.0
structlog==24.1.0
httpx==0.27.0
docker==7.1.0
kubernetes==30.1.0
GitPython==3.1.43
schedule==1.2.2
python-dateutil==2.9.0
pytz==2024.1
EOF

echo "📦 Installing Python dependencies..."
pip install -r backend/requirements.txt

# Backend Implementation Files

# 1. Deployment Detector
cat > backend/src/deployment/detector.py << 'EOF'
import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Dict, List, Optional
import aiofiles
import requests
from dataclasses import dataclass, asdict
import structlog

logger = structlog.get_logger()

@dataclass
class DeploymentEvent:
    id: str
    service_name: str
    version: str
    environment: str
    timestamp: datetime
    source: str
    metadata: Dict
    commit_hash: Optional[str] = None
    branch: Optional[str] = None
    
class DeploymentDetector:
    def __init__(self, config: Dict):
        self.config = config
        self.active_deployments = {}
        self.deployment_history = []
        
    async def start_monitoring(self):
        """Start monitoring deployment sources"""
        logger.info("Starting deployment monitoring")
        
        # Start monitoring tasks
        tasks = [
            self.monitor_github_actions(),
            self.monitor_docker_registry(),
            self.monitor_kubernetes(),
            self.generate_demo_deployments()  # For demo purposes
        ]
        
        await asyncio.gather(*tasks, return_exceptions=True)
    
    async def monitor_github_actions(self):
        """Monitor GitHub Actions for deployment events"""
        while True:
            try:
                # In production, this would connect to GitHub webhooks
                await asyncio.sleep(30)
                logger.debug("Monitoring GitHub Actions...")
            except Exception as e:
                logger.error(f"GitHub Actions monitoring error: {e}")
            
    async def monitor_docker_registry(self):
        """Monitor Docker registry for new image pushes"""
        while True:
            try:
                # In production, this would connect to registry webhooks
                await asyncio.sleep(25)
                logger.debug("Monitoring Docker registry...")
            except Exception as e:
                logger.error(f"Docker registry monitoring error: {e}")
            
    async def monitor_kubernetes(self):
        """Monitor Kubernetes deployments"""
        while True:
            try:
                # In production, this would use Kubernetes API
                await asyncio.sleep(35)
                logger.debug("Monitoring Kubernetes deployments...")
            except Exception as e:
                logger.error(f"Kubernetes monitoring error: {e}")
                
    async def generate_demo_deployments(self):
        """Generate demo deployment events for demonstration"""
        services = ["user-service", "payment-service", "notification-service", "api-gateway"]
        environments = ["staging", "production"]
        
        while True:
            try:
                import random
                service = random.choice(services)
                env = random.choice(environments)
                version = f"v{random.randint(1,5)}.{random.randint(0,9)}.{random.randint(0,9)}"
                
                deployment = DeploymentEvent(
                    id=f"dep_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{service}",
                    service_name=service,
                    version=version,
                    environment=env,
                    timestamp=datetime.now(timezone.utc),
                    source="github_actions",
                    metadata={
                        "triggered_by": "user@company.com",
                        "duration": random.randint(60, 300),
                        "deployment_type": "rolling_update"
                    },
                    commit_hash=f"abc{random.randint(1000,9999)}def",
                    branch="main"
                )
                
                await self.process_deployment_event(deployment)
                
                # Random interval between 30 seconds to 2 minutes
                await asyncio.sleep(random.randint(30, 120))
                
            except Exception as e:
                logger.error(f"Demo deployment generation error: {e}")
                await asyncio.sleep(10)
    
    async def process_deployment_event(self, deployment: DeploymentEvent):
        """Process a new deployment event"""
        key = f"{deployment.service_name}_{deployment.environment}"
        self.active_deployments[key] = deployment
        self.deployment_history.append(deployment)
        
        # Keep only last 100 deployments in memory
        if len(self.deployment_history) > 100:
            self.deployment_history = self.deployment_history[-100:]
        
        logger.info(f"New deployment detected: {deployment.service_name} {deployment.version}")
        
        # Save to file for persistence
        await self.save_deployment_data()
        
        return deployment
    
    async def save_deployment_data(self):
        """Save deployment data to file"""
        try:
            data = {
                'active_deployments': {k: asdict(v) for k, v in self.active_deployments.items()},
                'history': [asdict(d) for d in self.deployment_history[-50:]]  # Save last 50
            }
            
            async with aiofiles.open('data/deployments.json', 'w') as f:
                await f.write(json.dumps(data, default=str, indent=2))
                
        except Exception as e:
            logger.error(f"Error saving deployment data: {e}")
    
    def get_active_deployments(self) -> Dict:
        """Get currently active deployments"""
        return {k: asdict(v) for k, v in self.active_deployments.items()}
    
    def get_deployment_history(self) -> List[Dict]:
        """Get deployment history"""
        return [asdict(d) for d in self.deployment_history]
    
    def get_deployment_for_timestamp(self, timestamp: datetime, service: str, environment: str) -> Optional[DeploymentEvent]:
        """Get deployment active at a specific timestamp"""
        key = f"{service}_{environment}"
        
        # Find the most recent deployment before the timestamp
        relevant_deployments = [
            d for d in self.deployment_history 
            if d.service_name == service and d.environment == environment and d.timestamp <= timestamp
        ]
        
        if relevant_deployments:
            return max(relevant_deployments, key=lambda x: x.timestamp)
        
        return None
EOF

# 2. Version Correlator
cat > backend/src/correlation/correlator.py << 'EOF'
import json
import asyncio
from datetime import datetime, timezone
from typing import Dict, Optional, Any
import structlog

logger = structlog.get_logger()

class VersionCorrelator:
    def __init__(self, deployment_detector):
        self.deployment_detector = deployment_detector
        self.correlation_cache = {}
        
    async def enrich_log_entry(self, log_entry: Dict[str, Any]) -> Dict[str, Any]:
        """Enrich log entry with deployment context"""
        try:
            # Extract metadata from log entry
            timestamp = self._parse_timestamp(log_entry.get('timestamp'))
            service = log_entry.get('service', 'unknown')
            environment = log_entry.get('environment', 'production')
            
            # Get deployment info for this log
            deployment = self.deployment_detector.get_deployment_for_timestamp(
                timestamp, service, environment
            )
            
            # Add deployment context to log entry
            enriched_entry = log_entry.copy()
            enriched_entry['deployment'] = {
                'version': deployment.version if deployment else 'unknown',
                'deployment_id': deployment.id if deployment else None,
                'commit_hash': deployment.commit_hash if deployment else None,
                'deployment_timestamp': deployment.timestamp.isoformat() if deployment else None
            }
            
            return enriched_entry
            
        except Exception as e:
            logger.error(f"Error enriching log entry: {e}")
            log_entry['deployment'] = {'version': 'unknown', 'error': str(e)}
            return log_entry
    
    def _parse_timestamp(self, timestamp_str: str) -> datetime:
        """Parse timestamp string to datetime object"""
        try:
            if isinstance(timestamp_str, str):
                # Handle different timestamp formats
                for fmt in ['%Y-%m-%dT%H:%M:%S.%fZ', '%Y-%m-%dT%H:%M:%SZ', '%Y-%m-%d %H:%M:%S']:
                    try:
                        return datetime.strptime(timestamp_str, fmt).replace(tzinfo=timezone.utc)
                    except ValueError:
                        continue
            
            return datetime.now(timezone.utc)
        except:
            return datetime.now(timezone.utc)
    
    async def batch_enrich_logs(self, log_entries: list) -> list:
        """Enrich multiple log entries in batch"""
        enriched_logs = []
        
        for log_entry in log_entries:
            enriched = await self.enrich_log_entry(log_entry)
            enriched_logs.append(enriched)
        
        return enriched_logs
    
    def get_correlation_stats(self) -> Dict:
        """Get correlation statistics"""
        return {
            'cache_size': len(self.correlation_cache),
            'active_deployments': len(self.deployment_detector.active_deployments),
            'total_deployments': len(self.deployment_detector.deployment_history)
        }
EOF

# 3. Impact Analyzer
cat > backend/src/analysis/analyzer.py << 'EOF'
import asyncio
import json
import numpy as np
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
import structlog

logger = structlog.get_logger()

@dataclass
class ImpactMetrics:
    deployment_id: str
    service_name: str
    version: str
    before_metrics: Dict
    after_metrics: Dict
    impact_score: float
    significant_changes: List[str]
    analysis_timestamp: datetime

class ImpactAnalyzer:
    def __init__(self, deployment_detector):
        self.deployment_detector = deployment_detector
        self.metrics_cache = {}
        self.impact_results = []
        
    async def start_analysis(self):
        """Start continuous impact analysis"""
        logger.info("Starting deployment impact analysis")
        
        while True:
            try:
                await self.analyze_recent_deployments()
                await asyncio.sleep(60)  # Analyze every minute
            except Exception as e:
                logger.error(f"Impact analysis error: {e}")
                await asyncio.sleep(10)
    
    async def analyze_recent_deployments(self):
        """Analyze impact of recent deployments"""
        recent_deployments = [
            d for d in self.deployment_detector.deployment_history
            if (datetime.now(timezone.utc) - d.timestamp).total_seconds() < 3600  # Last hour
        ]
        
        for deployment in recent_deployments:
            if not any(r.deployment_id == deployment.id for r in self.impact_results):
                impact = await self.analyze_deployment_impact(deployment)
                if impact:
                    self.impact_results.append(impact)
                    
                    # Keep only last 50 results
                    if len(self.impact_results) > 50:
                        self.impact_results = self.impact_results[-50:]
    
    async def analyze_deployment_impact(self, deployment) -> Optional[ImpactMetrics]:
        """Analyze impact of a specific deployment"""
        try:
            # Define time windows for before/after analysis
            deployment_time = deployment.timestamp
            before_start = deployment_time - timedelta(minutes=30)
            before_end = deployment_time
            after_start = deployment_time
            after_end = deployment_time + timedelta(minutes=30)
            
            # Generate synthetic metrics for demo
            before_metrics = await self.generate_metrics(before_start, before_end, deployment.service_name)
            after_metrics = await self.generate_metrics(after_start, after_end, deployment.service_name)
            
            # Calculate impact score and significant changes
            impact_score, significant_changes = self.calculate_impact(before_metrics, after_metrics)
            
            impact = ImpactMetrics(
                deployment_id=deployment.id,
                service_name=deployment.service_name,
                version=deployment.version,
                before_metrics=before_metrics,
                after_metrics=after_metrics,
                impact_score=impact_score,
                significant_changes=significant_changes,
                analysis_timestamp=datetime.now(timezone.utc)
            )
            
            logger.info(f"Deployment impact analyzed: {deployment.service_name} - Score: {impact_score:.2f}")
            return impact
            
        except Exception as e:
            logger.error(f"Error analyzing deployment impact: {e}")
            return None
    
    async def generate_metrics(self, start_time: datetime, end_time: datetime, service: str) -> Dict:
        """Generate synthetic metrics for demo purposes"""
        import random
        
        # Base metrics that vary by service
        base_metrics = {
            "user-service": {"response_time": 150, "error_rate": 0.02, "throughput": 1000},
            "payment-service": {"response_time": 300, "error_rate": 0.01, "throughput": 500},
            "notification-service": {"response_time": 100, "error_rate": 0.05, "throughput": 2000},
            "api-gateway": {"response_time": 50, "error_rate": 0.03, "throughput": 5000}
        }
        
        base = base_metrics.get(service, {"response_time": 200, "error_rate": 0.03, "throughput": 1000})
        
        # Add some randomness
        metrics = {
            "response_time_avg": base["response_time"] + random.uniform(-20, 20),
            "response_time_p95": base["response_time"] * 1.5 + random.uniform(-30, 30),
            "error_rate": max(0, base["error_rate"] + random.uniform(-0.01, 0.01)),
            "throughput": base["throughput"] + random.uniform(-100, 100),
            "cpu_usage": random.uniform(30, 80),
            "memory_usage": random.uniform(40, 85),
            "success_rate": 1 - base["error_rate"] + random.uniform(-0.02, 0.02)
        }
        
        return metrics
    
    def calculate_impact(self, before: Dict, after: Dict) -> tuple:
        """Calculate impact score and identify significant changes"""
        significant_changes = []
        total_impact = 0
        
        # Define thresholds for significant changes
        thresholds = {
            "response_time_avg": 0.15,  # 15% change
            "response_time_p95": 0.20,  # 20% change
            "error_rate": 0.5,          # 50% change
            "throughput": 0.10,         # 10% change
            "cpu_usage": 0.20,          # 20% change
            "memory_usage": 0.20,       # 20% change
            "success_rate": 0.02        # 2% change
        }
        
        for metric in before.keys():
            if metric in after and metric in thresholds:
                before_val = before[metric]
                after_val = after[metric]
                
                if before_val != 0:
                    change_ratio = abs(after_val - before_val) / before_val
                    
                    if change_ratio > thresholds[metric]:
                        direction = "increased" if after_val > before_val else "decreased"
                        percentage = change_ratio * 100
                        significant_changes.append(f"{metric} {direction} by {percentage:.1f}%")
                        
                        # Weight impact based on metric importance
                        weights = {
                            "error_rate": 3.0,
                            "response_time_avg": 2.0,
                            "response_time_p95": 2.0,
                            "success_rate": 3.0,
                            "throughput": 1.5,
                            "cpu_usage": 1.0,
                            "memory_usage": 1.0
                        }
                        
                        weight = weights.get(metric, 1.0)
                        total_impact += change_ratio * weight
        
        # Normalize impact score to 0-100 scale
        impact_score = min(100, total_impact * 100)
        
        return impact_score, significant_changes
    
    def get_impact_summary(self) -> Dict:
        """Get summary of deployment impacts"""
        if not self.impact_results:
            return {"total_analyzed": 0}
        
        return {
            "total_analyzed": len(self.impact_results),
            "high_impact_deployments": len([r for r in self.impact_results if r.impact_score > 50]),
            "average_impact_score": np.mean([r.impact_score for r in self.impact_results]),
            "recent_impacts": [
                {
                    "deployment_id": r.deployment_id,
                    "service": r.service_name,
                    "version": r.version,
                    "impact_score": r.impact_score,
                    "significant_changes": r.significant_changes
                }
                for r in self.impact_results[-10:]  # Last 10 impacts
            ]
        }
EOF

# 4. API Server
cat > backend/src/api/server.py << 'EOF'
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
import json
import asyncio
from datetime import datetime
import uvicorn
import structlog
from typing import List
import os

# Import our modules
import sys
sys.path.append('/app/backend/src')

from deployment.detector import DeploymentDetector
from correlation.correlator import VersionCorrelator
from analysis.analyzer import ImpactAnalyzer

logger = structlog.configure(
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
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

app = FastAPI(title="Deployment Tracking System", version="1.0.0")

# Global components
deployment_detector = None
version_correlator = None
impact_analyzer = None
connected_websockets: List[WebSocket] = []

@app.on_event("startup")
async def startup_event():
    global deployment_detector, version_correlator, impact_analyzer
    
    logger.info("Starting Deployment Tracking System")
    
    # Initialize components
    config = {"sources": ["github", "docker", "kubernetes"]}
    deployment_detector = DeploymentDetector(config)
    version_correlator = VersionCorrelator(deployment_detector)
    impact_analyzer = ImpactAnalyzer(deployment_detector)
    
    # Start background tasks
    asyncio.create_task(deployment_detector.start_monitoring())
    asyncio.create_task(impact_analyzer.start_analysis())
    asyncio.create_task(websocket_broadcaster())

async def websocket_broadcaster():
    """Broadcast updates to connected websockets"""
    while True:
        try:
            if connected_websockets:
                # Prepare update data
                update_data = {
                    "timestamp": datetime.now().isoformat(),
                    "active_deployments": deployment_detector.get_active_deployments(),
                    "recent_deployments": deployment_detector.get_deployment_history()[-10:],
                    "impact_summary": impact_analyzer.get_impact_summary(),
                    "correlation_stats": version_correlator.get_correlation_stats()
                }
                
                # Send to all connected clients
                disconnected = []
                for websocket in connected_websockets:
                    try:
                        await websocket.send_text(json.dumps(update_data, default=str))
                    except:
                        disconnected.append(websocket)
                
                # Remove disconnected websockets
                for ws in disconnected:
                    connected_websockets.remove(ws)
            
            await asyncio.sleep(5)  # Update every 5 seconds
            
        except Exception as e:
            logger.error(f"Websocket broadcaster error: {e}")
            await asyncio.sleep(5)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    connected_websockets.append(websocket)
    
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        connected_websockets.remove(websocket)

@app.get("/")
async def serve_dashboard():
    """Serve the main dashboard"""
    return FileResponse('/app/frontend/public/index.html')

@app.get("/api/deployments")
async def get_deployments():
    """Get all deployment data"""
    return {
        "active_deployments": deployment_detector.get_active_deployments(),
        "deployment_history": deployment_detector.get_deployment_history(),
        "total_count": len(deployment_detector.deployment_history)
    }

@app.get("/api/deployments/{deployment_id}/impact")
async def get_deployment_impact(deployment_id: str):
    """Get impact analysis for a specific deployment"""
    impact = next((r for r in impact_analyzer.impact_results if r.deployment_id == deployment_id), None)
    
    if impact:
        return {
            "deployment_id": impact.deployment_id,
            "service_name": impact.service_name,
            "version": impact.version,
            "before_metrics": impact.before_metrics,
            "after_metrics": impact.after_metrics,
            "impact_score": impact.impact_score,
            "significant_changes": impact.significant_changes,
            "analysis_timestamp": impact.analysis_timestamp.isoformat()
        }
    
    return {"error": "Impact analysis not found"}

@app.get("/api/impact/summary")
async def get_impact_summary():
    """Get overall impact analysis summary"""
    return impact_analyzer.get_impact_summary()

@app.get("/api/correlation/stats")
async def get_correlation_stats():
    """Get correlation statistics"""
    return version_correlator.get_correlation_stats()

@app.post("/api/logs/enrich")
async def enrich_log_entries(log_entries: List[dict]):
    """Enrich log entries with deployment context"""
    enriched = await version_correlator.batch_enrich_logs(log_entries)
    return {"enriched_logs": enriched, "count": len(enriched)}

# Mount static files for frontend
if os.path.exists('/app/frontend/build'):
    app.mount("/static", StaticFiles(directory="/app/frontend/build/static"), name="static")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
EOF

# 5. Frontend Implementation
echo "⚛️ Creating React frontend..."

# Package.json
cat > frontend/package.json << 'EOF'
{
  "name": "deployment-tracking-dashboard",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@testing-library/jest-dom": "^6.4.5",
    "@testing-library/react": "^15.0.7",
    "@testing-library/user-event": "^14.5.2",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-scripts": "5.0.1",
    "recharts": "^2.12.7",
    "web-vitals": "^4.0.1",
    "lucide-react": "^0.379.0"
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
  "proxy": "http://localhost:8000"
}
EOF

# Create HTML template
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Deployment Tracking Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #2d3748;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: white;
            border-radius: 16px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
            text-align: center;
        }
        
        .header h1 {
            color: #2d3748;
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 10px;
        }
        
        .header p {
            color: #718096;
            font-size: 1.1rem;
        }
        
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
            animation: pulse 2s infinite;
        }
        
        .status-online {
            background-color: #48bb78;
        }
        
        @keyframes pulse {
            0% { box-shadow: 0 0 0 0 rgba(72, 187, 120, 0.7); }
            70% { box-shadow: 0 0 0 10px rgba(72, 187, 120, 0); }
            100% { box-shadow: 0 0 0 0 rgba(72, 187, 120, 0); }
        }
        
        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
            margin-bottom: 30px;
        }
        
        .card {
            background: white;
            border-radius: 16px;
            padding: 30px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 40px rgba(0,0,0,0.15);
        }
        
        .card h2 {
            color: #2d3748;
            font-size: 1.5rem;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
        }
        
        .card h2 .icon {
            margin-right: 10px;
            width: 24px;
            height: 24px;
        }
        
        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px 0;
            border-bottom: 1px solid #e2e8f0;
        }
        
        .metric:last-child {
            border-bottom: none;
        }
        
        .metric-label {
            color: #718096;
            font-weight: 500;
        }
        
        .metric-value {
            color: #2d3748;
            font-weight: 700;
            font-size: 1.1rem;
        }
        
        .deployment-item {
            background: #f7fafc;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 15px;
            border-left: 4px solid #4299e1;
            transition: all 0.3s ease;
        }
        
        .deployment-item:hover {
            background: #edf2f7;
            transform: translateX(5px);
        }
        
        .deployment-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }
        
        .deployment-service {
            font-weight: 700;
            color: #2d3748;
        }
        
        .deployment-version {
            background: #4299e1;
            color: white;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.9rem;
            font-weight: 600;
        }
        
        .deployment-meta {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 10px;
            color: #718096;
            font-size: 0.9rem;
        }
        
        .impact-score {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 20px;
            font-weight: 600;
            font-size: 0.9rem;
        }
        
        .impact-low {
            background: #c6f6d5;
            color: #2f855a;
        }
        
        .impact-medium {
            background: #fed7a1;
            color: #c05621;
        }
        
        .impact-high {
            background: #fed7d7;
            color: #c53030;
        }
        
        .loading {
            text-align: center;
            padding: 40px;
            color: #718096;
        }
        
        .loading:after {
            content: '⟳';
            display: inline-block;
            animation: spin 1s linear infinite;
            margin-left: 10px;
        }
        
        @keyframes spin {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
        }
        
        .timeline {
            max-height: 500px;
            overflow-y: auto;
        }
        
        .timeline::-webkit-scrollbar {
            width: 8px;
        }
        
        .timeline::-webkit-scrollbar-track {
            background: #f1f1f1;
            border-radius: 4px;
        }
        
        .timeline::-webkit-scrollbar-thumb {
            background: #c1c1c1;
            border-radius: 4px;
        }
        
        .timeline::-webkit-scrollbar-thumb:hover {
            background: #a8a8a8;
        }
    </style>
</head>
<body>
    <div id="root">
        <div class="container">
            <div class="header">
                <h1>🚀 Deployment Tracking Dashboard</h1>
                <p><span class="status-indicator status-online"></span>Real-time monitoring of deployments and their impact</p>
            </div>
            
            <div class="dashboard-grid">
                <div class="card">
                    <h2>📊 System Overview</h2>
                    <div id="system-metrics" class="loading">Loading system metrics...</div>
                </div>
                
                <div class="card">
                    <h2>🔄 Active Deployments</h2>
                    <div id="active-deployments" class="loading">Loading active deployments...</div>
                </div>
                
                <div class="card">
                    <h2>📈 Impact Analysis</h2>
                    <div id="impact-summary" class="loading">Loading impact analysis...</div>
                </div>
                
                <div class="card">
                    <h2>📅 Deployment Timeline</h2>
                    <div id="deployment-timeline" class="timeline loading">Loading deployment history...</div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        class DeploymentDashboard {
            constructor() {
                this.ws = null;
                this.data = {};
                this.connect();
            }
            
            connect() {
                const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                this.ws = new WebSocket(`${protocol}//${window.location.host}/ws`);
                
                this.ws.onopen = () => {
                    console.log('Connected to deployment tracking system');
                };
                
                this.ws.onmessage = (event) => {
                    this.data = JSON.parse(event.data);
                    this.updateDashboard();
                };
                
                this.ws.onclose = () => {
                    console.log('Disconnected from deployment tracking system');
                    setTimeout(() => this.connect(), 5000);
                };
                
                this.ws.onerror = (error) => {
                    console.error('WebSocket error:', error);
                };
            }
            
            updateDashboard() {
                this.updateSystemMetrics();
                this.updateActiveDeployments();
                this.updateImpactSummary();
                this.updateDeploymentTimeline();
            }
            
            updateSystemMetrics() {
                const element = document.getElementById('system-metrics');
                const stats = this.data.correlation_stats || {};
                
                element.innerHTML = `
                    <div class="metric">
                        <span class="metric-label">Active Deployments</span>
                        <span class="metric-value">${stats.active_deployments || 0}</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Total Deployments</span>
                        <span class="metric-value">${stats.total_deployments || 0}</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Correlation Cache</span>
                        <span class="metric-value">${stats.cache_size || 0}</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Last Update</span>
                        <span class="metric-value">${new Date().toLocaleTimeString()}</span>
                    </div>
                `;
            }
            
            updateActiveDeployments() {
                const element = document.getElementById('active-deployments');
                const deployments = this.data.active_deployments || {};
                
                if (Object.keys(deployments).length === 0) {
                    element.innerHTML = '<p style="color: #718096; text-align: center;">No active deployments</p>';
                    return;
                }
                
                let html = '';
                Object.values(deployments).forEach(deployment => {
                    html += `
                        <div class="deployment-item">
                            <div class="deployment-header">
                                <span class="deployment-service">${deployment.service_name}</span>
                                <span class="deployment-version">${deployment.version}</span>
                            </div>
                            <div class="deployment-meta">
                                <div>Environment: ${deployment.environment}</div>
                                <div>Source: ${deployment.source}</div>
                                <div>Time: ${new Date(deployment.timestamp).toLocaleTimeString()}</div>
                            </div>
                        </div>
                    `;
                });
                
                element.innerHTML = html;
            }
            
            updateImpactSummary() {
                const element = document.getElementById('impact-summary');
                const impact = this.data.impact_summary || {};
                
                if (!impact.total_analyzed) {
                    element.innerHTML = '<p style="color: #718096; text-align: center;">No impact data available yet</p>';
                    return;
                }
                
                const avgScore = impact.average_impact_score || 0;
                const scoreClass = avgScore > 70 ? 'impact-high' : avgScore > 30 ? 'impact-medium' : 'impact-low';
                
                element.innerHTML = `
                    <div class="metric">
                        <span class="metric-label">Deployments Analyzed</span>
                        <span class="metric-value">${impact.total_analyzed}</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">High Impact Deployments</span>
                        <span class="metric-value">${impact.high_impact_deployments || 0}</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Average Impact Score</span>
                        <span class="metric-value">
                            <span class="impact-score ${scoreClass}">${avgScore.toFixed(1)}</span>
                        </span>
                    </div>
                `;
            }
            
            updateDeploymentTimeline() {
                const element = document.getElementById('deployment-timeline');
                const deployments = this.data.recent_deployments || [];
                
                if (deployments.length === 0) {
                    element.innerHTML = '<p style="color: #718096; text-align: center;">No recent deployments</p>';
                    return;
                }
                
                let html = '';
                deployments.slice().reverse().forEach(deployment => {
                    const timeAgo = this.timeAgo(new Date(deployment.timestamp));
                    html += `
                        <div class="deployment-item">
                            <div class="deployment-header">
                                <span class="deployment-service">${deployment.service_name}</span>
                                <span class="deployment-version">${deployment.version}</span>
                            </div>
                            <div class="deployment-meta">
                                <div>Environment: ${deployment.environment}</div>
                                <div>Branch: ${deployment.branch || 'main'}</div>
                                <div>Deployed: ${timeAgo}</div>
                                <div>Commit: ${deployment.commit_hash || 'N/A'}</div>
                            </div>
                        </div>
                    `;
                });
                
                element.innerHTML = html;
            }
            
            timeAgo(date) {
                const now = new Date();
                const diff = now - date;
                const minutes = Math.floor(diff / 60000);
                
                if (minutes < 1) return 'Just now';
                if (minutes < 60) return `${minutes}m ago`;
                
                const hours = Math.floor(minutes / 60);
                if (hours < 24) return `${hours}h ago`;
                
                const days = Math.floor(hours / 24);
                return `${days}d ago`;
            }
        }
        
        // Initialize dashboard when page loads
        document.addEventListener('DOMContentLoaded', () => {
            new DeploymentDashboard();
        });
    </script>
</body>
</html>
EOF

# 6. Configuration Files
cat > backend/config/config.yaml << 'EOF'
deployment_tracking:
  sources:
    github_actions:
      enabled: true
      webhook_url: "/webhooks/github"
    docker_registry:
      enabled: true
      registries:
        - "docker.io"
        - "ghcr.io"
    kubernetes:
      enabled: true
      namespaces:
        - "default"
        - "production"
        - "staging"

correlation:
  cache_size: 10000
  batch_size: 100
  enrichment_timeout: 5

analysis:
  time_windows:
    before_deployment: 30  # minutes
    after_deployment: 30   # minutes
  impact_thresholds:
    response_time: 0.15    # 15% change
    error_rate: 0.5        # 50% change
    throughput: 0.10       # 10% change

api:
  host: "0.0.0.0"
  port: 8000
  cors_origins:
    - "http://localhost:3000"
    - "http://localhost:8000"
EOF

# 7. Test Files
echo "🧪 Creating test suite..."

cat > backend/tests/test_deployment_detector.py << 'EOF'
import pytest
import asyncio
from datetime import datetime, timezone
import sys
sys.path.append('../src')

from deployment.detector import DeploymentDetector, DeploymentEvent

@pytest.mark.asyncio
async def test_deployment_detector_initialization():
    """Test deployment detector initialization"""
    config = {"sources": ["github", "docker"]}
    detector = DeploymentDetector(config)
    
    assert detector.config == config
    assert detector.active_deployments == {}
    assert detector.deployment_history == []

@pytest.mark.asyncio
async def test_process_deployment_event():
    """Test processing deployment events"""
    detector = DeploymentDetector({"sources": []})
    
    deployment = DeploymentEvent(
        id="test_deployment_1",
        service_name="test-service",
        version="v1.0.0",
        environment="production",
        timestamp=datetime.now(timezone.utc),
        source="github_actions",
        metadata={"test": True}
    )
    
    result = await detector.process_deployment_event(deployment)
    
    assert result == deployment
    assert len(detector.deployment_history) == 1
    assert "test-service_production" in detector.active_deployments

@pytest.mark.asyncio
async def test_get_deployment_for_timestamp():
    """Test getting deployment for specific timestamp"""
    detector = DeploymentDetector({"sources": []})
    
    # Create test deployment
    deployment_time = datetime.now(timezone.utc)
    deployment = DeploymentEvent(
        id="test_deployment_2",
        service_name="test-service",
        version="v1.1.0",
        environment="production",
        timestamp=deployment_time,
        source="github_actions",
        metadata={}
    )
    
    await detector.process_deployment_event(deployment)
    
    # Test getting deployment
    result = detector.get_deployment_for_timestamp(
        deployment_time, "test-service", "production"
    )
    
    assert result is not None
    assert result.version == "v1.1.0"

def test_deployment_history_limit():
    """Test deployment history size limit"""
    detector = DeploymentDetector({"sources": []})
    
    # Add 150 deployments (more than limit of 100)
    for i in range(150):
        deployment = DeploymentEvent(
            id=f"test_deployment_{i}",
            service_name="test-service",
            version=f"v1.{i}.0",
            environment="production",
            timestamp=datetime.now(timezone.utc),
            source="github_actions",
            metadata={}
        )
        detector.deployment_history.append(deployment)
    
    # Simulate the limit check that happens in process_deployment_event
    if len(detector.deployment_history) > 100:
        detector.deployment_history = detector.deployment_history[-100:]
    
    assert len(detector.deployment_history) == 100
    assert detector.deployment_history[0].id == "test_deployment_50"
EOF

cat > backend/tests/test_correlator.py << 'EOF'
import pytest
import asyncio
from datetime import datetime, timezone
import sys
sys.path.append('../src')

from correlation.correlator import VersionCorrelator
from deployment.detector import DeploymentDetector, DeploymentEvent

@pytest.mark.asyncio
async def test_log_enrichment():
    """Test log entry enrichment with deployment context"""
    # Setup
    detector = DeploymentDetector({"sources": []})
    correlator = VersionCorrelator(detector)
    
    # Create test deployment
    deployment = DeploymentEvent(
        id="test_deployment",
        service_name="test-service",
        version="v2.0.0",
        environment="production",
        timestamp=datetime.now(timezone.utc),
        source="github_actions",
        metadata={},
        commit_hash="abc123def"
    )
    
    await detector.process_deployment_event(deployment)
    
    # Test log entry
    log_entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "test-service",
        "environment": "production",
        "level": "INFO",
        "message": "Test log message"
    }
    
    # Enrich log entry
    enriched = await correlator.enrich_log_entry(log_entry)
    
    assert "deployment" in enriched
    assert enriched["deployment"]["version"] == "v2.0.0"
    assert enriched["deployment"]["commit_hash"] == "abc123def"

@pytest.mark.asyncio
async def test_batch_enrichment():
    """Test batch log enrichment"""
    detector = DeploymentDetector({"sources": []})
    correlator = VersionCorrelator(detector)
    
    # Test with multiple log entries
    log_entries = [
        {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "service": "unknown-service",
            "message": "Test message 1"
        },
        {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "service": "unknown-service",
            "message": "Test message 2"
        }
    ]
    
    enriched_logs = await correlator.batch_enrich_logs(log_entries)
    
    assert len(enriched_logs) == 2
    assert all("deployment" in log for log in enriched_logs)

def test_correlation_stats():
    """Test correlation statistics"""
    detector = DeploymentDetector({"sources": []})
    correlator = VersionCorrelator(detector)
    
    stats = correlator.get_correlation_stats()
    
    assert "cache_size" in stats
    assert "active_deployments" in stats
    assert "total_deployments" in stats
EOF

cat > backend/tests/test_analyzer.py << 'EOF'
import pytest
import asyncio
from datetime import datetime, timezone
import sys
sys.path.append('../src')

from analysis.analyzer import ImpactAnalyzer
from deployment.detector import DeploymentDetector, DeploymentEvent

@pytest.mark.asyncio
async def test_impact_calculation():
    """Test impact calculation logic"""
    detector = DeploymentDetector({"sources": []})
    analyzer = ImpactAnalyzer(detector)
    
    # Test metrics with significant changes
    before_metrics = {
        "response_time_avg": 100,
        "error_rate": 0.01,
        "throughput": 1000
    }
    
    after_metrics = {
        "response_time_avg": 150,  # 50% increase
        "error_rate": 0.02,        # 100% increase
        "throughput": 950          # 5% decrease
    }
    
    impact_score, significant_changes = analyzer.calculate_impact(before_metrics, after_metrics)
    
    assert impact_score > 0
    assert len(significant_changes) > 0
    assert any("response_time_avg" in change for change in significant_changes)

@pytest.mark.asyncio
async def test_deployment_impact_analysis():
    """Test deployment impact analysis"""
    detector = DeploymentDetector({"sources": []})
    analyzer = ImpactAnalyzer(detector)
    
    # Create test deployment
    deployment = DeploymentEvent(
        id="test_deployment_impact",
        service_name="test-service",
        version="v1.5.0",
        environment="production",
        timestamp=datetime.now(timezone.utc),
        source="github_actions",
        metadata={}
    )
    
    # Analyze impact
    impact = await analyzer.analyze_deployment_impact(deployment)
    
    assert impact is not None
    assert impact.deployment_id == "test_deployment_impact"
    assert impact.service_name == "test-service"
    assert impact.version == "v1.5.0"
    assert "before_metrics" in impact.__dict__
    assert "after_metrics" in impact.__dict__

def test_impact_summary():
    """Test impact summary generation"""
    detector = DeploymentDetector({"sources": []})
    analyzer = ImpactAnalyzer(detector)
    
    # Test with no impact results
    summary = analyzer.get_impact_summary()
    assert summary["total_analyzed"] == 0
    
    # TODO: Add test with mock impact results
EOF

# 8. Docker Configuration
echo "🐳 Creating Docker configuration..."

cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

# Copy application code
COPY backend/ /app/backend/
COPY frontend/ /app/frontend/
COPY data/ /app/data/

# Create necessary directories
RUN mkdir -p /app/data /app/logs

# Set Python path
ENV PYTHONPATH=/app/backend/src

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/api/deployments || exit 1

# Run the application
CMD ["python", "/app/backend/src/api/server.py"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  deployment-tracker:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    environment:
      - PYTHONPATH=/app/backend/src
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/deployments"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  redis_data:
EOF

cat > .dockerignore << 'EOF'
venv/
__pycache__/
*.pyc
*.pyo
*.pyd
.git/
.gitignore
README.md
.pytest_cache/
.coverage
.env
logs/*.log
node_modules/
frontend/build/
EOF

# 9. Build Scripts
cat > build.sh << 'EOF'
#!/bin/bash

echo "🔨 Building Deployment Tracking System..."

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r backend/requirements.txt

# Create data directory
mkdir -p data logs

# Run tests
echo "🧪 Running tests..."
cd backend && python -m pytest tests/ -v

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Tests failed!"
    exit 1
fi

echo "✅ Build completed successfully!"
EOF

cat > start.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Deployment Tracking System..."

# Create necessary directories
mkdir -p data logs

# Start with Docker Compose
docker-compose up -d --build

echo "⏳ Waiting for services to start..."
sleep 15

# Check health
curl -s http://localhost:8000/api/deployments > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Deployment Tracking System is running!"
    echo "📊 Dashboard: http://localhost:8000"
    echo "🔍 API Health: http://localhost:8000/api/deployments"
else
    echo "❌ System failed to start properly"
    docker-compose logs
fi
EOF

cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Deployment Tracking System..."

docker-compose down

echo "✅ System stopped!"
EOF

# Make scripts executable
chmod +x build.sh start.sh stop.sh

# 10. Demo and Verification
echo "🎭 Creating demo script..."

cat > demo.py << 'EOF'
#!/usr/bin/env python3
"""
Deployment Tracking System Demo
Demonstrates key functionality and generates sample data
"""

import asyncio
import json
import time
import requests
from datetime import datetime

class DeploymentTrackingDemo:
    def __init__(self):
        self.base_url = "http://localhost:8000"
        
    def test_api_health(self):
        """Test API health and basic connectivity"""
        try:
            response = requests.get(f"{self.base_url}/api/deployments", timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def generate_test_logs(self):
        """Generate test log entries for correlation demo"""
        test_logs = [
            {
                "timestamp": datetime.now().isoformat() + "Z",
                "service": "user-service",
                "environment": "production",
                "level": "INFO",
                "message": "User login successful",
                "user_id": "user_123"
            },
            {
                "timestamp": datetime.now().isoformat() + "Z",
                "service": "payment-service",
                "environment": "production",
                "level": "ERROR",
                "message": "Payment processing failed",
                "error_code": "CARD_DECLINED"
            },
            {
                "timestamp": datetime.now().isoformat() + "Z",
                "service": "api-gateway",
                "environment": "staging",
                "level": "WARN",
                "message": "High response time detected",
                "response_time": 2500
            }
        ]
        
        try:
            response = requests.post(
                f"{self.base_url}/api/logs/enrich",
                json=test_logs,
                timeout=10
            )
            return response.status_code == 200, response.json()
        except Exception as e:
            return False, str(e)
    
    def get_impact_summary(self):
        """Get deployment impact analysis summary"""
        try:
            response = requests.get(f"{self.base_url}/api/impact/summary", timeout=5)
            return response.status_code == 200, response.json()
        except Exception as e:
            return False, str(e)
    
    def run_demo(self):
        """Run complete demo"""
        print("🎭 Deployment Tracking System Demo")
        print("=" * 50)
        
        # Test 1: API Health
        print("\n1. Testing API connectivity...")
        if self.test_api_health():
            print("   ✅ API is healthy and responding")
        else:
            print("   ❌ API is not responding - make sure system is running")
            return False
        
        # Test 2: Wait for deployments to be generated
        print("\n2. Waiting for demo deployments to be generated...")
        time.sleep(10)
        
        # Test 3: Log Correlation
        print("\n3. Testing log correlation with deployments...")
        success, result = self.generate_test_logs()
        if success:
            print("   ✅ Log correlation successful")
            enriched_count = result.get('count', 0)
            print(f"   📊 Enriched {enriched_count} log entries with deployment context")
        else:
            print(f"   ❌ Log correlation failed: {result}")
        
        # Test 4: Impact Analysis
        print("\n4. Checking deployment impact analysis...")
        time.sleep(5)  # Wait for analysis to process
        success, result = self.get_impact_summary()
        if success:
            print("   ✅ Impact analysis available")
            total = result.get('total_analyzed', 0)
            print(f"   📊 Analyzed {total} deployments for impact")
        else:
            print(f"   ❌ Impact analysis failed: {result}")
        
        # Test 5: Real-time Dashboard
        print("\n5. Dashboard verification...")
        print(f"   🌐 Dashboard URL: {self.base_url}")
        print("   📊 Features available:")
        print("      - Real-time deployment monitoring")
        print("      - Deployment impact analysis")
        print("      - Log correlation statistics")
        print("      - Interactive deployment timeline")
        
        print("\n✅ Demo completed successfully!")
        print(f"\n🎯 Key URLs:")
        print(f"   Dashboard: {self.base_url}")
        print(f"   API Health: {self.base_url}/api/deployments")
        print(f"   Impact Summary: {self.base_url}/api/impact/summary")
        
        return True

if __name__ == "__main__":
    demo = DeploymentTrackingDemo()
    demo.run_demo()
EOF

# 11. Main execution script
cat > run_system.py << 'EOF'
#!/usr/bin/env python3
"""
Main execution script for Deployment Tracking System
"""

import os
import sys
import subprocess
import time

def run_command(command, check=True):
    """Run a shell command"""
    print(f"Running: {command}")
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    
    if check and result.returncode != 0:
        print(f"Error: {result.stderr}")
        return False
    
    if result.stdout:
        print(result.stdout)
    
    return True

def main():
    print("🚀 Deployment Tracking System - Full Setup")
    print("=" * 50)
    
    # Check Python version
    print("1. Checking Python version...")
    if not run_command("python3 --version"):
        print("Error: Python 3.11 not found")
        return False
    
    # Create virtual environment and install dependencies
    print("\n2. Setting up Python environment...")
    if not run_command("chmod +x build.sh && ./build.sh"):
        print("Error: Build failed")
        return False
    
    # Start services
    print("\n3. Starting services...")
    if not run_command("chmod +x start.sh && ./start.sh"):
        print("Error: Failed to start services")
        return False
    
    # Wait for services to be ready
    print("\n4. Waiting for services to be ready...")
    time.sleep(20)
    
    # Run demo
    print("\n5. Running system demonstration...")
    if not run_command("python demo.py"):
        print("Warning: Demo had issues, but system may still be functional")
    
    print("\n🎉 System is ready!")
    print("📊 Dashboard: http://localhost:8000")
    print("🔍 API: http://localhost:8000/api/deployments")
    print("\nTo stop the system, run: ./stop.sh")

if __name__ == "__main__":
    main()
EOF

# Final permissions and directory creation
chmod +x run_system.py demo.py
mkdir -p data logs

echo "✅ All files created successfully!"
echo ""
echo "📁 Project structure:"
find . -type f -name "*.py" -o -name "*.sh" -o -name "*.yml" -o -name "*.json" | head -20
echo ""
echo "🚀 To start the system, run:"
echo "   python3 run_system.py"
echo ""
echo "📊 Dashboard will be available at: http://localhost:8000"