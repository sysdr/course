#!/bin/bash

# Day 141: Metrics Export to Monitoring Systems - Complete Implementation
# Implements Prometheus and Datadog metrics export for distributed log processing

set -e

PROJECT_NAME="day141-metrics-export"
PYTHON_VERSION="3.11"

echo "🚀 Day 141: Setting up Metrics Export System"
echo "=============================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p ${PROJECT_NAME}/{src/{metrics,exporters,collectors,api},tests/{unit,integration},config,web/{public,src/{components,styles}},scripts,docker}

cd ${PROJECT_NAME}

# Create Python virtual environment
echo "🐍 Setting up Python ${PYTHON_VERSION} environment..."
python3 -m venv venv
source venv/bin/activate

# Create requirements.txt
echo "📦 Creating requirements.txt..."
cat > requirements.txt << 'EOF'
# Core dependencies
fastapi==0.110.2
uvicorn[standard]==0.29.0
pydantic==2.7.1
pydantic-settings==2.2.1

# Metrics export
prometheus-client==0.20.0
datadog==0.48.0
statsd==4.0.1

# Storage and caching
redis==5.0.4
aioredis==2.0.1

# HTTP client
aiohttp==3.9.5
httpx==0.27.0

# Testing
pytest==8.2.0
pytest-asyncio==0.23.6
pytest-cov==5.0.0

# Utilities
python-dotenv==1.0.1
structlog==24.2.0
pyyaml==6.0.1
colorama==0.4.6
psutil==5.9.8
EOF

pip install --upgrade pip
pip install -r requirements.txt

# Create configuration
echo "⚙️  Creating configuration files..."
cat > config/settings.yaml << 'EOF'
application:
  name: "log-processor"
  environment: "production"
  version: "1.0.0"

metrics:
  collection_interval: 10  # seconds
  export_interval: 30      # seconds
  cardinality_limit: 10000
  
prometheus:
  enabled: true
  port: 9090
  path: "/metrics"
  
datadog:
  enabled: true
  api_key: "${DATADOG_API_KEY}"
  app_key: "${DATADOG_APP_KEY}"
  host: "api.datadoghq.com"
  statsd_host: "localhost"
  statsd_port: 8125
  flush_interval: 10
  
redis:
  host: "localhost"
  port: 6379
  db: 0
  
api:
  host: "0.0.0.0"
  port: 8000
EOF

cat > config/.env.example << 'EOF'
DATADOG_API_KEY=your_datadog_api_key_here
DATADOG_APP_KEY=your_datadog_app_key_here
ENVIRONMENT=production
LOG_LEVEL=INFO
EOF

cp config/.env.example config/.env

# Create metrics registry
echo "📊 Creating metrics registry..."
cat > src/metrics/registry.py << 'EOF'
"""
Unified metrics registry for all monitoring backends.
Manages counters, gauges, histograms, and summaries.
"""
from prometheus_client import Counter, Gauge, Histogram, Summary, CollectorRegistry
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
from collections import defaultdict
import time
import threading
import structlog

logger = structlog.get_logger()

@dataclass
class MetricDefinition:
    """Definition of a metric with metadata"""
    name: str
    metric_type: str  # counter, gauge, histogram, summary
    description: str
    labels: List[str] = field(default_factory=list)
    buckets: Optional[List[float]] = None  # for histograms

class UnifiedMetricsRegistry:
    """
    Central registry managing metrics for multiple backends.
    Provides high-level API for instrumenting application code.
    """
    
    def __init__(self, namespace: str = "log_processor"):
        self.namespace = namespace
        self.prom_registry = CollectorRegistry()
        self._metrics = {}
        self._metric_values = defaultdict(float)
        self._labels_cache = {}
        self._cardinality_limit = 10000
        self._lock = threading.RLock()
        
        logger.info("metrics_registry_initialized", namespace=namespace)
        
    def register_counter(self, name: str, description: str, 
                        labels: List[str] = None) -> None:
        """Register a counter metric"""
        labels = labels or []
        full_name = f"{self.namespace}_{name}"
        
        if full_name not in self._metrics:
            self._metrics[full_name] = {
                'type': 'counter',
                'description': description,
                'labels': labels,
                'prometheus': Counter(
                    full_name, description, labels, registry=self.prom_registry
                )
            }
            logger.info("counter_registered", name=full_name, labels=labels)
    
    def register_gauge(self, name: str, description: str,
                      labels: List[str] = None) -> None:
        """Register a gauge metric"""
        labels = labels or []
        full_name = f"{self.namespace}_{name}"
        
        if full_name not in self._metrics:
            self._metrics[full_name] = {
                'type': 'gauge',
                'description': description,
                'labels': labels,
                'prometheus': Gauge(
                    full_name, description, labels, registry=self.prom_registry
                )
            }
            logger.info("gauge_registered", name=full_name, labels=labels)
    
    def register_histogram(self, name: str, description: str,
                          labels: List[str] = None,
                          buckets: tuple = None) -> None:
        """Register a histogram metric"""
        labels = labels or []
        buckets = buckets or (0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10)
        full_name = f"{self.namespace}_{name}"
        
        if full_name not in self._metrics:
            self._metrics[full_name] = {
                'type': 'histogram',
                'description': description,
                'labels': labels,
                'buckets': buckets,
                'prometheus': Histogram(
                    full_name, description, labels, buckets=buckets,
                    registry=self.prom_registry
                )
            }
            logger.info("histogram_registered", name=full_name, labels=labels)
    
    def inc_counter(self, name: str, value: float = 1, labels: Dict[str, str] = None) -> None:
        """Increment a counter"""
        full_name = f"{self.namespace}_{name}"
        labels = labels or {}
        
        if full_name in self._metrics:
            metric = self._metrics[full_name]
            if metric['type'] == 'counter':
                if labels:
                    metric['prometheus'].labels(**labels).inc(value)
                else:
                    metric['prometheus'].inc(value)
                    
                # Store for Datadog export
                label_key = self._make_label_key(full_name, labels)
                with self._lock:
                    self._metric_values[label_key] += value
    
    def set_gauge(self, name: str, value: float, labels: Dict[str, str] = None) -> None:
        """Set a gauge value"""
        full_name = f"{self.namespace}_{name}"
        labels = labels or {}
        
        if full_name in self._metrics:
            metric = self._metrics[full_name]
            if metric['type'] == 'gauge':
                if labels:
                    metric['prometheus'].labels(**labels).set(value)
                else:
                    metric['prometheus'].set(value)
                    
                # Store for Datadog export
                label_key = self._make_label_key(full_name, labels)
                with self._lock:
                    self._metric_values[label_key] = value
    
    def observe_histogram(self, name: str, value: float, labels: Dict[str, str] = None) -> None:
        """Observe a value in histogram"""
        full_name = f"{self.namespace}_{name}"
        labels = labels or {}
        
        if full_name in self._metrics:
            metric = self._metrics[full_name]
            if metric['type'] == 'histogram':
                if labels:
                    metric['prometheus'].labels(**labels).observe(value)
                else:
                    metric['prometheus'].observe(value)
    
    def get_prometheus_registry(self) -> CollectorRegistry:
        """Get Prometheus collector registry"""
        return self.prom_registry
    
    def get_all_metrics(self) -> Dict[str, Any]:
        """Get all metrics for export"""
        with self._lock:
            return dict(self._metric_values)
    
    def _make_label_key(self, name: str, labels: Dict[str, str]) -> str:
        """Create unique key from metric name and labels"""
        if not labels:
            return name
        label_str = ",".join(f"{k}={v}" for k, v in sorted(labels.items()))
        return f"{name}{{{label_str}}}"
    
    def check_cardinality(self) -> Dict[str, int]:
        """Check metric cardinality"""
        cardinality = defaultdict(int)
        for key in self._metric_values.keys():
            metric_name = key.split('{')[0]
            cardinality[metric_name] += 1
        return dict(cardinality)

# Global registry instance
global_registry = UnifiedMetricsRegistry()
EOF

# Create Prometheus exporter
echo "🎯 Creating Prometheus exporter..."
cat > src/exporters/prometheus_exporter.py << 'EOF'
"""
Prometheus metrics exporter.
Exposes /metrics endpoint in OpenMetrics format.
"""
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from fastapi import Response
import structlog

logger = structlog.get_logger()

class PrometheusExporter:
    """Exports metrics in Prometheus format"""
    
    def __init__(self, registry):
        self.registry = registry
        self.prom_registry = registry.get_prometheus_registry()
        logger.info("prometheus_exporter_initialized")
    
    def get_metrics(self) -> Response:
        """Generate Prometheus metrics response"""
        try:
            metrics_output = generate_latest(self.prom_registry)
            return Response(
                content=metrics_output,
                media_type=CONTENT_TYPE_LATEST
            )
        except Exception as e:
            logger.error("metrics_generation_failed", error=str(e))
            return Response(content=b"", status_code=500)
    
    def get_metrics_text(self) -> str:
        """Get metrics as text for display"""
        return generate_latest(self.prom_registry).decode('utf-8')
EOF

# Create Datadog exporter
echo "📤 Creating Datadog exporter..."
cat > src/exporters/datadog_exporter.py << 'EOF'
"""
Datadog metrics exporter.
Pushes metrics via DogStatsD and HTTP API.
"""
from datadog import initialize, api
from datadog import statsd
import time
from typing import Dict, Any, List
import structlog
import asyncio

logger = structlog.get_logger()

class DatadogExporter:
    """Exports metrics to Datadog"""
    
    def __init__(self, api_key: str, app_key: str, 
                 statsd_host: str = "localhost", statsd_port: int = 8125):
        self.api_key = api_key
        self.app_key = app_key
        
        # Initialize Datadog
        options = {
            'api_key': api_key,
            'app_key': app_key
        }
        initialize(**options)
        
        # Configure StatsD
        statsd.host = statsd_host
        statsd.port = statsd_port
        
        self.metrics_buffer = []
        self.last_flush = time.time()
        self.flush_interval = 10  # seconds
        
        logger.info("datadog_exporter_initialized",
                   statsd_host=statsd_host, statsd_port=statsd_port)
    
    def gauge(self, metric: str, value: float, tags: List[str] = None) -> None:
        """Send gauge metric"""
        try:
            statsd.gauge(metric, value, tags=tags or [])
        except Exception as e:
            logger.error("gauge_send_failed", metric=metric, error=str(e))
    
    def increment(self, metric: str, value: float = 1, tags: List[str] = None) -> None:
        """Send counter increment"""
        try:
            statsd.increment(metric, value, tags=tags or [])
        except Exception as e:
            logger.error("increment_send_failed", metric=metric, error=str(e))
    
    def histogram(self, metric: str, value: float, tags: List[str] = None) -> None:
        """Send histogram value"""
        try:
            statsd.histogram(metric, value, tags=tags or [])
        except Exception as e:
            logger.error("histogram_send_failed", metric=metric, error=str(e))
    
    def timing(self, metric: str, value: float, tags: List[str] = None) -> None:
        """Send timing metric"""
        try:
            statsd.timing(metric, value, tags=tags or [])
        except Exception as e:
            logger.error("timing_send_failed", metric=metric, error=str(e))
    
    def send_metrics_batch(self, metrics: List[Dict[str, Any]]) -> bool:
        """Send batch of metrics via HTTP API"""
        try:
            current_time = int(time.time())
            series = []
            
            for metric in metrics:
                series.append({
                    'metric': metric['name'],
                    'points': [[current_time, metric['value']]],
                    'type': metric.get('type', 'gauge'),
                    'tags': metric.get('tags', [])
                })
            
            if series:
                api.Metric.send(series)
                logger.info("metrics_batch_sent", count=len(series))
                return True
                
        except Exception as e:
            logger.error("batch_send_failed", error=str(e))
            return False
    
    def should_flush(self) -> bool:
        """Check if buffer should be flushed"""
        return (time.time() - self.last_flush) >= self.flush_interval
EOF

# Create metrics collector
echo "📈 Creating metrics collector..."
cat > src/collectors/system_metrics.py << 'EOF'
"""
System metrics collector.
Collects CPU, memory, disk, and network metrics.
"""
import psutil
import time
from typing import Dict
import structlog

logger = structlog.get_logger()

class SystemMetricsCollector:
    """Collects system-level metrics"""
    
    def __init__(self, registry):
        self.registry = registry
        self._setup_metrics()
        logger.info("system_metrics_collector_initialized")
    
    def _setup_metrics(self):
        """Setup system metrics"""
        # CPU metrics
        self.registry.register_gauge(
            "system_cpu_percent",
            "CPU usage percentage"
        )
        self.registry.register_gauge(
            "system_cpu_count",
            "Number of CPU cores"
        )
        
        # Memory metrics
        self.registry.register_gauge(
            "system_memory_used_bytes",
            "Used memory in bytes"
        )
        self.registry.register_gauge(
            "system_memory_total_bytes",
            "Total memory in bytes"
        )
        self.registry.register_gauge(
            "system_memory_percent",
            "Memory usage percentage"
        )
        
        # Disk metrics
        self.registry.register_gauge(
            "system_disk_used_bytes",
            "Disk space used in bytes"
        )
        self.registry.register_gauge(
            "system_disk_total_bytes",
            "Total disk space in bytes"
        )
    
    def collect(self) -> Dict[str, float]:
        """Collect all system metrics"""
        metrics = {}
        
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_count = psutil.cpu_count()
            
            self.registry.set_gauge("system_cpu_percent", cpu_percent)
            self.registry.set_gauge("system_cpu_count", cpu_count)
            
            metrics['cpu_percent'] = cpu_percent
            metrics['cpu_count'] = cpu_count
            
            # Memory metrics
            memory = psutil.virtual_memory()
            self.registry.set_gauge("system_memory_used_bytes", memory.used)
            self.registry.set_gauge("system_memory_total_bytes", memory.total)
            self.registry.set_gauge("system_memory_percent", memory.percent)
            
            metrics['memory_used_bytes'] = memory.used
            metrics['memory_total_bytes'] = memory.total
            metrics['memory_percent'] = memory.percent
            
            # Disk metrics
            disk = psutil.disk_usage('/')
            self.registry.set_gauge("system_disk_used_bytes", disk.used)
            self.registry.set_gauge("system_disk_total_bytes", disk.total)
            
            metrics['disk_used_bytes'] = disk.used
            metrics['disk_total_bytes'] = disk.total
            
            logger.debug("system_metrics_collected", metrics=metrics)
            
        except Exception as e:
            logger.error("system_metrics_collection_failed", error=str(e))
        
        return metrics
EOF

# Create application metrics collector
echo "🔧 Creating application metrics collector..."
cat > src/collectors/app_metrics.py << 'EOF'
"""
Application-specific metrics collector.
Tracks log processing, queue depths, and business metrics.
"""
import time
import random
from typing import Dict
import structlog

logger = structlog.get_logger()

class AppMetricsCollector:
    """Collects application-specific metrics"""
    
    def __init__(self, registry):
        self.registry = registry
        self._setup_metrics()
        self._counters = {
            'messages_processed': 0,
            'messages_failed': 0,
            'bytes_processed': 0
        }
        logger.info("app_metrics_collector_initialized")
    
    def _setup_metrics(self):
        """Setup application metrics"""
        # Processing metrics
        self.registry.register_counter(
            "messages_processed_total",
            "Total messages processed",
            labels=["status", "source"]
        )
        self.registry.register_counter(
            "messages_failed_total",
            "Total messages failed"
        )
        self.registry.register_counter(
            "bytes_processed_total",
            "Total bytes processed"
        )
        
        # Queue metrics
        self.registry.register_gauge(
            "queue_depth",
            "Current queue depth",
            labels=["queue_name"]
        )
        self.registry.register_gauge(
            "consumer_lag",
            "Consumer lag in messages",
            labels=["consumer_group"]
        )
        
        # Latency metrics
        self.registry.register_histogram(
            "message_processing_duration_seconds",
            "Message processing duration",
            labels=["operation"]
        )
        
        # Export metrics
        self.registry.register_counter(
            "metrics_exported_total",
            "Total metrics exported",
            labels=["backend"]
        )
        self.registry.register_counter(
            "metric_export_errors_total",
            "Total metric export errors",
            labels=["backend"]
        )
    
    def record_message_processed(self, status: str = "success", 
                                 source: str = "default",
                                 bytes_count: int = 100):
        """Record a processed message"""
        self.registry.inc_counter(
            "messages_processed_total",
            labels={"status": status, "source": source}
        )
        
        if status == "success":
            self._counters['messages_processed'] += 1
            self._counters['bytes_processed'] += bytes_count
            self.registry.inc_counter("bytes_processed_total", bytes_count)
        else:
            self._counters['messages_failed'] += 1
            self.registry.inc_counter("messages_failed_total")
    
    def record_processing_duration(self, operation: str, duration: float):
        """Record processing duration"""
        self.registry.observe_histogram(
            "message_processing_duration_seconds",
            duration,
            labels={"operation": operation}
        )
    
    def set_queue_depth(self, queue_name: str, depth: int):
        """Set queue depth"""
        self.registry.set_gauge(
            "queue_depth",
            depth,
            labels={"queue_name": queue_name}
        )
    
    def set_consumer_lag(self, consumer_group: str, lag: int):
        """Set consumer lag"""
        self.registry.set_gauge(
            "consumer_lag",
            lag,
            labels={"consumer_group": consumer_group}
        )
    
    def record_export(self, backend: str, success: bool):
        """Record metric export"""
        if success:
            self.registry.inc_counter(
                "metrics_exported_total",
                labels={"backend": backend}
            )
        else:
            self.registry.inc_counter(
                "metric_export_errors_total",
                labels={"backend": backend}
            )
    
    def get_counters(self) -> Dict[str, int]:
        """Get current counter values"""
        return self._counters.copy()
    
    def simulate_activity(self):
        """Simulate log processing activity"""
        # Simulate message processing
        for _ in range(random.randint(5, 15)):
            status = "success" if random.random() > 0.1 else "failed"
            source = random.choice(["web", "api", "database", "queue"])
            bytes_count = random.randint(100, 5000)
            
            self.record_message_processed(status, source, bytes_count)
            
            # Record processing duration
            duration = random.uniform(0.01, 0.5)
            self.record_processing_duration("process", duration)
        
        # Update queue depths
        for queue_name in ["high_priority", "normal", "low_priority"]:
            depth = random.randint(0, 1000)
            self.set_queue_depth(queue_name, depth)
        
        # Update consumer lag
        for group in ["consumer_group_1", "consumer_group_2"]:
            lag = random.randint(0, 500)
            self.set_consumer_lag(group, lag)
EOF

# Create metrics export manager
echo "🎛️ Creating export manager..."
cat > src/exporters/export_manager.py << 'EOF'
"""
Manages metrics export to multiple backends.
Orchestrates Prometheus and Datadog exporters.
"""
import asyncio
from typing import List, Dict, Any
import structlog

logger = structlog.get_logger()

class MetricsExportManager:
    """Manages export to multiple monitoring backends"""
    
    def __init__(self, registry, prometheus_exporter=None, datadog_exporter=None):
        self.registry = registry
        self.prometheus_exporter = prometheus_exporter
        self.datadog_exporter = datadog_exporter
        self.export_interval = 30  # seconds
        self._running = False
        self._export_task = None
        
        logger.info("export_manager_initialized")
    
    async def start_export_loop(self):
        """Start continuous export loop"""
        self._running = True
        self._export_task = asyncio.create_task(self._export_loop())
        logger.info("export_loop_started", interval=self.export_interval)
    
    async def stop_export_loop(self):
        """Stop export loop"""
        self._running = False
        if self._export_task:
            self._export_task.cancel()
            try:
                await self._export_task
            except asyncio.CancelledError:
                pass
        logger.info("export_loop_stopped")
    
    async def _export_loop(self):
        """Main export loop"""
        while self._running:
            try:
                await self.export_metrics()
                await asyncio.sleep(self.export_interval)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error("export_loop_error", error=str(e))
                await asyncio.sleep(5)
    
    async def export_metrics(self) -> Dict[str, bool]:
        """Export metrics to all configured backends"""
        results = {}
        
        # Export to Datadog if configured
        if self.datadog_exporter:
            try:
                metrics = self.registry.get_all_metrics()
                metrics_list = [
                    {
                        'name': name,
                        'value': value,
                        'type': 'gauge',
                        'tags': ['env:production']
                    }
                    for name, value in metrics.items()
                ]
                
                success = self.datadog_exporter.send_metrics_batch(metrics_list)
                results['datadog'] = success
                
                if success:
                    logger.info("metrics_exported_to_datadog", count=len(metrics_list))
                    
            except Exception as e:
                logger.error("datadog_export_failed", error=str(e))
                results['datadog'] = False
        
        # Prometheus exports via /metrics endpoint (pull model)
        results['prometheus'] = self.prometheus_exporter is not None
        
        return results
    
    def get_export_stats(self) -> Dict[str, Any]:
        """Get export statistics"""
        return {
            'backends_configured': {
                'prometheus': self.prometheus_exporter is not None,
                'datadog': self.datadog_exporter is not None
            },
            'export_interval': self.export_interval,
            'running': self._running
        }
EOF

# Create FastAPI application
echo "🌐 Creating FastAPI application..."
cat > src/api/app.py << 'EOF'
"""
FastAPI application for metrics export system.
Exposes metrics endpoints and management API.
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, Response
from contextlib import asynccontextmanager
import asyncio
from typing import Dict, Any

from src.metrics.registry import global_registry
from src.exporters.prometheus_exporter import PrometheusExporter
from src.exporters.datadog_exporter import DatadogExporter
from src.exporters.export_manager import MetricsExportManager
from src.collectors.system_metrics import SystemMetricsCollector
from src.collectors.app_metrics import AppMetricsCollector
import structlog
import os

logger = structlog.get_logger()

# Background tasks
background_tasks = []

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan"""
    # Startup
    logger.info("application_starting")
    
    # Start metric collection
    collection_task = asyncio.create_task(collect_metrics_loop())
    background_tasks.append(collection_task)
    
    # Start export loop
    await app.state.export_manager.start_export_loop()
    
    yield
    
    # Shutdown
    logger.info("application_stopping")
    await app.state.export_manager.stop_export_loop()
    
    for task in background_tasks:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass

app = FastAPI(
    title="Metrics Export System",
    description="Day 141: Metrics export to Prometheus and Datadog",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize exporters
prometheus_exporter = PrometheusExporter(global_registry)

datadog_api_key = os.getenv("DATADOG_API_KEY", "test_key")
datadog_app_key = os.getenv("DATADOG_APP_KEY", "test_key")
datadog_exporter = None

if datadog_api_key != "test_key":
    datadog_exporter = DatadogExporter(datadog_api_key, datadog_app_key)

# Initialize collectors
system_collector = SystemMetricsCollector(global_registry)
app_collector = AppMetricsCollector(global_registry)

# Initialize export manager
export_manager = MetricsExportManager(
    global_registry,
    prometheus_exporter,
    datadog_exporter
)

app.state.export_manager = export_manager
app.state.system_collector = system_collector
app.state.app_collector = app_collector

async def collect_metrics_loop():
    """Background loop to collect metrics"""
    while True:
        try:
            # Collect system metrics
            system_collector.collect()
            
            # Simulate application activity
            app_collector.simulate_activity()
            
            await asyncio.sleep(10)
            
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error("metrics_collection_error", error=str(e))
            await asyncio.sleep(5)

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Metrics Export System",
        "version": "1.0.0",
        "endpoints": {
            "metrics": "/metrics",
            "health": "/health",
            "stats": "/api/stats"
        }
    }

@app.get("/metrics")
async def metrics_endpoint():
    """Prometheus metrics endpoint"""
    return prometheus_exporter.get_metrics()

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": asyncio.get_event_loop().time()
    }

@app.get("/api/stats")
async def get_stats() -> Dict[str, Any]:
    """Get current statistics"""
    return {
        "collectors": {
            "system": system_collector.collect(),
            "application": app_collector.get_counters()
        },
        "export": export_manager.get_export_stats(),
        "cardinality": global_registry.check_cardinality()
    }

@app.post("/api/trigger-export")
async def trigger_export():
    """Manually trigger metrics export"""
    try:
        results = await export_manager.export_metrics()
        return {"success": True, "results": results}
    except Exception as e:
        logger.error("manual_export_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard():
    """Metrics dashboard"""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Metrics Export Dashboard</title>
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
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
                padding: 30px;
                border-radius: 15px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.2);
                margin-bottom: 30px;
            }
            .header h1 {
                color: #667eea;
                margin-bottom: 10px;
            }
            .metrics-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                margin-bottom: 30px;
            }
            .metric-card {
                background: white;
                padding: 25px;
                border-radius: 15px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            }
            .metric-value {
                font-size: 36px;
                font-weight: bold;
                color: #667eea;
                margin: 10px 0;
            }
            .metric-label {
                color: #666;
                font-size: 14px;
                text-transform: uppercase;
                letter-spacing: 1px;
            }
            .chart-container {
                background: white;
                padding: 25px;
                border-radius: 15px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1);
                margin-bottom: 20px;
            }
            .status-indicator {
                display: inline-block;
                width: 12px;
                height: 12px;
                border-radius: 50%;
                margin-right: 8px;
            }
            .status-online { background: #10b981; }
            .status-offline { background: #ef4444; }
            .export-status {
                display: flex;
                gap: 20px;
                margin-top: 15px;
            }
            .export-badge {
                background: #f3f4f6;
                padding: 10px 20px;
                border-radius: 8px;
                display: flex;
                align-items: center;
            }
            button {
                background: #667eea;
                color: white;
                border: none;
                padding: 12px 24px;
                border-radius: 8px;
                cursor: pointer;
                font-size: 14px;
                font-weight: 600;
                transition: all 0.3s;
            }
            button:hover {
                background: #5568d3;
                transform: translateY(-2px);
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>📊 Metrics Export Dashboard</h1>
                <p>Real-time monitoring of metrics export to Prometheus and Datadog</p>
                <div class="export-status">
                    <div class="export-badge">
                        <span class="status-indicator status-online"></span>
                        <span>Prometheus: Active</span>
                    </div>
                    <div class="export-badge">
                        <span class="status-indicator" id="datadog-status"></span>
                        <span id="datadog-text">Datadog: Checking...</span>
                    </div>
                    <button onclick="triggerExport()">Export Now</button>
                </div>
            </div>
            
            <div class="metrics-grid">
                <div class="metric-card">
                    <div class="metric-label">Messages Processed</div>
                    <div class="metric-value" id="messages-processed">0</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">Messages Failed</div>
                    <div class="metric-value" id="messages-failed">0</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">CPU Usage</div>
                    <div class="metric-value" id="cpu-usage">0%</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">Memory Usage</div>
                    <div class="metric-value" id="memory-usage">0%</div>
                </div>
            </div>
            
            <div class="chart-container">
                <h3>Message Processing Rate</h3>
                <canvas id="messageChart"></canvas>
            </div>
            
            <div class="chart-container">
                <h3>Queue Depths</h3>
                <canvas id="queueChart"></canvas>
            </div>
        </div>
        
        <script>
            let messageChart, queueChart;
            let messageData = [];
            let queueData = {
                high_priority: [],
                normal: [],
                low_priority: []
            };
            
            function initCharts() {
                const messageCtx = document.getElementById('messageChart').getContext('2d');
                messageChart = new Chart(messageCtx, {
                    type: 'line',
                    data: {
                        labels: [],
                        datasets: [{
                            label: 'Messages Processed',
                            data: [],
                            borderColor: '#667eea',
                            backgroundColor: 'rgba(102, 126, 234, 0.1)',
                            tension: 0.4
                        }]
                    },
                    options: {
                        responsive: true,
                        scales: {
                            y: { beginAtZero: true }
                        }
                    }
                });
                
                const queueCtx = document.getElementById('queueChart').getContext('2d');
                queueChart = new Chart(queueCtx, {
                    type: 'bar',
                    data: {
                        labels: ['High Priority', 'Normal', 'Low Priority'],
                        datasets: [{
                            label: 'Queue Depth',
                            data: [0, 0, 0],
                            backgroundColor: [
                                '#ef4444',
                                '#f59e0b',
                                '#10b981'
                            ]
                        }]
                    },
                    options: {
                        responsive: true,
                        scales: {
                            y: { beginAtZero: true }
                        }
                    }
                });
            }
            
            async function updateMetrics() {
                try {
                    const response = await fetch('/api/stats');
                    const data = await response.json();
                    
                    // Update metric cards
                    document.getElementById('messages-processed').textContent = 
                        data.collectors.application.messages_processed;
                    document.getElementById('messages-failed').textContent = 
                        data.collectors.application.messages_failed;
                    document.getElementById('cpu-usage').textContent = 
                        data.collectors.system.cpu_percent.toFixed(1) + '%';
                    document.getElementById('memory-usage').textContent = 
                        data.collectors.system.memory_percent.toFixed(1) + '%';
                    
                    // Update Datadog status
                    const datadogEnabled = data.export.backends_configured.datadog;
                    document.getElementById('datadog-status').className = 
                        'status-indicator ' + (datadogEnabled ? 'status-online' : 'status-offline');
                    document.getElementById('datadog-text').textContent = 
                        'Datadog: ' + (datadogEnabled ? 'Active' : 'Disabled');
                    
                    // Update message chart
                    const time = new Date().toLocaleTimeString();
                    messageChart.data.labels.push(time);
                    messageChart.data.datasets[0].data.push(data.collectors.application.messages_processed);
                    
                    if (messageChart.data.labels.length > 20) {
                        messageChart.data.labels.shift();
                        messageChart.data.datasets[0].data.shift();
                    }
                    
                    messageChart.update('none');
                    
                } catch (error) {
                    console.error('Failed to update metrics:', error);
                }
            }
            
            async function triggerExport() {
                try {
                    const response = await fetch('/api/trigger-export', { method: 'POST' });
                    const data = await response.json();
                    alert('Export triggered successfully!');
                } catch (error) {
                    alert('Export failed: ' + error.message);
                }
            }
            
            // Initialize
            initCharts();
            updateMetrics();
            setInterval(updateMetrics, 5000);
        </script>
    </body>
    </html>
    """
EOF

# Create main entry point
echo "🚪 Creating main entry point..."
cat > src/main.py << 'EOF'
"""
Main entry point for metrics export system.
"""
import uvicorn
import structlog

# Configure structured logging
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ]
)

if __name__ == "__main__":
    uvicorn.run(
        "src.api.app:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )
EOF

# Create tests
echo "🧪 Creating tests..."
cat > tests/unit/test_registry.py << 'EOF'
"""Unit tests for metrics registry"""
import pytest
from src.metrics.registry import UnifiedMetricsRegistry

def test_register_counter():
    registry = UnifiedMetricsRegistry("test")
    registry.register_counter("test_counter", "Test counter")
    assert "test_test_counter" in registry._metrics

def test_increment_counter():
    registry = UnifiedMetricsRegistry("test")
    registry.register_counter("requests", "Request count")
    registry.inc_counter("requests", 5)
    assert registry.get_all_metrics()["test_requests"] == 5

def test_set_gauge():
    registry = UnifiedMetricsRegistry("test")
    registry.register_gauge("temperature", "Temperature")
    registry.set_gauge("temperature", 25.5)
    assert registry.get_all_metrics()["test_temperature"] == 25.5

def test_metrics_with_labels():
    registry = UnifiedMetricsRegistry("test")
    registry.register_counter("http_requests", "HTTP requests", labels=["method", "status"])
    registry.inc_counter("http_requests", labels={"method": "GET", "status": "200"})
    metrics = registry.get_all_metrics()
    assert any("http_requests" in key for key in metrics.keys())
EOF

cat > tests/integration/test_export.py << 'EOF'
"""Integration tests for metrics export"""
import pytest
from src.metrics.registry import UnifiedMetricsRegistry
from src.exporters.prometheus_exporter import PrometheusExporter
from src.collectors.system_metrics import SystemMetricsCollector

@pytest.mark.asyncio
async def test_system_metrics_collection():
    registry = UnifiedMetricsRegistry("test")
    collector = SystemMetricsCollector(registry)
    metrics = collector.collect()
    
    assert 'cpu_percent' in metrics
    assert 'memory_percent' in metrics
    assert metrics['cpu_percent'] >= 0

def test_prometheus_export():
    registry = UnifiedMetricsRegistry("test")
    registry.register_counter("test_metric", "Test")
    registry.inc_counter("test_metric", 42)
    
    exporter = PrometheusExporter(registry)
    response = exporter.get_metrics()
    
    assert response.status_code == 200
    assert b"test_test_metric" in response.body
EOF

# Create Docker configuration
echo "🐳 Creating Docker configuration..."
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ ./src/
COPY config/ ./config/

# Expose ports
EXPOSE 8000 9090

# Run application
CMD ["python", "-m", "src.main"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATADOG_API_KEY=${DATADOG_API_KEY:-test_key}
      - DATADOG_APP_KEY=${DATADOG_APP_KEY:-test_key}
      - ENVIRONMENT=production
    volumes:
      - ./config:/app/config
    depends_on:
      - redis
  
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
  
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'

volumes:
  prometheus_data:
EOF

cat > .dockerignore << 'EOF'
venv/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
*.so
*.egg
*.egg-info/
dist/
build/
.git/
.pytest_cache/
.coverage
htmlcov/
EOF

# Create Prometheus configuration
cat > config/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'metrics-export'
    static_configs:
      - targets: ['app:8000']
EOF

# Create build script
echo "🔨 Creating build.sh..."
cat > build.sh << 'EOF'
#!/bin/bash
set -e

echo "🔨 Building Metrics Export System"
echo "=================================="

# Activate virtual environment if exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v --tb=short

echo "✅ Build completed successfully!"
EOF

chmod +x build.sh

# Create start script
echo "🚀 Creating start.sh..."
cat > start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Metrics Export System"
echo "=================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Run setup first."
    exit 1
fi

source venv/bin/activate

# Start the application
echo "Starting FastAPI server..."
python -m src.main &
APP_PID=$!

echo "✅ Application started (PID: $APP_PID)"
echo "📊 Dashboard: http://localhost:8000/dashboard"
echo "📈 Metrics: http://localhost:8000/metrics"
echo "🏥 Health: http://localhost:8000/health"
echo ""
echo "Press Ctrl+C to stop"

# Wait for interrupt
trap "kill $APP_PID; exit" INT TERM
wait $APP_PID
EOF

chmod +x start.sh

# Create stop script
echo "🛑 Creating stop.sh..."
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Metrics Export System"
pkill -f "python -m src.main" || true
echo "✅ System stopped"
EOF

chmod +x stop.sh

# Create demo script
echo "🎬 Creating demo.sh..."
cat > scripts/demo.sh << 'EOF'
#!/bin/bash
set -e

echo "🎬 Day 141 Metrics Export - System Demonstration"
echo "================================================"

source venv/bin/activate

# Start application in background
python -m src.main &
APP_PID=$!

echo "⏳ Waiting for application to start..."
sleep 5

echo ""
echo "1️⃣ Testing Health Endpoint"
echo "============================="
curl -s http://localhost:8000/health | python -m json.tool

echo ""
echo "2️⃣ Fetching Current Statistics"
echo "================================"
curl -s http://localhost:8000/api/stats | python -m json.tool

echo ""
echo "3️⃣ Viewing Prometheus Metrics"
echo "==============================="
curl -s http://localhost:8000/metrics | head -n 30

echo ""
echo "4️⃣ Triggering Manual Export"
echo "============================"
curl -s -X POST http://localhost:8000/api/trigger-export | python -m json.tool

echo ""
echo "✅ Demonstration Complete!"
echo ""
echo "📊 View Dashboard: http://localhost:8000/dashboard"
echo "📈 View Metrics: http://localhost:8000/metrics"
echo ""

# Keep running for dashboard access
echo "Application running... Press Ctrl+C to stop"
trap "kill $APP_PID; exit" INT TERM
wait $APP_PID
EOF

chmod +x scripts/demo.sh

# Run build
echo ""
echo "🔨 Building and testing..."
./build.sh

# Run demonstration
echo ""
echo "🎬 Running system demonstration..."
chmod +x scripts/demo.sh
./scripts/demo.sh &
DEMO_PID=$!

# Wait a bit then display final message
sleep 10

echo ""
echo "✅ Day 141 Implementation Complete!"
echo "===================================="
echo ""
echo "📁 Project Structure Created:"
echo "   - Unified metrics registry"
echo "   - Prometheus exporter"
echo "   - Datadog integration"
echo "   - System & application collectors"
echo "   - FastAPI dashboard"
echo ""
echo "🌐 Access Points:"
echo "   Dashboard:  http://localhost:8000/dashboard"
echo "   Metrics:    http://localhost:8000/metrics"
echo "   Health:     http://localhost:8000/health"
echo "   Stats API:  http://localhost:8000/api/stats"
echo ""
echo "📊 Features Implemented:"
echo "   ✅ Multi-backend metrics export"
echo "   ✅ Prometheus OpenMetrics format"
echo "   ✅ Datadog push integration"
echo "   ✅ Real-time dashboard"
echo "   ✅ System metrics collection"
echo "   ✅ Application metrics tracking"
echo "   ✅ Cardinality management"
echo ""
echo "🐳 Docker Commands:"
echo "   docker-compose up --build"
echo ""
echo "Press Ctrl+C to stop the demo"
wait $DEMO_PID