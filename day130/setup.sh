#!/bin/bash

# Day 130: APM Integration Implementation Script
# Application Performance Monitoring Integration for Distributed Log Processing

set -e

echo "🚀 Day 130: Setting up APM Integration System"
echo "=============================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p day130-apm-integration/{src/{collectors,correlation,storage,api},frontend/{src/components,public},tests,config,docker,scripts}
cd day130-apm-integration

# Create directory structure verification
echo "📂 Project structure:"
find . -type d | sort

# Create Python requirements with latest May 2025 libraries
cat > requirements.txt << 'EOF'
fastapi==0.111.0
uvicorn==0.30.1
psutil==5.9.8
redis==5.0.4
asyncio-mqtt==0.16.2
pydantic==2.7.1
structlog==24.1.0
prometheus-client==0.20.0
websockets==12.0
pytest==8.2.0
pytest-asyncio==0.23.6
httpx==0.27.0
numpy==1.26.4
pandas==2.2.2
aiofiles==23.2.1
python-multipart==0.0.6
jinja2==3.1.2
EOF

# Create package.json for React frontend
cat > frontend/package.json << 'EOF'
{
  "name": "apm-dashboard",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-scripts": "5.0.1",
    "recharts": "^2.12.7",
    "socket.io-client": "^4.7.5",
    "axios": "^1.7.2",
    "lucide-react": "^0.378.0",
    "@headlessui/react": "^2.0.4",
    "@heroicons/react": "^2.1.3",
    "tailwindcss": "^3.4.3",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.38"
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

# Configuration files
cat > config/apm_config.yaml << 'EOF'
apm:
  correlation:
    window_size_seconds: 30
    threshold_cpu: 80.0
    threshold_memory: 75.0
    threshold_response_time: 1000
  
  metrics:
    collection_interval: 5
    retention_hours: 24
  
  alerts:
    cpu_critical: 90.0
    memory_critical: 85.0
    response_time_critical: 2000
    
  storage:
    redis_url: "redis://localhost:6379/0"
    logs_index: "apm_logs"
    metrics_index: "apm_metrics"

server:
  host: "0.0.0.0" 
  port: 8000
  debug: true
EOF

# System metrics collector
cat > src/collectors/system_metrics.py << 'EOF'
import asyncio
import psutil
import time
from typing import Dict, Any
from dataclasses import dataclass
from datetime import datetime
import structlog
import redis.asyncio as redis

logger = structlog.get_logger()

@dataclass
class SystemMetrics:
    timestamp: float
    cpu_percent: float
    memory_percent: float
    disk_io: Dict[str, Any]
    network_io: Dict[str, Any]
    load_average: tuple

class SystemMetricsCollector:
    def __init__(self, redis_client: redis.Redis, collection_interval: int = 5):
        self.redis_client = redis_client
        self.collection_interval = collection_interval
        self.running = False
        
    async def start_collection(self):
        """Start collecting system metrics"""
        self.running = True
        logger.info("Starting system metrics collection")
        
        while self.running:
            try:
                metrics = await self._collect_metrics()
                await self._store_metrics(metrics)
                await asyncio.sleep(self.collection_interval)
            except Exception as e:
                logger.error("Error collecting metrics", error=str(e))
                
    async def _collect_metrics(self) -> SystemMetrics:
        """Collect current system metrics"""
        disk_io = psutil.disk_io_counters()._asdict() if psutil.disk_io_counters() else {}
        net_io = psutil.net_io_counters()._asdict() if psutil.net_io_counters() else {}
        
        return SystemMetrics(
            timestamp=time.time(),
            cpu_percent=psutil.cpu_percent(interval=1),
            memory_percent=psutil.virtual_memory().percent,
            disk_io=disk_io,
            network_io=net_io,
            load_average=psutil.getloadavg()
        )
    
    async def _store_metrics(self, metrics: SystemMetrics):
        """Store metrics in Redis time series"""
        key = f"metrics:{int(metrics.timestamp)}"
        data = {
            "timestamp": metrics.timestamp,
            "cpu": metrics.cpu_percent,
            "memory": metrics.memory_percent,
            "load_1": metrics.load_average[0],
            "load_5": metrics.load_average[1], 
            "load_15": metrics.load_average[2]
        }
        
        await self.redis_client.hset(key, mapping=data)
        await self.redis_client.expire(key, 86400)  # 24 hours retention
        
    def stop(self):
        """Stop metrics collection"""
        self.running = False
        logger.info("Stopped system metrics collection")
EOF

# Application metrics collector
cat > src/collectors/app_metrics.py << 'EOF'
import asyncio
import time
from typing import Dict, Any, Optional
from dataclasses import dataclass
from datetime import datetime
import structlog
import redis.asyncio as redis

logger = structlog.get_logger()

@dataclass  
class AppMetrics:
    timestamp: float
    request_count: int
    error_count: int
    response_time_avg: float
    response_time_p95: float
    active_connections: int

class AppMetricsCollector:
    def __init__(self, redis_client: redis.Redis):
        self.redis_client = redis_client
        self.request_count = 0
        self.error_count = 0
        self.response_times = []
        self.active_connections = 0
        
    async def record_request(self, response_time: float, is_error: bool = False):
        """Record a request with response time"""
        self.request_count += 1
        if is_error:
            self.error_count += 1
        self.response_times.append(response_time)
        
        # Keep only last 100 response times for memory efficiency
        if len(self.response_times) > 100:
            self.response_times = self.response_times[-100:]
    
    async def get_current_metrics(self) -> AppMetrics:
        """Get current application metrics"""
        response_times = self.response_times.copy()
        avg_response_time = sum(response_times) / len(response_times) if response_times else 0
        
        # Calculate P95
        if response_times:
            sorted_times = sorted(response_times)
            p95_index = int(0.95 * len(sorted_times))
            p95_response_time = sorted_times[p95_index] if p95_index < len(sorted_times) else sorted_times[-1]
        else:
            p95_response_time = 0
            
        return AppMetrics(
            timestamp=time.time(),
            request_count=self.request_count,
            error_count=self.error_count,
            response_time_avg=avg_response_time,
            response_time_p95=p95_response_time,
            active_connections=self.active_connections
        )
    
    async def store_metrics(self):
        """Store current metrics snapshot"""
        metrics = await self.get_current_metrics()
        key = f"app_metrics:{int(metrics.timestamp)}"
        
        data = {
            "timestamp": metrics.timestamp,
            "requests": metrics.request_count,
            "errors": metrics.error_count,
            "avg_response": metrics.response_time_avg,
            "p95_response": metrics.response_time_p95,
            "connections": metrics.active_connections
        }
        
        await self.redis_client.hset(key, mapping=data)
        await self.redis_client.expire(key, 86400)
        
        # Reset counters after storing
        self.request_count = 0
        self.error_count = 0
        self.response_times = []
EOF

# Correlation engine
cat > src/correlation/engine.py << 'EOF'
import asyncio
import time
import json
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
import structlog
import redis.asyncio as redis

logger = structlog.get_logger()

@dataclass
class EnrichedLog:
    original_log: Dict[str, Any]
    metrics_context: Dict[str, Any]
    correlation_id: str
    enhancement_level: str
    timestamp: float

class CorrelationEngine:
    def __init__(self, redis_client: redis.Redis, config: Dict[str, Any]):
        self.redis_client = redis_client
        self.config = config
        self.correlation_windows = {}
        self.alert_thresholds = config.get('alerts', {})
        
    async def process_log_entry(self, log_entry: Dict[str, Any]) -> EnrichedLog:
        """Process a log entry and enrich with performance context"""
        timestamp = log_entry.get('timestamp', time.time())
        
        # Get current metrics context
        metrics_context = await self._get_metrics_context(timestamp)
        
        # Determine enhancement level
        enhancement_level = self._calculate_enhancement_level(metrics_context, log_entry)
        
        # Create correlation ID
        correlation_id = f"corr_{int(timestamp)}_{hash(str(log_entry))}"
        
        enriched_log = EnrichedLog(
            original_log=log_entry,
            metrics_context=metrics_context,
            correlation_id=correlation_id,
            enhancement_level=enhancement_level,
            timestamp=timestamp
        )
        
        # Store enriched log
        await self._store_enriched_log(enriched_log)
        
        # Check for alert conditions
        await self._check_alert_conditions(enriched_log)
        
        return enriched_log
    
    async def _get_metrics_context(self, timestamp: float) -> Dict[str, Any]:
        """Get metrics context for the given timestamp"""
        window_start = int(timestamp - 30)  # 30-second window
        window_end = int(timestamp)
        
        metrics_data = {}
        
        # Collect system metrics from the time window
        for ts in range(window_start, window_end + 1):
            key = f"metrics:{ts}"
            data = await self.redis_client.hgetall(key)
            if data:
                for field, value in data.items():
                    if field != 'timestamp':
                        metrics_data.setdefault(field, []).append(float(value))
        
        # Calculate aggregated metrics
        context = {}
        for metric, values in metrics_data.items():
            if values:
                context[f"{metric}_avg"] = sum(values) / len(values)
                context[f"{metric}_max"] = max(values)
                context[f"{metric}_min"] = min(values)
        
        return context
    
    def _calculate_enhancement_level(self, metrics_context: Dict[str, Any], log_entry: Dict[str, Any]) -> str:
        """Calculate how much to enhance the log based on metrics and log content"""
        cpu_avg = metrics_context.get('cpu_avg', 0)
        memory_avg = metrics_context.get('memory_avg', 0)
        
        log_level = log_entry.get('level', '').upper()
        
        # Critical enhancement for errors during high resource usage
        if log_level == 'ERROR' and (cpu_avg > 80 or memory_avg > 75):
            return 'CRITICAL'
        
        # High enhancement for warnings during moderate resource usage
        if log_level in ['ERROR', 'WARNING'] and (cpu_avg > 60 or memory_avg > 60):
            return 'HIGH'
        
        # Normal enhancement for all other cases
        return 'NORMAL'
    
    async def _store_enriched_log(self, enriched_log: EnrichedLog):
        """Store enriched log in Redis"""
        key = f"enriched_logs:{enriched_log.correlation_id}"
        data = json.dumps(asdict(enriched_log), default=str)
        
        await self.redis_client.set(key, data, ex=86400)  # 24-hour expiry
        
        # Also add to a time-ordered list for querying
        list_key = f"logs_timeline:{int(enriched_log.timestamp // 3600)}"  # Hourly buckets
        await self.redis_client.lpush(list_key, enriched_log.correlation_id)
        await self.redis_client.expire(list_key, 86400)
    
    async def _check_alert_conditions(self, enriched_log: EnrichedLog):
        """Check if alert conditions are met"""
        metrics = enriched_log.metrics_context
        cpu_avg = metrics.get('cpu_avg', 0)
        memory_avg = metrics.get('memory_avg', 0)
        
        alerts = []
        
        if cpu_avg > self.alert_thresholds.get('cpu_critical', 90):
            alerts.append({
                'type': 'CPU_CRITICAL',
                'value': cpu_avg,
                'threshold': self.alert_thresholds['cpu_critical'],
                'correlation_id': enriched_log.correlation_id
            })
            
        if memory_avg > self.alert_thresholds.get('memory_critical', 85):
            alerts.append({
                'type': 'MEMORY_CRITICAL', 
                'value': memory_avg,
                'threshold': self.alert_thresholds['memory_critical'],
                'correlation_id': enriched_log.correlation_id
            })
        
        # Store alerts
        for alert in alerts:
            alert_key = f"alerts:{int(time.time())}"
            await self.redis_client.set(alert_key, json.dumps(alert), ex=3600)
            logger.warning("APM Alert generated", alert=alert)
    
    async def get_recent_logs(self, hours: int = 1) -> List[EnrichedLog]:
        """Get recent enriched logs"""
        current_hour = int(time.time() // 3600)
        logs = []
        
        for hour_offset in range(hours):
            list_key = f"logs_timeline:{current_hour - hour_offset}"
            correlation_ids = await self.redis_client.lrange(list_key, 0, -1)
            
            for correlation_id in correlation_ids:
                key = f"enriched_logs:{correlation_id.decode()}"
                data = await self.redis_client.get(key)
                if data:
                    log_data = json.loads(data)
                    logs.append(EnrichedLog(**log_data))
        
        return sorted(logs, key=lambda x: x.timestamp, reverse=True)
EOF

# API server
cat > src/api/server.py << 'EOF'
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import asyncio
import json
import time
from typing import Dict, Any, List
import redis.asyncio as redis
import structlog
import yaml
from pathlib import Path

from collectors.system_metrics import SystemMetricsCollector
from collectors.app_metrics import AppMetricsCollector
from correlation.engine import CorrelationEngine

logger = structlog.get_logger()

# Load configuration
config_path = Path("config/apm_config.yaml")
with open(config_path) as f:
    config = yaml.safe_load(f)

app = FastAPI(title="APM Integration API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global components
redis_client = None
system_collector = None
app_collector = None
correlation_engine = None
websocket_connections = []

@app.on_event("startup")
async def startup_event():
    global redis_client, system_collector, app_collector, correlation_engine
    
    # Initialize Redis connection
    redis_client = redis.Redis.from_url(config['apm']['storage']['redis_url'])
    
    # Initialize collectors
    system_collector = SystemMetricsCollector(redis_client, config['apm']['metrics']['collection_interval'])
    app_collector = AppMetricsCollector(redis_client)
    correlation_engine = CorrelationEngine(redis_client, config['apm'])
    
    # Start system metrics collection
    asyncio.create_task(system_collector.start_collection())
    
    logger.info("APM Integration API started successfully")

@app.on_event("shutdown") 
async def shutdown_event():
    if system_collector:
        system_collector.stop()
    if redis_client:
        await redis_client.close()

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": time.time()}

@app.post("/logs")
async def process_log(log_data: Dict[str, Any]):
    """Process and enrich a log entry"""
    try:
        # Record request for app metrics
        start_time = time.time()
        
        enriched_log = await correlation_engine.process_log_entry(log_data)
        
        # Record response time
        response_time = (time.time() - start_time) * 1000
        await app_collector.record_request(response_time)
        
        # Broadcast to WebSocket clients
        await broadcast_log_update(enriched_log)
        
        return {
            "status": "processed",
            "correlation_id": enriched_log.correlation_id,
            "enhancement_level": enriched_log.enhancement_level
        }
    
    except Exception as e:
        await app_collector.record_request(0, is_error=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/metrics/current")
async def get_current_metrics():
    """Get current system and application metrics"""
    # Get latest system metrics
    current_time = int(time.time())
    system_key = f"metrics:{current_time}"
    system_data = await redis_client.hgetall(system_key)
    
    # Get application metrics
    app_metrics = await app_collector.get_current_metrics()
    
    return {
        "system": {k.decode(): float(v) for k, v in system_data.items() if k.decode() != 'timestamp'},
        "application": {
            "request_count": app_metrics.request_count,
            "error_count": app_metrics.error_count,
            "avg_response_time": app_metrics.response_time_avg,
            "p95_response_time": app_metrics.response_time_p95,
            "active_connections": app_metrics.active_connections
        },
        "timestamp": current_time
    }

@app.get("/logs/recent")
async def get_recent_logs(hours: int = 1):
    """Get recent enriched logs"""
    logs = await correlation_engine.get_recent_logs(hours)
    return [log.__dict__ for log in logs]

@app.get("/alerts/recent")
async def get_recent_alerts():
    """Get recent alerts"""
    current_time = int(time.time())
    alerts = []
    
    # Get alerts from the last hour
    for i in range(3600):  # Last hour in seconds
        key = f"alerts:{current_time - i}"
        data = await redis_client.get(key)
        if data:
            alerts.append(json.loads(data))
    
    return sorted(alerts, key=lambda x: x.get('timestamp', 0), reverse=True)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    websocket_connections.append(websocket)
    
    try:
        while True:
            # Send periodic updates
            await asyncio.sleep(5)
            metrics = await get_current_metrics()
            await websocket.send_json({
                "type": "metrics_update",
                "data": metrics
            })
    except WebSocketDisconnect:
        websocket_connections.remove(websocket)

async def broadcast_log_update(enriched_log):
    """Broadcast log update to all WebSocket connections"""
    message = {
        "type": "log_update", 
        "data": enriched_log.__dict__
    }
    
    for websocket in websocket_connections[:]:  # Copy list to avoid modification during iteration
        try:
            await websocket.send_json(message)
        except:
            websocket_connections.remove(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# React frontend components
cat > frontend/src/App.js << 'EOF'
import React, { useState, useEffect } from 'react';
import './App.css';
import Dashboard from './components/Dashboard';
import LogViewer from './components/LogViewer';
import AlertsPanel from './components/AlertsPanel';

function App() {
  const [currentView, setCurrentView] = useState('dashboard');
  const [wsConnected, setWsConnected] = useState(false);

  useEffect(() => {
    // WebSocket connection for real-time updates
    const ws = new WebSocket('ws://localhost:8000/ws');
    
    ws.onopen = () => {
      setWsConnected(true);
      console.log('WebSocket connected');
    };
    
    ws.onclose = () => {
      setWsConnected(false);
      console.log('WebSocket disconnected');
    };
    
    return () => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.close();
      }
    };
  }, []);

  const navItems = [
    { id: 'dashboard', label: 'Dashboard', icon: '📊' },
    { id: 'logs', label: 'Log Viewer', icon: '📝' },
    { id: 'alerts', label: 'Alerts', icon: '🚨' }
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      {/* Header */}
      <header className="bg-white shadow-lg border-b-2 border-indigo-200">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-xl">🔍</span>
              </div>
              <div>
                <h1 className="text-2xl font-bold text-gray-900">APM Integration</h1>
                <p className="text-sm text-gray-600">Application Performance Monitoring</p>
              </div>
            </div>
            <div className="flex items-center space-x-2">
              <div className={`w-3 h-3 rounded-full ${wsConnected ? 'bg-green-500' : 'bg-red-500'}`}></div>
              <span className="text-sm text-gray-600">
                {wsConnected ? 'Connected' : 'Disconnected'}
              </span>
            </div>
          </div>
        </div>
      </header>

      {/* Navigation */}
      <nav className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-6">
          <div className="flex space-x-8">
            {navItems.map((item) => (
              <button
                key={item.id}
                onClick={() => setCurrentView(item.id)}
                className={`py-4 px-2 border-b-2 font-medium text-sm transition-colors duration-200 ${
                  currentView === item.id
                    ? 'border-indigo-500 text-indigo-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <span className="mr-2">{item.icon}</span>
                {item.label}
              </button>
            ))}
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-6 py-8">
        {currentView === 'dashboard' && <Dashboard />}
        {currentView === 'logs' && <LogViewer />}
        {currentView === 'alerts' && <AlertsPanel />}
      </main>
    </div>
  );
}

export default App;
EOF

# Dashboard component
cat > frontend/src/components/Dashboard.js << 'EOF'
import React, { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, BarChart, Bar } from 'recharts';

const Dashboard = () => {
  const [metrics, setMetrics] = useState(null);
  const [historicalData, setHistoricalData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchCurrentMetrics();
    const interval = setInterval(fetchCurrentMetrics, 5000);
    return () => clearInterval(interval);
  }, []);

  const fetchCurrentMetrics = async () => {
    try {
      const response = await fetch('/metrics/current');
      const data = await response.json();
      setMetrics(data);
      
      // Update historical data
      setHistoricalData(prev => {
        const newData = [...prev, {
          timestamp: new Date(data.timestamp * 1000).toLocaleTimeString(),
          cpu: data.system.cpu || 0,
          memory: data.system.memory || 0,
          requests: data.application.request_count || 0,
          responseTime: data.application.avg_response_time || 0
        }];
        // Keep only last 20 data points
        return newData.slice(-20);
      });
      
      setLoading(false);
    } catch (error) {
      console.error('Error fetching metrics:', error);
    }
  };

  if (loading || !metrics) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  const MetricCard = ({ title, value, unit, icon, trend }) => (
    <div className="bg-white rounded-xl shadow-md p-6 border border-gray-100 hover:shadow-lg transition-shadow duration-300">
      <div className="flex items-center justify-between mb-2">
        <h3 className="text-sm font-medium text-gray-600">{title}</h3>
        <span className="text-2xl">{icon}</span>
      </div>
      <div className="flex items-center space-x-2">
        <span className="text-2xl font-bold text-gray-900">{value}</span>
        <span className="text-sm text-gray-500">{unit}</span>
        {trend && (
          <span className={`text-xs px-2 py-1 rounded-full ${
            trend > 0 ? 'bg-red-100 text-red-600' : 'bg-green-100 text-green-600'
          }`}>
            {trend > 0 ? '↑' : '↓'} {Math.abs(trend)}%
          </span>
        )}
      </div>
    </div>
  );

  return (
    <div className="space-y-6">
      {/* Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <MetricCard
          title="CPU Usage"
          value={metrics.system.cpu?.toFixed(1) || '0.0'}
          unit="%"
          icon="💻"
        />
        <MetricCard
          title="Memory Usage"
          value={metrics.system.memory?.toFixed(1) || '0.0'}
          unit="%"
          icon="🧠"
        />
        <MetricCard
          title="Response Time"
          value={metrics.application.avg_response_time?.toFixed(0) || '0'}
          unit="ms"
          icon="⚡"
        />
        <MetricCard
          title="Request Count"
          value={metrics.application.request_count || 0}
          unit="req/min"
          icon="📈"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* System Metrics Chart */}
        <div className="bg-white rounded-xl shadow-md p-6 border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">System Performance</h3>
          <LineChart width={400} height={250} data={historicalData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="timestamp" stroke="#6b7280" />
            <YAxis stroke="#6b7280" />
            <Tooltip 
              contentStyle={{
                backgroundColor: 'white',
                border: '1px solid #e5e7eb',
                borderRadius: '8px',
                boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
              }}
            />
            <Legend />
            <Line 
              type="monotone" 
              dataKey="cpu" 
              stroke="#3b82f6" 
              strokeWidth={2}
              name="CPU %"
              dot={{ fill: '#3b82f6', strokeWidth: 2, r: 4 }}
            />
            <Line 
              type="monotone" 
              dataKey="memory" 
              stroke="#10b981" 
              strokeWidth={2}
              name="Memory %"
              dot={{ fill: '#10b981', strokeWidth: 2, r: 4 }}
            />
          </LineChart>
        </div>

        {/* Application Metrics Chart */}
        <div className="bg-white rounded-xl shadow-md p-6 border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Application Performance</h3>
          <LineChart width={400} height={250} data={historicalData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="timestamp" stroke="#6b7280" />
            <YAxis stroke="#6b7280" />
            <Tooltip 
              contentStyle={{
                backgroundColor: 'white',
                border: '1px solid #e5e7eb',
                borderRadius: '8px',
                boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
              }}
            />
            <Legend />
            <Line 
              type="monotone" 
              dataKey="responseTime" 
              stroke="#f59e0b" 
              strokeWidth={2}
              name="Response Time (ms)"
              dot={{ fill: '#f59e0b', strokeWidth: 2, r: 4 }}
            />
          </LineChart>
        </div>
      </div>

      {/* Status Indicators */}
      <div className="bg-white rounded-xl shadow-md p-6 border border-gray-100">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">System Status</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="flex items-center space-x-3 p-4 bg-green-50 rounded-lg">
            <div className="w-3 h-3 bg-green-500 rounded-full"></div>
            <div>
              <p className="text-sm font-medium text-green-800">Metrics Collection</p>
              <p className="text-xs text-green-600">Active</p>
            </div>
          </div>
          <div className="flex items-center space-x-3 p-4 bg-blue-50 rounded-lg">
            <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
            <div>
              <p className="text-sm font-medium text-blue-800">Log Correlation</p>
              <p className="text-xs text-blue-600">Running</p>
            </div>
          </div>
          <div className="flex items-center space-x-3 p-4 bg-purple-50 rounded-lg">
            <div className="w-3 h-3 bg-purple-500 rounded-full"></div>
            <div>
              <p className="text-sm font-medium text-purple-800">Alert Engine</p>
              <p className="text-xs text-purple-600">Monitoring</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
EOF

# Log viewer component  
cat > frontend/src/components/LogViewer.js << 'EOF'
import React, { useState, useEffect } from 'react';

const LogViewer = () => {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');

  useEffect(() => {
    fetchLogs();
    const interval = setInterval(fetchLogs, 10000); // Refresh every 10 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchLogs = async () => {
    try {
      const response = await fetch('/logs/recent?hours=1');
      const data = await response.json();
      setLogs(data);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching logs:', error);
    }
  };

  const filteredLogs = logs.filter(log => {
    if (filter === 'all') return true;
    if (filter === 'critical') return log.enhancement_level === 'CRITICAL';
    if (filter === 'high') return log.enhancement_level === 'HIGH';
    return log.enhancement_level === 'NORMAL';
  });

  const getEnhancementBadge = (level) => {
    const badges = {
      'CRITICAL': 'bg-red-100 text-red-800 border-red-200',
      'HIGH': 'bg-yellow-100 text-yellow-800 border-yellow-200',
      'NORMAL': 'bg-green-100 text-green-800 border-green-200'
    };
    return badges[level] || badges['NORMAL'];
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Controls */}
      <div className="bg-white rounded-xl shadow-md p-6 border border-gray-100">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-semibold text-gray-900">Enriched Logs</h2>
          <div className="flex items-center space-x-4">
            <label className="text-sm text-gray-600">Filter by enhancement:</label>
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              className="px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="all">All Levels</option>
              <option value="critical">Critical</option>
              <option value="high">High</option>
              <option value="normal">Normal</option>
            </select>
            <button
              onClick={fetchLogs}
              className="px-4 py-2 bg-indigo-600 text-white rounded-md text-sm hover:bg-indigo-700 transition-colors"
            >
              Refresh
            </button>
          </div>
        </div>
      </div>

      {/* Log Entries */}
      <div className="space-y-4">
        {filteredLogs.map((log, index) => (
          <div
            key={log.correlation_id || index}
            className="bg-white rounded-xl shadow-md border border-gray-100 hover:shadow-lg transition-shadow duration-300"
          >
            <div className="p-6">
              {/* Header */}
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center space-x-3">
                  <span className={`px-2 py-1 text-xs font-medium rounded-md border ${getEnhancementBadge(log.enhancement_level)}`}>
                    {log.enhancement_level}
                  </span>
                  <span className="text-sm text-gray-500">
                    {new Date(log.timestamp * 1000).toLocaleString()}
                  </span>
                </div>
                <code className="text-xs text-gray-400 font-mono">{log.correlation_id}</code>
              </div>

              {/* Original Log */}
              <div className="mb-4">
                <h4 className="text-sm font-medium text-gray-700 mb-2">Original Log Entry</h4>
                <div className="bg-gray-50 rounded-lg p-3">
                  <pre className="text-sm text-gray-800 whitespace-pre-wrap font-mono">
                    {JSON.stringify(log.original_log, null, 2)}
                  </pre>
                </div>
              </div>

              {/* Metrics Context */}
              {log.metrics_context && Object.keys(log.metrics_context).length > 0 && (
                <div>
                  <h4 className="text-sm font-medium text-gray-700 mb-2">Performance Context</h4>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    {Object.entries(log.metrics_context).map(([key, value]) => (
                      <div key={key} className="bg-indigo-50 rounded-lg p-3">
                        <p className="text-xs text-indigo-600 font-medium uppercase tracking-wide">
                          {key.replace('_', ' ')}
                        </p>
                        <p className="text-sm font-semibold text-indigo-900">
                          {typeof value === 'number' ? value.toFixed(2) : value}
                        </p>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        ))}
        
        {filteredLogs.length === 0 && (
          <div className="bg-white rounded-xl shadow-md p-12 text-center border border-gray-100">
            <div className="text-gray-400 text-4xl mb-4">📄</div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No logs found</h3>
            <p className="text-gray-500">No logs match the current filter criteria.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default LogViewer;
EOF

# Alerts panel component
cat > frontend/src/components/AlertsPanel.js << 'EOF'
import React, { useState, useEffect } from 'react';

const AlertsPanel = () => {
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchAlerts();
    const interval = setInterval(fetchAlerts, 5000); // Refresh every 5 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchAlerts = async () => {
    try {
      const response = await fetch('/alerts/recent');
      const data = await response.json();
      setAlerts(data);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching alerts:', error);
    }
  };

  const getAlertIcon = (type) => {
    const icons = {
      'CPU_CRITICAL': '🔥',
      'MEMORY_CRITICAL': '🧠',
      'RESPONSE_TIME_CRITICAL': '⚡',
      'ERROR_RATE_HIGH': '⚠️'
    };
    return icons[type] || '🚨';
  };

  const getAlertColor = (type) => {
    const colors = {
      'CPU_CRITICAL': 'border-red-200 bg-red-50',
      'MEMORY_CRITICAL': 'border-orange-200 bg-orange-50',
      'RESPONSE_TIME_CRITICAL': 'border-yellow-200 bg-yellow-50',
      'ERROR_RATE_HIGH': 'border-purple-200 bg-purple-50'
    };
    return colors[type] || 'border-red-200 bg-red-50';
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white rounded-xl shadow-md p-6 border border-gray-100">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-xl font-semibold text-gray-900">System Alerts</h2>
            <p className="text-sm text-gray-600">Real-time performance alerts and notifications</p>
          </div>
          <div className="flex items-center space-x-2">
            <div className="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
            <span className="text-sm text-gray-600">Monitoring Active</span>
          </div>
        </div>
      </div>

      {/* Alerts List */}
      <div className="space-y-4">
        {alerts.map((alert, index) => (
          <div
            key={`${alert.correlation_id}_${index}`}
            className={`bg-white rounded-xl shadow-md border-2 p-6 ${getAlertColor(alert.type)} hover:shadow-lg transition-shadow duration-300`}
          >
            <div className="flex items-start space-x-4">
              <div className="text-3xl">{getAlertIcon(alert.type)}</div>
              <div className="flex-1">
                <div className="flex items-center justify-between mb-2">
                  <h3 className="text-lg font-semibold text-gray-900">
                    {alert.type.replace('_', ' ').toLowerCase().replace(/\b\w/g, l => l.toUpperCase())}
                  </h3>
                  <span className="text-sm text-gray-500">
                    {alert.timestamp ? new Date(alert.timestamp * 1000).toLocaleString() : 'Just now'}
                  </span>
                </div>
                
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mb-4">
                  <div className="bg-white bg-opacity-50 rounded-lg p-3">
                    <p className="text-xs text-gray-600 font-medium uppercase tracking-wide">Current Value</p>
                    <p className="text-lg font-bold text-gray-900">
                      {alert.value?.toFixed(1) || 'N/A'}{alert.type.includes('CPU') || alert.type.includes('MEMORY') ? '%' : 'ms'}
                    </p>
                  </div>
                  
                  <div className="bg-white bg-opacity-50 rounded-lg p-3">
                    <p className="text-xs text-gray-600 font-medium uppercase tracking-wide">Threshold</p>
                    <p className="text-lg font-bold text-gray-900">
                      {alert.threshold}{alert.type.includes('CPU') || alert.type.includes('MEMORY') ? '%' : 'ms'}
                    </p>
                  </div>
                  
                  <div className="bg-white bg-opacity-50 rounded-lg p-3">
                    <p className="text-xs text-gray-600 font-medium uppercase tracking-wide">Severity</p>
                    <p className="text-lg font-bold text-red-600">Critical</p>
                  </div>
                </div>
                
                <div className="flex items-center justify-between">
                  <code className="text-xs text-gray-500 font-mono bg-white bg-opacity-50 px-2 py-1 rounded">
                    {alert.correlation_id}
                  </code>
                  <div className="flex space-x-2">
                    <button className="px-3 py-1 bg-indigo-600 text-white text-xs rounded-md hover:bg-indigo-700 transition-colors">
                      View Logs
                    </button>
                    <button className="px-3 py-1 bg-gray-600 text-white text-xs rounded-md hover:bg-gray-700 transition-colors">
                      Acknowledge
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        ))}
        
        {alerts.length === 0 && (
          <div className="bg-white rounded-xl shadow-md p-12 text-center border border-gray-100">
            <div className="text-gray-400 text-4xl mb-4">✅</div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No Active Alerts</h3>
            <p className="text-gray-500">All systems are operating within normal parameters.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default AlertsPanel;
EOF

# Test files
cat > tests/test_correlation_engine.py << 'EOF'
import pytest
import asyncio
import redis.asyncio as redis
from unittest.mock import AsyncMock, Mock
import json
import time

from src.correlation.engine import CorrelationEngine, EnrichedLog

@pytest.fixture
async def redis_client():
    # Mock Redis client
    mock_redis = AsyncMock()
    mock_redis.hgetall = AsyncMock(return_value={
        b'cpu': b'75.5',
        b'memory': b'60.2',
        b'load_1': b'1.5'
    })
    mock_redis.set = AsyncMock()
    mock_redis.lpush = AsyncMock()
    mock_redis.expire = AsyncMock()
    return mock_redis

@pytest.fixture
def correlation_config():
    return {
        'correlation': {
            'window_size_seconds': 30,
            'threshold_cpu': 80.0,
            'threshold_memory': 75.0,
        },
        'alerts': {
            'cpu_critical': 90.0,
            'memory_critical': 85.0
        }
    }

@pytest.mark.asyncio
async def test_process_log_entry(redis_client, correlation_config):
    """Test processing a log entry with correlation"""
    engine = CorrelationEngine(redis_client, correlation_config)
    
    log_entry = {
        'timestamp': time.time(),
        'level': 'ERROR',
        'message': 'Database connection failed',
        'service': 'api'
    }
    
    enriched_log = await engine.process_log_entry(log_entry)
    
    assert isinstance(enriched_log, EnrichedLog)
    assert enriched_log.original_log == log_entry
    assert enriched_log.enhancement_level in ['NORMAL', 'HIGH', 'CRITICAL']
    assert enriched_log.correlation_id.startswith('corr_')

@pytest.mark.asyncio
async def test_enhancement_level_critical(redis_client, correlation_config):
    """Test critical enhancement level calculation"""
    engine = CorrelationEngine(redis_client, correlation_config)
    
    # Mock high CPU metrics
    redis_client.hgetall = AsyncMock(return_value={
        b'cpu': b'85.0',
        b'memory': b'80.0'
    })
    
    log_entry = {
        'timestamp': time.time(),
        'level': 'ERROR',
        'message': 'System overload'
    }
    
    enriched_log = await engine.process_log_entry(log_entry)
    assert enriched_log.enhancement_level == 'CRITICAL'

@pytest.mark.asyncio
async def test_metrics_context_aggregation(redis_client, correlation_config):
    """Test metrics context aggregation"""
    engine = CorrelationEngine(redis_client, correlation_config)
    
    log_entry = {
        'timestamp': time.time(),
        'level': 'INFO',
        'message': 'Request processed'
    }
    
    enriched_log = await engine.process_log_entry(log_entry)
    
    # Verify metrics context is populated
    assert 'cpu_avg' in enriched_log.metrics_context
    assert 'memory_avg' in enriched_log.metrics_context
    assert enriched_log.metrics_context['cpu_avg'] == 75.5

def test_calculate_enhancement_level():
    """Test enhancement level calculation logic"""
    engine = CorrelationEngine(None, {'alerts': {}})
    
    # Test critical level
    metrics = {'cpu_avg': 85.0, 'memory_avg': 80.0}
    log_entry = {'level': 'ERROR'}
    level = engine._calculate_enhancement_level(metrics, log_entry)
    assert level == 'CRITICAL'
    
    # Test high level
    metrics = {'cpu_avg': 65.0, 'memory_avg': 65.0}
    log_entry = {'level': 'WARNING'}
    level = engine._calculate_enhancement_level(metrics, log_entry)
    assert level == 'HIGH'
    
    # Test normal level
    metrics = {'cpu_avg': 30.0, 'memory_avg': 40.0}
    log_entry = {'level': 'INFO'}
    level = engine._calculate_enhancement_level(metrics, log_entry)
    assert level == 'NORMAL'
EOF

cat > tests/test_system_metrics.py << 'EOF'
import pytest
import asyncio
from unittest.mock import AsyncMock, patch, Mock

from src.collectors.system_metrics import SystemMetricsCollector, SystemMetrics

@pytest.fixture
async def redis_client():
    mock_redis = AsyncMock()
    mock_redis.hset = AsyncMock()
    mock_redis.expire = AsyncMock()
    return mock_redis

@pytest.mark.asyncio
async def test_metrics_collection(redis_client):
    """Test system metrics collection"""
    collector = SystemMetricsCollector(redis_client, collection_interval=1)
    
    with patch('psutil.cpu_percent', return_value=45.5), \
         patch('psutil.virtual_memory') as mock_memory, \
         patch('psutil.disk_io_counters', return_value=Mock(read_bytes=1000, write_bytes=2000)), \
         patch('psutil.net_io_counters', return_value=Mock(bytes_sent=3000, bytes_recv=4000)), \
         patch('psutil.getloadavg', return_value=(1.0, 1.5, 2.0)):
        
        mock_memory.return_value.percent = 67.8
        
        metrics = await collector._collect_metrics()
        
        assert isinstance(metrics, SystemMetrics)
        assert metrics.cpu_percent == 45.5
        assert metrics.memory_percent == 67.8
        assert metrics.load_average == (1.0, 1.5, 2.0)

@pytest.mark.asyncio
async def test_metrics_storage(redis_client):
    """Test metrics storage in Redis"""
    collector = SystemMetricsCollector(redis_client)
    
    metrics = SystemMetrics(
        timestamp=1234567890.0,
        cpu_percent=55.5,
        memory_percent=70.0,
        disk_io={'read_bytes': 1000},
        network_io={'bytes_sent': 2000},
        load_average=(1.0, 1.5, 2.0)
    )
    
    await collector._store_metrics(metrics)
    
    # Verify Redis operations
    redis_client.hset.assert_called_once()
    redis_client.expire.assert_called_once_with("metrics:1234567890", 86400)

@pytest.mark.asyncio
async def test_collection_loop_start_stop():
    """Test collector start/stop functionality"""
    redis_client = AsyncMock()
    collector = SystemMetricsCollector(redis_client, collection_interval=0.1)
    
    # Start collection
    task = asyncio.create_task(collector.start_collection())
    await asyncio.sleep(0.05)  # Let it run briefly
    
    # Stop collection
    collector.stop()
    await asyncio.sleep(0.15)  # Wait for graceful shutdown
    
    assert not collector.running
    task.cancel()
    
    try:
        await task
    except asyncio.CancelledError:
        pass
EOF

# Build and test scripts
cat > build.sh << 'EOF'
#!/bin/bash

echo "🏗️ Building Day 130 APM Integration System"
echo "=========================================="

# Check Python version
python3.11 --version || { echo "Python 3.11 not found!"; exit 1; }

# Create and activate virtual environment
echo "📦 Creating Python virtual environment..."
python3.11 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "⬇️ Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Install Node.js dependencies for frontend
echo "📱 Installing React dependencies..."
cd frontend
npm install
cd ..

# Run tests
echo "🧪 Running Python tests..."
python -m pytest tests/ -v

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo ""
    echo "🚀 Next steps:"
    echo "  1. Run './start.sh' to start the system"
    echo "  2. Visit http://localhost:3000 for the dashboard"
    echo "  3. API available at http://localhost:8000"
else
    echo "❌ Build failed!"
    exit 1
fi
EOF

cat > start.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting APM Integration System"
echo "================================="

# Activate virtual environment
source venv/bin/activate

# Start Redis if not running
if ! pgrep redis-server > /dev/null; then
    echo "📡 Starting Redis server..."
    redis-server --daemonize yes --port 6379
fi

# Start backend API
echo "🔧 Starting FastAPI backend..."
cd src && python -m api.server &
BACKEND_PID=$!
cd ..

# Start frontend
echo "🌐 Starting React frontend..."
cd frontend && npm start &
FRONTEND_PID=$!
cd ..

echo ""
echo "✅ System started successfully!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔧 Backend API: http://localhost:8000"
echo "📊 API Docs: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop all services"

# Create PID file for cleanup
echo "$BACKEND_PID $FRONTEND_PID" > .pids

# Wait for interrupt
trap 'kill $(cat .pids) 2>/dev/null; rm -f .pids; exit' INT
wait
EOF

cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping APM Integration System"
echo "================================="

# Kill processes from PID file
if [ -f .pids ]; then
    kill $(cat .pids) 2>/dev/null
    rm -f .pids
    echo "✅ Backend and frontend stopped"
fi

# Stop any remaining processes
pkill -f "python.*api.server" 2>/dev/null
pkill -f "npm.*start" 2>/dev/null

# Stop Redis if we started it
redis-cli shutdown 2>/dev/null || true

echo "✅ All services stopped"
EOF

# Docker files
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    redis-server \
    && rm -rf /var/lib/apt/lists/*

# Copy Python requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY config/ ./config/
COPY tests/ ./tests/

# Expose ports
EXPOSE 8000

# Start command
CMD ["python", "src/api/server.py"]
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

  apm-backend:
    build: .
    ports:
      - "8000:8000"
    depends_on:
      - redis
    environment:
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - ./config:/app/config
      - ./logs:/app/logs

  apm-frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    depends_on:
      - apm-backend
    environment:
      - REACT_APP_API_URL=http://localhost:8000

volumes:
  redis_data:
EOF

# Frontend Dockerfile
cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY src/ ./src/
COPY public/ ./public/

# Expose port
EXPOSE 3000

# Start command
CMD ["npm", "start"]
EOF

# Demo script
cat > demo.py << 'EOF'
#!/usr/bin/env python3

"""
APM Integration Demo Script
Generates sample logs and metrics to demonstrate the system
"""

import asyncio
import json
import random
import time
from datetime import datetime
import aiohttp

async def generate_sample_logs():
    """Generate sample log entries with various levels and scenarios"""
    
    services = ['api', 'database', 'auth', 'payment', 'notification']
    levels = ['INFO', 'WARNING', 'ERROR']
    messages = {
        'INFO': [
            'Request processed successfully',
            'User logged in',
            'Cache hit for key',
            'Configuration loaded',
            'Health check passed'
        ],
        'WARNING': [
            'High memory usage detected',
            'Connection pool nearly full',
            'Slow query detected',
            'Rate limit approaching',
            'Disk space low'
        ],
        'ERROR': [
            'Database connection failed',
            'Authentication failed',
            'Payment processing error',
            'Service unavailable',
            'Timeout occurred'
        ]
    }
    
    async with aiohttp.ClientSession() as session:
        for i in range(50):
            service = random.choice(services)
            level = random.choice(levels)
            message = random.choice(messages[level])
            
            log_entry = {
                'timestamp': time.time(),
                'level': level,
                'service': service,
                'message': message,
                'request_id': f'req_{random.randint(1000, 9999)}',
                'user_id': random.randint(1, 1000)
            }
            
            try:
                async with session.post('http://localhost:8000/logs', json=log_entry) as response:
                    if response.status == 200:
                        result = await response.json()
                        print(f"✅ Log processed: {level} - {message[:30]}... (Enhancement: {result['enhancement_level']})")
                    else:
                        print(f"❌ Failed to process log: {response.status}")
            except Exception as e:
                print(f"❌ Error sending log: {e}")
            
            # Random delay between logs
            await asyncio.sleep(random.uniform(0.5, 2.0))

async def monitor_system():
    """Monitor system metrics and display current status"""
    async with aiohttp.ClientSession() as session:
        for i in range(20):  # Monitor for ~2 minutes
            try:
                async with session.get('http://localhost:8000/metrics/current') as response:
                    if response.status == 200:
                        metrics = await response.json()
                        print(f"📊 System Status - CPU: {metrics['system'].get('cpu', 0):.1f}%, "
                              f"Memory: {metrics['system'].get('memory', 0):.1f}%, "
                              f"Requests: {metrics['application']['request_count']}")
                    else:
                        print(f"❌ Failed to get metrics: {response.status}")
            except Exception as e:
                print(f"❌ Error getting metrics: {e}")
            
            await asyncio.sleep(5)

async def main():
    """Run the complete demo"""
    print("🎬 Starting APM Integration Demo")
    print("=" * 40)
    print()
    print("This demo will:")
    print("1. Generate sample log entries with different levels")
    print("2. Show real-time correlation with system metrics")
    print("3. Demonstrate alert generation")
    print("4. Display enriched logs with performance context")
    print()
    print("👀 Watch the dashboard at: http://localhost:3000")
    print("🔍 API docs at: http://localhost:8000/docs")
    print()
    
    # Wait for user to be ready
    input("Press Enter to start the demo...")
    
    # Run log generation and monitoring concurrently
    await asyncio.gather(
        generate_sample_logs(),
        monitor_system()
    )
    
    print()
    print("✅ Demo completed!")
    print("🌐 Check the dashboard to see enriched logs and performance correlation")

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Frontend public files
mkdir -p frontend/public
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="APM Integration Dashboard" />
    <title>APM Integration Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

cat > frontend/src/App.css << 'EOF'
.App {
  text-align: center;
}

.App-logo {
  height: 40vmin;
  pointer-events: none;
}

@media (prefers-reduced-motion: no-preference) {
  .App-logo {
    animation: App-logo-spin infinite 20s linear;
  }
}

.App-header {
  background-color: #282c34;
  padding: 20px;
  color: white;
}

.App-link {
  color: #61dafb;
}

@keyframes App-logo-spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
EOF

cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './App.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Docker ignore
cat > .dockerignore << 'EOF'
node_modules
venv
__pycache__
*.pyc
.git
.gitignore
README.md
.env
logs
.pids
EOF

# Git ignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
venv/
env/

# Node.js
node_modules/
npm-debug.log*

# Logs
logs/
*.log

# Environment
.env

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Project specific
.pids
redis-data/
EOF

# Make scripts executable
chmod +x build.sh start.sh stop.sh demo.py

echo ""
echo "✅ Day 130 APM Integration project created successfully!"
echo ""
echo "📁 Project structure:"
echo "   src/              - Python backend source"
echo "   frontend/         - React dashboard"
echo "   tests/           - Test suite"
echo "   config/          - Configuration files"
echo ""
echo "🚀 Quick start:"
echo "   1. ./build.sh    - Build and test the system"
echo "   2. ./start.sh    - Start all services"
echo "   3. python demo.py - Run demonstration"
echo "   4. ./stop.sh     - Stop all services"
echo ""
echo "🌐 Endpoints:"
echo "   http://localhost:3000 - React Dashboard"
echo "   http://localhost:8000 - FastAPI Backend"
echo "   http://localhost:8000/docs - API Documentation"
echo ""
echo "🐳 Docker deployment:"
echo "   docker-compose up --build"
echo ""