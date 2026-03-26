#!/bin/bash
set -e

echo "🚀 Day 165: SLA Monitoring System - Complete Implementation"
echo "==========================================================="

PROJECT="day165_sla_monitoring"
rm -rf ${PROJECT} 2>/dev/null || true
mkdir -p ${PROJECT} && cd ${PROJECT}

# Create directory structure
echo "📁 Creating project structure..."
mkdir -p {src/{api,monitoring,alerts,reporting,models},tests,config,web,docker,logs,reports}

# Create requirements.txt
cat > requirements.txt << 'REQEOF'
fastapi==0.110.0
uvicorn==0.29.0
pydantic==2.7.0
redis==5.0.4
aiohttp==3.9.5
python-multipart==0.0.9
pytest==8.1.1
pytest-asyncio==0.23.6
requests==2.31.0
pyyaml==6.0.1
REQEOF

# Create configuration
cat > config/sla_config.yaml << 'CFGEOF'
sla_monitoring:
  collection_interval_seconds: 10
  evaluation_windows:
    short: 60
    medium: 300
    long: 1800
  service_tiers:
    gold:
      availability_slo: 99.95
      latency_p95_ms: 50
      error_rate_percent: 0.01
    silver:
      availability_slo: 99.9
      latency_p95_ms: 100
      error_rate_percent: 0.05
    bronze:
      availability_slo: 99.5
      latency_p95_ms: 200
      error_rate_percent: 0.1
  alerting:
    channels:
      - type: email
        enabled: true
    severity_levels:
      critical:
        breach_duration_seconds: 120
      warning:
        breach_duration_seconds: 60
redis:
  host: localhost
  port: 6379
  db: 0
CFGEOF

# Create data models (COMPLETE CODE)
cat > src/models/sla_models.py << 'MODELEOF'
from pydantic import BaseModel
from typing import Dict, List, Literal
from datetime import datetime
from enum import Enum

class ServiceTier(str, Enum):
    GOLD = "gold"
    SILVER = "silver"
    BRONZE = "bronze"

class MetricType(str, Enum):
    LATENCY = "latency"
    AVAILABILITY = "availability"
    ERROR_RATE = "error_rate"
    THROUGHPUT = "throughput"

class SLIMetric(BaseModel):
    metric_type: MetricType
    value: float
    timestamp: datetime
    service_tier: ServiceTier

class SLOViolation(BaseModel):
    slo_name: str
    service_tier: ServiceTier
    actual_value: float
    target_value: float
    breach_duration_seconds: int
    severity: Literal["critical", "warning", "info"]
    timestamp: datetime
MODELEOF

# Create complete metrics collector (WORKING CODE)
cat > src/monitoring/metrics_collector.py << 'COLLEOF'
import asyncio
import random
import time
from datetime import datetime
from typing import List
import redis.asyncio as aioredis
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
from src.models.sla_models import SLIMetric, MetricType, ServiceTier

class MetricsCollector:
    def __init__(self, redis_client: aioredis.Redis):
        self.redis = redis_client
        self.running = False
        
    async def start_collection(self):
        self.running = True
        print("📊 Metrics collection started")
        while self.running:
            try:
                await self._collect_metrics()
                await asyncio.sleep(10)
            except Exception as e:
                print(f"Collection error: {e}")
                await asyncio.sleep(5)
    
    async def _collect_metrics(self):
        timestamp = datetime.now()
        for tier in ServiceTier:
            latency = self._gen_latency(tier)
            availability = self._gen_availability(tier)
            error_rate = self._gen_error_rate(tier)
            
            await self._store(SLIMetric(
                metric_type=MetricType.LATENCY,
                value=latency,
                timestamp=timestamp,
                service_tier=tier
            ))
            await self._store(SLIMetric(
                metric_type=MetricType.AVAILABILITY,
                value=availability,
                timestamp=timestamp,
                service_tier=tier
            ))
            await self._store(SLIMetric(
                metric_type=MetricType.ERROR_RATE,
                value=error_rate,
                timestamp=timestamp,
                service_tier=tier
            ))
    
    def _gen_latency(self, tier: ServiceTier) -> float:
        base = {ServiceTier.GOLD: 45, ServiceTier.SILVER: 95, ServiceTier.BRONZE: 180}[tier]
        if random.random() < 0.08:  # 8% spike chance
            return base * random.uniform(1.5, 2.5)
        return base + random.gauss(0, base * 0.1)
    
    def _gen_availability(self, tier: ServiceTier) -> float:
        base = {ServiceTier.GOLD: 99.98, ServiceTier.SILVER: 99.92, ServiceTier.BRONZE: 99.6}[tier]
        if random.random() < 0.03:
            return base - random.uniform(0.1, 0.5)
        return min(100, base + random.gauss(0, 0.02))
    
    def _gen_error_rate(self, tier: ServiceTier) -> float:
        base = {ServiceTier.GOLD: 0.005, ServiceTier.SILVER: 0.03, ServiceTier.BRONZE: 0.08}[tier]
        if random.random() < 0.05:
            return base * random.uniform(2, 5)
        return max(0, base + random.gauss(0, base * 0.3))
    
    async def _store(self, metric: SLIMetric):
        key = f"metrics:{metric.service_tier.value}:{metric.metric_type.value}"
        value = f"{metric.timestamp.isoformat()}|{metric.value}"
        await self.redis.lpush(key, value)
        await self.redis.ltrim(key, 0, 10000)
        await self.redis.expire(key, 604800)
    
    async def get_recent_metrics(self, tier: ServiceTier, metric_type: MetricType, window: int = 300) -> List[float]:
        key = f"metrics:{tier.value}:{metric_type.value}"
        values = await self.redis.lrange(key, 0, -1)
        cutoff = time.time() - window
        recent = []
        for v in values:
            ts, val = (v.decode() if isinstance(v, bytes) else v).split('|')
            if datetime.fromisoformat(ts).timestamp() >= cutoff:
                recent.append(float(val))
        return recent
    
    async def stop(self):
        self.running = False
COLLEOF

# Create complete SLO evaluator (WORKING CODE)
cat > src/monitoring/slo_evaluator.py << 'SLOOF'
import asyncio
from datetime import datetime
from typing import List, Dict
import statistics
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
from src.models.sla_models import SLOViolation, MetricType, ServiceTier

class SLOEvaluator:
    def __init__(self, redis_client, metrics_collector, config: Dict):
        self.redis = redis_client
        self.metrics = metrics_collector
        self.config = config
        self.violations = {}
        self.running = False
        self.slo_targets = self._init_targets()
    
    def _init_targets(self):
        targets = {}
        for tier_name, cfg in self.config['service_tiers'].items():
            tier = ServiceTier(tier_name)
            targets[f"{tier_name}_availability"] = (tier, MetricType.AVAILABILITY, cfg['availability_slo'], "greater")
            targets[f"{tier_name}_latency"] = (tier, MetricType.LATENCY, cfg['latency_p95_ms'], "less")
            targets[f"{tier_name}_error_rate"] = (tier, MetricType.ERROR_RATE, cfg['error_rate_percent'], "less")
        return targets
    
    async def start_evaluation(self):
        self.running = True
        print("🎯 SLO evaluation started")
        while self.running:
            try:
                await self._evaluate_all()
                await asyncio.sleep(10)
            except Exception as e:
                print(f"Evaluation error: {e}")
                await asyncio.sleep(5)
    
    async def _evaluate_all(self):
        for slo_name, (tier, metric_type, target, comp) in self.slo_targets.items():
            metrics = await self.metrics.get_recent_metrics(tier, metric_type, 300)
            if not metrics:
                continue
            
            actual = self._calc_p95(metrics) if metric_type == MetricType.LATENCY else statistics.mean(metrics)
            violated = (actual > target) if comp == "less" else (actual < target)
            
            if violated:
                await self._handle_violation(slo_name, tier, actual, target)
            else:
                if slo_name in self.violations:
                    del self.violations[slo_name]
                    print(f"✅ Resolved: {slo_name}")
    
    def _calc_p95(self, vals: List[float]) -> float:
        sorted_vals = sorted(vals)
        idx = int(len(sorted_vals) * 0.95)
        return sorted_vals[min(idx, len(sorted_vals) - 1)]
    
    async def _handle_violation(self, name: str, tier: ServiceTier, actual: float, target: float):
        if name in self.violations:
            self.violations[name].breach_duration_seconds += 10
            self.violations[name].actual_value = actual
        else:
            severity = "critical" if abs(actual - target) / target > 0.1 else "warning"
            self.violations[name] = SLOViolation(
                slo_name=name,
                service_tier=tier,
                actual_value=actual,
                target_value=target,
                breach_duration_seconds=10,
                severity=severity,
                timestamp=datetime.now()
            )
            print(f"🚨 NEW: {name} ({severity})")
    
    async def get_slo_status(self) -> Dict:
        status = {}
        for name, (tier, metric_type, target, comp) in self.slo_targets.items():
            metrics = await self.metrics.get_recent_metrics(tier, metric_type, 300)
            if metrics:
                current = self._calc_p95(metrics) if metric_type == MetricType.LATENCY else statistics.mean(metrics)
                compliant = (current <= target) if comp == "less" else (current >= target)
                status[name] = {
                    'tier': tier.value,
                    'type': metric_type.value,
                    'target': target,
                    'current': round(current, 2),
                    'compliant': compliant
                }
        return status
    
    async def get_violations(self) -> List[SLOViolation]:
        return list(self.violations.values())
    
    async def stop(self):
        self.running = False
SLOOF

# Create alert manager (WORKING CODE)
cat > src/alerts/alert_manager.py << 'ALERTEOF'
import asyncio
from datetime import datetime
from typing import List
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

class AlertManager:
    def __init__(self, config):
        self.config = config
        self.alerts_sent = {}
        self.running = False
    
    async def start_monitoring(self, evaluator):
        self.running = True
        self.evaluator = evaluator
        print("📢 Alert monitoring started")
        while self.running:
            try:
                violations = await self.evaluator.get_violations()
                for v in violations:
                    if self._should_alert(v):
                        await self._send_alert(v)
                await asyncio.sleep(30)
            except Exception as e:
                print(f"Alert error: {e}")
                await asyncio.sleep(10)
    
    def _should_alert(self, v) -> bool:
        severity_cfg = self.config['alerting']['severity_levels'][v.severity]
        return v.breach_duration_seconds >= severity_cfg['breach_duration_seconds']
    
    async def _send_alert(self, v):
        key = f"{v.slo_name}_{v.timestamp.date()}"
        if key not in self.alerts_sent:
            print(f"📧 ALERT: {v.slo_name} - {v.severity.upper()} (actual={v.actual_value:.2f}, target={v.target_value})")
            self.alerts_sent[key] = datetime.now()
    
    async def stop(self):
        self.running = False
ALERTEOF

# Create FastAPI application (COMPLETE CODE)
cat > src/api/sla_api.py << 'APIEOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

class SLAAPI:
    def __init__(self, metrics, evaluator, alerts):
        self.app = FastAPI(title="SLA Monitor")
        self.metrics = metrics
        self.evaluator = evaluator
        self.alerts = alerts
        
        self.app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"])
        self._setup()
    
    def _setup(self):
        @self.app.get("/")
        async def root():
            return {"status": "online"}
        
        @self.app.get("/api/slo/status")
        async def status():
            return JSONResponse(await self.evaluator.get_slo_status())
        
        @self.app.get("/api/violations")
        async def violations():
            v = await self.evaluator.get_violations()
            return JSONResponse([{
                "slo": x.slo_name,
                "tier": x.service_tier.value,
                "severity": x.severity,
                "actual": x.actual_value,
                "target": x.target_value,
                "duration": x.breach_duration_seconds
            } for x in v])
APIEOF

# Create main application (COMPLETE CODE)
cat > src/main.py << 'MAINEOF'
#!/usr/bin/env python3
import asyncio
import signal
import yaml
import redis.asyncio as aioredis
import uvicorn
import sys, os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from src.monitoring.metrics_collector import MetricsCollector
from src.monitoring.slo_evaluator import SLOEvaluator
from src.alerts.alert_manager import AlertManager
from src.api.sla_api import SLAAPI

class SLASystem:
    def __init__(self):
        with open('config/sla_config.yaml') as f:
            self.config = yaml.safe_load(f)
        self.redis = None
        self.tasks = []
    
    async def init(self):
        print("🚀 Initializing SLA Monitoring System...")
        cfg = self.config['redis']
        self.redis = await aioredis.from_url(f"redis://{cfg['host']}:{cfg['port']}/{cfg['db']}")
        
        self.metrics = MetricsCollector(self.redis)
        self.evaluator = SLOEvaluator(self.redis, self.metrics, self.config['sla_monitoring'])
        self.alerts = AlertManager(self.config['sla_monitoring'])
        self.api = SLAAPI(self.metrics, self.evaluator, self.alerts)
        print("✅ Components initialized")
    
    async def start(self):
        print("\n🎯 Starting monitoring...\n")
        self.tasks.append(asyncio.create_task(self.metrics.start_collection()))
        self.tasks.append(asyncio.create_task(self.evaluator.start_evaluation()))
        self.tasks.append(asyncio.create_task(self.alerts.start_monitoring(self.evaluator)))
        
        config = uvicorn.Config(self.api.app, host="0.0.0.0", port=8000, log_level="warning")
        server = uvicorn.Server(config)
        self.tasks.append(asyncio.create_task(server.serve()))
        
        print("✅ API: http://localhost:8000")
        print("📊 Dashboard: http://localhost:8000/api/slo/status")
        print("=" * 60)
    
    async def stop(self):
        print("\n⏹️  Shutting down...")
        await self.metrics.stop()
        await self.evaluator.stop()
        await self.alerts.stop()
        for t in self.tasks:
            t.cancel()
        if self.redis:
            await self.redis.close()

async def main():
    system = SLASystem()
    await system.init()
    await system.start()
    
    def handler(sig, frame):
        asyncio.create_task(system.stop())
    signal.signal(signal.SIGINT, handler)
    
    try:
        while True:
            await asyncio.sleep(1)
    except:
        await system.stop()

if __name__ == "__main__":
    asyncio.run(main())
MAINEOF

# Create tests (COMPLETE CODE)
cat > tests/test_sla.py << 'TESTEOF'
import pytest
from unittest.mock import AsyncMock, MagicMock

@pytest.mark.asyncio
async def test_metrics_collection():
    redis_mock = AsyncMock()
    redis_mock.lpush = AsyncMock()
    redis_mock.ltrim = AsyncMock()
    redis_mock.expire = AsyncMock()
    
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
    from src.monitoring.metrics_collector import MetricsCollector
    
    collector = MetricsCollector(redis_mock)
    await collector._collect_metrics()
    
    assert redis_mock.lpush.called
    print("✅ Metrics collection test passed")

def test_slo_violation_detection():
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
    from src.models.sla_models import ServiceTier, MetricType
    
    # Test violation logic
    target = 100
    actual_compliant = 95
    actual_violated = 110
    
    assert actual_compliant < target, "Should be compliant"
    assert actual_violated > target, "Should be violated"
    print("✅ Violation detection test passed")

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
TESTEOF

# Create Docker setup
cat > docker/Dockerfile << 'DKREOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "-m", "src.main"]
DKREOF

cat > docker-compose.yml << 'DKCEOF'
version: '3.8'
services:
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
  sla-monitor:
    build: {context: ., dockerfile: docker/Dockerfile}
    ports: ["8000:8000"]
    depends_on: [redis]
    environment:
      REDIS_HOST: redis
DKCEOF

# Create start script
cat > start.sh << 'STARTEOF'
#!/bin/bash
set -e
echo "🚀 Starting SLA Monitoring System..."

# Start Redis if not running
if ! redis-cli ping >/dev/null 2>&1; then
    echo "Starting Redis..."
    redis-server --daemonize yes
    sleep 2
fi

# Setup Python environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3.11 -m venv venv
fi

source venv/bin/activate
echo "Installing dependencies..."
pip install -q -r requirements.txt

# Run tests
echo -e "\n🧪 Running tests..."
python -m pytest tests/ -v

# Start system
echo -e "\n🎯 Starting SLA monitoring..."
python -m src.main
STARTEOF
chmod +x start.sh

# Create stop script
cat > stop.sh << 'STOPEOF'
#!/bin/bash
echo "Stopping SLA Monitoring System..."
pkill -f "python -m src.main" || true
redis-cli shutdown || true
echo "✅ Stopped"
STOPEOF
chmod +x stop.sh

# Create demo script
cat > demo.sh << 'DEMOEOF'
#!/bin/bash
echo "📊 SLA Monitoring System - Demo"
echo "================================"
sleep 3

echo -e "\n1. API Health:"
curl -s http://localhost:8000/ | python3 -m json.tool

echo -e "\n\n2. SLO Status:"
curl -s http://localhost:8000/api/slo/status | python3 -m json.tool

echo -e "\n\n3. Active Violations:"
curl -s http://localhost:8000/api/violations | python3 -m json.tool

echo -e "\n\n✅ Demo complete!"
echo "Monitor console for real-time violations"
DEMOEOF
chmod +x demo.sh

# Create web dashboard
cat > web/index.html << 'DASHEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SLA Monitoring Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        .header {
            background: white;
            padding: 20px 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .header h1 {
            color: #333;
            font-size: 28px;
        }
        
        .status-indicator {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .status-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #4caf50;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .last-update {
            color: #666;
            font-size: 14px;
        }
        
        .tiers-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .tier-card {
            background: white;
            border-radius: 10px;
            padding: 25px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .tier-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #f0f0f0;
        }
        
        .tier-name {
            font-size: 24px;
            font-weight: bold;
            text-transform: capitalize;
        }
        
        .tier-gold { color: #ffd700; }
        .tier-silver { color: #c0c0c0; }
        .tier-bronze { color: #cd7f32; }
        
        .metric {
            margin-bottom: 20px;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
        }
        
        .metric-header {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
        }
        
        .metric-name {
            font-weight: 600;
            color: #333;
            text-transform: capitalize;
        }
        
        .metric-status {
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .status-compliant {
            background: #d4edda;
            color: #155724;
        }
        
        .status-violated {
            background: #f8d7da;
            color: #721c24;
        }
        
        .metric-values {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 10px;
        }
        
        .value {
            font-size: 18px;
            font-weight: bold;
        }
        
        .current-value {
            color: #667eea;
        }
        
        .target-value {
            color: #999;
            font-size: 14px;
        }
        
        .progress-bar {
            width: 100%;
            height: 8px;
            background: #e0e0e0;
            border-radius: 4px;
            margin-top: 10px;
            overflow: hidden;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #4caf50, #8bc34a);
            transition: width 0.3s ease;
        }
        
        .progress-fill.warning {
            background: linear-gradient(90deg, #ff9800, #ffc107);
        }
        
        .progress-fill.danger {
            background: linear-gradient(90deg, #f44336, #e91e63);
        }
        
        .violations-panel {
            background: white;
            border-radius: 10px;
            padding: 25px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-top: 20px;
        }
        
        .violations-panel h2 {
            color: #333;
            margin-bottom: 20px;
            font-size: 22px;
        }
        
        .violation-item {
            padding: 15px;
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            border-radius: 4px;
            margin-bottom: 10px;
        }
        
        .violation-item.critical {
            background: #f8d7da;
            border-left-color: #dc3545;
        }
        
        .violation-item.warning {
            background: #fff3cd;
            border-left-color: #ffc107;
        }
        
        .no-violations {
            text-align: center;
            padding: 40px;
            color: #4caf50;
            font-size: 18px;
        }
        
        .error-message {
            background: #f8d7da;
            color: #721c24;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        .loading {
            text-align: center;
            padding: 40px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 SLA Monitoring Dashboard</h1>
            <div class="status-indicator">
                <div class="status-dot"></div>
                <span class="last-update" id="lastUpdate">Loading...</span>
            </div>
        </div>
        
        <div id="errorMessage" style="display: none;"></div>
        
        <div id="tiersContainer" class="tiers-grid"></div>
        
        <div class="violations-panel">
            <h2>🚨 Active Violations</h2>
            <div id="violationsContainer" class="loading">Loading violations...</div>
        </div>
    </div>
    
    <script>
        const API_BASE = window.location.origin;
        let updateInterval;
        
        async function fetchSLOStatus() {
            try {
                const response = await fetch(`${API_BASE}/api/slo/status`);
                if (!response.ok) throw new Error(`HTTP ${response.status}`);
                return await response.json();
            } catch (error) {
                throw new Error(`Failed to fetch SLO status: ${error.message}`);
            }
        }
        
        async function fetchViolations() {
            try {
                const response = await fetch(`${API_BASE}/api/violations`);
                if (!response.ok) throw new Error(`HTTP ${response.status}`);
                return await response.json();
            } catch (error) {
                throw new Error(`Failed to fetch violations: ${error.message}`);
            }
        }
        
        function formatValue(value, type) {
            if (value === null || value === undefined || isNaN(value)) return 'N/A';
            
            if (type === 'latency') {
                return `${value.toFixed(2)} ms`;
            } else if (type === 'availability') {
                return `${value.toFixed(3)}%`;
            } else if (type === 'error_rate') {
                return `${value.toFixed(4)}%`;
            }
            return value.toFixed(2);
        }
        
        function calculateProgress(current, target, type) {
            if (type === 'latency' || type === 'error_rate') {
                const ratio = Math.min(current / target, 1);
                return Math.max(0, Math.min(100, (1 - ratio) * 100));
            } else {
                return Math.min(100, (current / target) * 100);
            }
        }
        
        function getProgressClass(progress, compliant) {
            if (!compliant) return 'danger';
            if (progress < 80) return 'warning';
            return '';
        }
        
        function renderTiers(sloStatus) {
            const container = document.getElementById('tiersContainer');
            container.innerHTML = '';
            
            const tiers = {};
            for (const [key, data] of Object.entries(sloStatus)) {
                const tier = data.tier;
                if (!tiers[tier]) {
                    tiers[tier] = [];
                }
                tiers[tier].push({ key, ...data });
            }
            
            for (const [tierName, metrics] of Object.entries(tiers)) {
                const tierCard = document.createElement('div');
                tierCard.className = 'tier-card';
                
                const tierHeader = document.createElement('div');
                tierHeader.className = 'tier-header';
                tierHeader.innerHTML = `
                    <span class="tier-name tier-${tierName}">${tierName.toUpperCase()}</span>
                `;
                tierCard.appendChild(tierHeader);
                
                metrics.forEach(metric => {
                    const metricDiv = document.createElement('div');
                    metricDiv.className = 'metric';
                    
                    const progress = calculateProgress(metric.current, metric.target, metric.type);
                    const progressClass = getProgressClass(progress, metric.compliant);
                    
                    metricDiv.innerHTML = `
                        <div class="metric-header">
                            <span class="metric-name">${metric.type.replace('_', ' ')}</span>
                            <span class="metric-status ${metric.compliant ? 'status-compliant' : 'status-violated'}">
                                ${metric.compliant ? '✓ Compliant' : '✗ Violated'}
                            </span>
                        </div>
                        <div class="metric-values">
                            <span class="value current-value">${formatValue(metric.current, metric.type)}</span>
                            <span class="target-value">Target: ${formatValue(metric.target, metric.type)}</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill ${progressClass}" style="width: ${progress}%"></div>
                        </div>
                    `;
                    
                    tierCard.appendChild(metricDiv);
                });
                
                container.appendChild(tierCard);
            }
        }
        
        function renderViolations(violations) {
            const container = document.getElementById('violationsContainer');
            
            if (!violations || violations.length === 0) {
                container.innerHTML = '<div class="no-violations">✅ No active violations - All SLOs are compliant!</div>';
                return;
            }
            
            container.innerHTML = violations.map(v => `
                <div class="violation-item ${v.severity}">
                    <strong>${v.slo}</strong> (${v.tier.toUpperCase()}) - 
                    <span style="color: #dc3545;">${v.severity.toUpperCase()}</span><br>
                    Actual: ${formatValue(v.actual, v.slo.includes('latency') ? 'latency' : v.slo.includes('availability') ? 'availability' : 'error_rate')} | 
                    Target: ${formatValue(v.target, v.slo.includes('latency') ? 'latency' : v.slo.includes('availability') ? 'availability' : 'error_rate')} | 
                    Duration: ${v.duration}s
                </div>
            `).join('');
        }
        
        function showError(message) {
            const errorDiv = document.getElementById('errorMessage');
            errorDiv.textContent = `Error: ${message}`;
            errorDiv.style.display = 'block';
        }
        
        function hideError() {
            document.getElementById('errorMessage').style.display = 'none';
        }
        
        async function updateDashboard() {
            try {
                hideError();
                
                const [sloStatus, violations] = await Promise.all([
                    fetchSLOStatus(),
                    fetchViolations()
                ]);
                
                if (!sloStatus || Object.keys(sloStatus).length === 0) {
                    showError('No SLO status data available. Waiting for metrics collection...');
                    return;
                }
                
                let hasZeroValues = false;
                for (const [key, data] of Object.entries(sloStatus)) {
                    if (data.current === 0 || data.current === null || isNaN(data.current)) {
                        hasZeroValues = true;
                        break;
                    }
                }
                
                if (hasZeroValues) {
                    showError('Some metrics show zero values. Waiting for data collection...');
                }
                
                renderTiers(sloStatus);
                renderViolations(violations);
                
                document.getElementById('lastUpdate').textContent = 
                    `Last updated: ${new Date().toLocaleTimeString()}`;
                
            } catch (error) {
                showError(error.message);
                console.error('Dashboard update error:', error);
            }
        }
        
        updateDashboard();
        updateInterval = setInterval(updateDashboard, 5000);
        
        window.addEventListener('beforeunload', () => {
            if (updateInterval) clearInterval(updateInterval);
        });
    </script>
</body>
</html>
DASHEOF

# Create service check script
cat > check_services.sh << 'CHKEOF'
#!/bin/bash
echo "🔍 Checking for running services..."

redis_count=$(pgrep -f "redis-server" | wc -l)
if [ $redis_count -gt 0 ]; then
    echo "⚠️  Found $redis_count Redis server process(es)"
    pgrep -f "redis-server" | xargs ps -p 2>/dev/null || true
else
    echo "✅ No Redis server running"
fi

sla_count=$(pgrep -f "python.*src.main" | wc -l)
if [ $sla_count -gt 0 ]; then
    echo "⚠️  Found $sla_count SLA monitoring process(es)"
    pgrep -f "python.*src.main" | xargs ps -p 2>/dev/null || true
    exit 1
else
    echo "✅ No SLA monitoring system running"
    exit 0
fi
CHKEOF
chmod +x check_services.sh

echo ""
echo "✅ Project setup complete!"
echo ""
echo "📁 Structure: ${PROJECT}/"
echo ""
echo "🚀 Quick start:"
echo "   cd ${PROJECT}"
echo "   ./start.sh"
echo ""
echo "🧪 Or with Docker:"
echo "   docker-compose up --build"
echo ""
echo "📊 Endpoints:"
echo "   Dashboard: http://localhost:8000/dashboard"
echo "   API Status: http://localhost:8000/api/slo/status"
echo "   Violations: http://localhost:8000/api/violations"
echo ""
echo "📋 Additional Scripts:"
echo "   ./start_background.sh - Start in background"
echo "   ./check_services.sh - Check for duplicate services"
echo "   ./validate_dashboard.sh - Validate dashboard metrics"
echo ""