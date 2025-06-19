#!/bin/bash

# Day 39: Kafka Producer Implementation Script
# Creates complete project structure and implementation

set -e  # Exit on any error

echo "🚀 Day 39: Creating Kafka Producers for Log Ingestion"
echo "=================================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p kafka-log-producer/{src,tests,config,web,docker,scripts}
cd kafka-log-producer

# Create subdirectories
mkdir -p src/{producer,models,monitoring,utils}
mkdir -p tests/{unit,integration,performance}
mkdir -p web/{static,templates}

echo "✅ Project structure created"

# Create requirements.txt with latest libraries
cat > requirements.txt << 'EOF'
kafka-python==2.0.2
confluent-kafka==2.3.0
fastapi==0.111.0
uvicorn==0.30.1
pydantic==2.7.1
prometheus-client==0.20.0
structlog==24.1.0
pytest==8.2.0
pytest-asyncio==0.23.7
aiofiles==23.2.1
jinja2==3.1.2
websockets==12.0
psutil==5.9.8
numpy==1.26.4
pandas==2.2.2
matplotlib==3.8.4
seaborn==0.13.2
docker==7.1.0
EOF

echo "📦 Installing dependencies..."
python -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "✅ Dependencies installed"

# Create configuration files
cat > config/producer_config.yaml << 'EOF'
kafka:
  bootstrap_servers: "localhost:9092"
  client_id: "log-producer-client"
  security_protocol: "PLAINTEXT"
  
producer:
  acks: "all"  # Wait for all in-sync replicas
  retries: 2147483647  # Retry until success
  batch_size: 16384  # 16KB batches
  linger_ms: 5  # Wait up to 5ms for batching
  compression_type: "gzip"
  enable_idempotence: true
  max_in_flight_requests_per_connection: 5
  buffer_memory: 33554432  # 32MB buffer
  request_timeout_ms: 30000
  delivery_timeout_ms: 120000

topics:
  application_logs: "logs-application"
  database_logs: "logs-database" 
  security_logs: "logs-security"
  error_logs: "logs-errors"

monitoring:
  metrics_port: 8000
  health_check_interval: 30
  performance_logging: true

logging:
  level: "INFO"
  format: "json"
  file: "logs/producer.log"
EOF

# Create log models
cat > src/models/log_entry.py << 'EOF'
from datetime import datetime
from typing import Dict, Any, Optional
from pydantic import BaseModel, Field
import json
import uuid

class LogLevel:
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARN = "WARN"
    ERROR = "ERROR"
    FATAL = "FATAL"

class LogEntry(BaseModel):
    """Structured log entry model"""
    
    timestamp: datetime = Field(default_factory=datetime.now)
    level: str = Field(..., description="Log level")
    message: str = Field(..., description="Log message")
    service: str = Field(..., description="Service name")
    component: str = Field(default="unknown", description="Component name")
    trace_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
    
    def to_kafka_message(self) -> bytes:
        """Convert to Kafka message format"""
        data = self.dict()
        return json.dumps(data, default=str).encode('utf-8')
    
    def get_partition_key(self) -> Optional[str]:
        """Get key for consistent partitioning"""
        if self.user_id:
            return self.user_id
        elif self.session_id:
            return self.session_id
        return self.service
    
    def get_topic(self) -> str:
        """Determine appropriate Kafka topic"""
        if self.level in [LogLevel.ERROR, LogLevel.FATAL]:
            return "logs-errors"
        elif self.service == "database":
            return "logs-database"
        elif self.service == "security":
            return "logs-security"
        else:
            return "logs-application"
EOF

# Create producer metrics
cat > src/monitoring/producer_metrics.py << 'EOF'
from prometheus_client import Counter, Histogram, Gauge, start_http_server
from typing import Dict, Any
import time
import threading
import structlog

logger = structlog.get_logger()

class ProducerMetrics:
    """Comprehensive producer metrics collection"""
    
    def __init__(self, port: int = 8000):
        self.port = port
        
        # Counters
        self.messages_sent = Counter(
            'kafka_producer_messages_sent_total',
            'Total messages sent to Kafka',
            ['topic', 'partition']
        )
        
        self.messages_failed = Counter(
            'kafka_producer_messages_failed_total', 
            'Total failed messages',
            ['topic', 'error_type']
        )
        
        self.bytes_sent = Counter(
            'kafka_producer_bytes_sent_total',
            'Total bytes sent to Kafka',
            ['topic']
        )
        
        # Histograms
        self.send_latency = Histogram(
            'kafka_producer_send_latency_seconds',
            'Message send latency',
            ['topic'],
            buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
        )
        
        self.batch_size = Histogram(
            'kafka_producer_batch_size_messages',
            'Batch size in messages',
            ['topic'],
            buckets=[1, 5, 10, 25, 50, 100, 250, 500, 1000]
        )
        
        # Gauges
        self.buffer_available = Gauge(
            'kafka_producer_buffer_available_bytes',
            'Available buffer memory'
        )
        
        self.pending_messages = Gauge(
            'kafka_producer_pending_messages',
            'Messages waiting to be sent'
        )
        
        self.connections_active = Gauge(
            'kafka_producer_connections_active',
            'Active connections to Kafka'
        )
        
        # Start metrics server
        self._start_server()
        
    def _start_server(self):
        """Start Prometheus metrics server"""
        try:
            start_http_server(self.port)
            logger.info(f"Metrics server started on port {self.port}")
        except Exception as e:
            logger.error(f"Failed to start metrics server: {e}")
    
    def record_message_sent(self, topic: str, partition: int, size_bytes: int):
        """Record successful message send"""
        self.messages_sent.labels(topic=topic, partition=partition).inc()
        self.bytes_sent.labels(topic=topic).inc(size_bytes)
        
    def record_message_failed(self, topic: str, error_type: str):
        """Record failed message"""
        self.messages_failed.labels(topic=topic, error_type=error_type).inc()
        
    def record_send_latency(self, topic: str, latency_seconds: float):
        """Record send latency"""
        self.send_latency.labels(topic=topic).observe(latency_seconds)
        
    def record_batch_size(self, topic: str, size: int):
        """Record batch size"""
        self.batch_size.labels(topic=topic).observe(size)
        
    def update_buffer_available(self, bytes_available: int):
        """Update available buffer memory"""
        self.buffer_available.set(bytes_available)
        
    def update_pending_messages(self, count: int):
        """Update pending message count"""
        self.pending_messages.set(count)
        
    def update_active_connections(self, count: int):
        """Update active connection count"""
        self.connections_active.set(count)
EOF

# Create main producer implementation
cat > src/producer/kafka_producer.py << 'EOF'
import json
import time
import threading
from typing import Optional, Dict, Any, Callable
from confluent_kafka import Producer, KafkaError
from confluent_kafka.admin import AdminClient, NewTopic
import structlog
import yaml
from pathlib import Path

from ..models.log_entry import LogEntry
from ..monitoring.producer_metrics import ProducerMetrics

logger = structlog.get_logger()

class KafkaLogProducer:
    """High-performance Kafka producer for log ingestion"""
    
    def __init__(self, config_path: str = "config/producer_config.yaml"):
        self.config = self._load_config(config_path)
        self.producer = None
        self.metrics = ProducerMetrics(self.config['monitoring']['metrics_port'])
        self.running = False
        self._callbacks = {}
        
        # Initialize producer
        self._initialize_producer()
        self._create_topics()
        
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            raise
            
    def _initialize_producer(self):
        """Initialize Kafka producer with configuration"""
        producer_config = {
            'bootstrap.servers': self.config['kafka']['bootstrap_servers'],
            'client.id': self.config['kafka']['client_id'],
            'security.protocol': self.config['kafka']['security_protocol'],
            'acks': self.config['producer']['acks'],
            'retries': self.config['producer']['retries'],
            'batch.size': self.config['producer']['batch_size'],
            'linger.ms': self.config['producer']['linger_ms'],
            'compression.type': self.config['producer']['compression_type'],
            'enable.idempotence': self.config['producer']['enable_idempotence'],
            'max.in.flight.requests.per.connection': 
                self.config['producer']['max_in_flight_requests_per_connection'],
            'buffer.memory': self.config['producer']['buffer_memory'],
            'request.timeout.ms': self.config['producer']['request_timeout_ms'],
            'delivery.timeout.ms': self.config['producer']['delivery_timeout_ms'],
        }
        
        try:
            self.producer = Producer(producer_config)
            logger.info("Kafka producer initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize producer: {e}")
            raise
            
    def _create_topics(self):
        """Ensure required topics exist"""
        admin_client = AdminClient({
            'bootstrap.servers': self.config['kafka']['bootstrap_servers']
        })
        
        topics = [
            NewTopic(topic, num_partitions=3, replication_factor=1)
            for topic in self.config['topics'].values()
        ]
        
        try:
            fs = admin_client.create_topics(topics)
            for topic, f in fs.items():
                try:
                    f.result()  # The result itself is None
                    logger.info(f"Topic {topic} created")
                except Exception as e:
                    if "already exists" not in str(e):
                        logger.error(f"Failed to create topic {topic}: {e}")
        except Exception as e:
            logger.error(f"Failed to create topics: {e}")
            
    def _delivery_callback(self, err, msg):
        """Callback for message delivery confirmation"""
        if err is not None:
            error_type = err.name() if hasattr(err, 'name') else str(type(err).__name__)
            self.metrics.record_message_failed(msg.topic(), error_type)
            logger.error(f"Message delivery failed: {err}")
        else:
            self.metrics.record_message_sent(
                msg.topic(), 
                msg.partition(), 
                len(msg.value())
            )
            logger.debug(f"Message delivered to {msg.topic()}[{msg.partition()}]")
            
    def send_log(self, log_entry: LogEntry, callback: Optional[Callable] = None) -> bool:
        """Send a single log entry to Kafka"""
        try:
            start_time = time.time()
            
            topic = log_entry.get_topic()
            key = log_entry.get_partition_key()
            message = log_entry.to_kafka_message()
            
            # Send to Kafka
            self.producer.produce(
                topic=topic,
                key=key.encode('utf-8') if key else None,
                value=message,
                callback=self._delivery_callback
            )
            
            # Record metrics
            latency = time.time() - start_time
            self.metrics.record_send_latency(topic, latency)
            
            logger.debug(f"Log sent to topic {topic}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to send log: {e}")
            self.metrics.record_message_failed("unknown", str(type(e).__name__))
            return False
            
    def send_logs_batch(self, log_entries: list[LogEntry]) -> Dict[str, int]:
        """Send multiple log entries efficiently"""
        results = {"sent": 0, "failed": 0}
        
        try:
            for log_entry in log_entries:
                if self.send_log(log_entry):
                    results["sent"] += 1
                else:
                    results["failed"] += 1
                    
            # Trigger send of batched messages
            self.producer.poll(0)
            
            return results
            
        except Exception as e:
            logger.error(f"Batch send failed: {e}")
            results["failed"] = len(log_entries)
            return results
            
    def flush(self, timeout: float = 10.0):
        """Flush pending messages"""
        try:
            remaining = self.producer.flush(timeout)
            if remaining > 0:
                logger.warning(f"{remaining} messages still pending after flush")
            else:
                logger.info("All messages flushed successfully")
        except Exception as e:
            logger.error(f"Flush failed: {e}")
            
    def close(self):
        """Close producer and clean up resources"""
        if self.producer:
            logger.info("Closing Kafka producer")
            self.flush()
            self.producer = None
            
    def get_stats(self) -> Dict[str, Any]:
        """Get producer statistics"""
        if not self.producer:
            return {}
            
        stats_json = self.producer.list_topics(timeout=5)
        return {
            "topics": len(stats_json.topics),
            "brokers": len(stats_json.brokers),
            "producer_active": self.producer is not None
        }
EOF

# Create log generator for testing
cat > src/utils/log_generator.py << 'EOF'
import random
import time
from datetime import datetime, timedelta
from typing import List
from ..models.log_entry import LogEntry, LogLevel

class LogGenerator:
    """Generate realistic log data for testing"""
    
    SERVICES = ["web-api", "user-service", "payment-service", "database", "security"]
    COMPONENTS = ["controller", "service", "repository", "middleware", "auth"]
    
    LOG_MESSAGES = {
        LogLevel.INFO: [
            "User logged in successfully",
            "Request processed successfully", 
            "Database connection established",
            "Cache hit for user data",
            "Service started successfully"
        ],
        LogLevel.WARN: [
            "High memory usage detected",
            "Slow database query detected",
            "Rate limit approaching",
            "Cache miss for frequent request",
            "Deprecated API endpoint accessed"
        ],
        LogLevel.ERROR: [
            "Database connection failed",
            "Authentication failed",
            "Payment processing error",
            "External service timeout",
            "Invalid request format"
        ]
    }
    
    def __init__(self):
        self.user_ids = [f"user_{i}" for i in range(1, 1001)]
        self.session_ids = [f"session_{i}" for i in range(1, 501)]
        
    def generate_log(self, 
                    level: str = None, 
                    service: str = None,
                    timestamp: datetime = None) -> LogEntry:
        """Generate a single log entry"""
        
        level = level or random.choice([
            LogLevel.INFO, LogLevel.INFO, LogLevel.INFO,  # Higher probability
            LogLevel.WARN, LogLevel.ERROR
        ])
        
        service = service or random.choice(self.SERVICES)
        component = random.choice(self.COMPONENTS)
        message = random.choice(self.LOG_MESSAGES[level])
        
        # Add realistic metadata
        metadata = {
            "ip_address": f"192.168.1.{random.randint(1, 255)}",
            "user_agent": "Mozilla/5.0 (compatible; LogGenerator/1.0)",
            "endpoint": f"/api/v1/{component}/{random.randint(1, 100)}",
            "response_time_ms": random.randint(10, 2000),
            "request_id": f"req_{random.randint(10000, 99999)}"
        }
        
        # Add error-specific metadata
        if level == LogLevel.ERROR:
            metadata.update({
                "error_code": f"ERR_{random.randint(1000, 9999)}",
                "stack_trace": f"at {component}.{random.choice(['process', 'handle', 'execute'])}(line:{random.randint(1, 500)})"
            })
            
        return LogEntry(
            timestamp=timestamp or datetime.now(),
            level=level,
            message=message,
            service=service,
            component=component,
            user_id=random.choice(self.user_ids) if random.random() > 0.3 else None,
            session_id=random.choice(self.session_ids) if random.random() > 0.5 else None,
            metadata=metadata
        )
        
    def generate_batch(self, count: int, timespan_minutes: int = 60) -> List[LogEntry]:
        """Generate a batch of log entries over a time span"""
        logs = []
        start_time = datetime.now() - timedelta(minutes=timespan_minutes)
        
        for i in range(count):
            # Distribute logs evenly over timespan
            timestamp = start_time + timedelta(
                minutes=(timespan_minutes * i / count)
            )
            logs.append(self.generate_log(timestamp=timestamp))
            
        return logs
        
    def generate_error_burst(self, count: int = 50) -> List[LogEntry]:
        """Generate a burst of error logs (simulating an incident)"""
        return [
            self.generate_log(level=LogLevel.ERROR, service="payment-service")
            for _ in range(count)
        ]
        
    def generate_high_volume_stream(self, duration_seconds: int = 60, rate_per_second: int = 100):
        """Generate high-volume log stream for performance testing"""
        start_time = time.time()
        logs_generated = 0
        
        while time.time() - start_time < duration_seconds:
            batch_start = time.time()
            
            # Generate logs for this second
            for _ in range(rate_per_second):
                yield self.generate_log()
                logs_generated += 1
                
            # Sleep to maintain rate
            elapsed = time.time() - batch_start
            if elapsed < 1.0:
                time.sleep(1.0 - elapsed)
                
        print(f"Generated {logs_generated} logs in {duration_seconds} seconds")
EOF

# Create main application
cat > src/main.py << 'EOF'
import asyncio
import signal
import sys
import time
from pathlib import Path
import structlog

# Add src to path
sys.path.append(str(Path(__file__).parent.parent))

from producer.kafka_producer import KafkaLogProducer
from utils.log_generator import LogGenerator
from monitoring.producer_metrics import ProducerMetrics

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
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

class ProducerApplication:
    """Main producer application"""
    
    def __init__(self):
        self.producer = None
        self.generator = LogGenerator()
        self.running = False
        
    def setup_signal_handlers(self):
        """Setup graceful shutdown signal handlers"""
        def signal_handler(signum, frame):
            logger.info(f"Received signal {signum}, shutting down gracefully")
            self.shutdown()
            
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
    def start(self):
        """Start the producer application"""
        try:
            logger.info("Starting Kafka Log Producer Application")
            
            # Initialize producer
            self.producer = KafkaLogProducer()
            self.running = True
            
            # Setup signal handlers
            self.setup_signal_handlers()
            
            logger.info("Producer application started successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to start application: {e}")
            return False
            
    def run_demo(self):
        """Run a demonstration of the producer"""
        if not self.start():
            return
            
        logger.info("Starting demo - generating sample logs")
        
        try:
            # Generate and send sample logs
            logs = self.generator.generate_batch(100, 30)
            
            logger.info(f"Sending {len(logs)} sample logs")
            
            batch_size = 10
            for i in range(0, len(logs), batch_size):
                batch = logs[i:i + batch_size]
                results = self.producer.send_logs_batch(batch)
                
                logger.info(
                    f"Batch {i//batch_size + 1}: "
                    f"sent={results['sent']}, failed={results['failed']}"
                )
                
                time.sleep(1)  # Throttle for demo
                
            # Generate an error burst to demonstrate error handling
            logger.info("Generating error burst for demonstration")
            error_logs = self.generator.generate_error_burst(20)
            error_results = self.producer.send_logs_batch(error_logs)
            
            logger.info(
                f"Error burst: sent={error_results['sent']}, "
                f"failed={error_results['failed']}"
            )
            
            # Flush all messages
            self.producer.flush()
            
            logger.info("Demo completed successfully")
            
        except Exception as e:
            logger.error(f"Demo failed: {e}")
        finally:
            self.shutdown()
            
    def run_performance_test(self, duration_seconds: int = 60, rate_per_second: int = 1000):
        """Run performance test"""
        if not self.start():
            return
            
        logger.info(f"Starting performance test: {rate_per_second} msgs/sec for {duration_seconds}s")
        
        try:
            start_time = time.time()
            total_sent = 0
            total_failed = 0
            
            for log in self.generator.generate_high_volume_stream(duration_seconds, rate_per_second):
                if self.producer.send_log(log):
                    total_sent += 1
                else:
                    total_failed += 1
                    
                # Poll for callbacks every 100 messages
                if (total_sent + total_failed) % 100 == 0:
                    self.producer.producer.poll(0)
                    
            # Final flush
            self.producer.flush()
            
            elapsed = time.time() - start_time
            actual_rate = total_sent / elapsed
            
            logger.info(
                f"Performance test completed: "
                f"sent={total_sent}, failed={total_failed}, "
                f"actual_rate={actual_rate:.1f} msgs/sec"
            )
            
        except Exception as e:
            logger.error(f"Performance test failed: {e}")
        finally:
            self.shutdown()
            
    def shutdown(self):
        """Gracefully shutdown the application"""
        self.running = False
        if self.producer:
            self.producer.close()
        logger.info("Application shutdown complete")

def main():
    """Main entry point"""
    app = ProducerApplication()
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "demo":
            app.run_demo()
        elif command == "performance":
            duration = int(sys.argv[2]) if len(sys.argv) > 2 else 60
            rate = int(sys.argv[3]) if len(sys.argv) > 3 else 1000
            app.run_performance_test(duration, rate)
        else:
            print("Usage: python main.py [demo|performance [duration] [rate]]")
    else:
        # Default to demo
        app.run_demo()

if __name__ == "__main__":
    main()
EOF

# Create web monitoring dashboard
cat > web/app.py << 'EOF'
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import json
import asyncio
import time
import sys
from pathlib import Path

# Add src to path
sys.path.append(str(Path(__file__).parent.parent / "src"))

from producer.kafka_producer import KafkaLogProducer
from utils.log_generator import LogGenerator

app = FastAPI(title="Kafka Producer Dashboard")
app.mount("/static", StaticFiles(directory="web/static"), name="static")
templates = Jinja2Templates(directory="web/templates")

# Global instances
producer = None
generator = LogGenerator()
connected_clients = []

@app.on_event("startup")
async def startup():
    global producer
    try:
        producer = KafkaLogProducer()
        print("✅ Kafka producer initialized for dashboard")
    except Exception as e:
        print(f"❌ Failed to initialize producer: {e}")

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Main dashboard page"""
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "title": "Kafka Producer Dashboard"
    })

@app.get("/api/stats")
async def get_stats():
    """Get current producer statistics"""
    if not producer:
        return {"error": "Producer not initialized"}
        
    return producer.get_stats()

@app.post("/api/send-sample")
async def send_sample_logs():
    """Send sample logs for testing"""
    if not producer:
        return {"error": "Producer not initialized"}
        
    try:
        # Generate 10 sample logs
        logs = generator.generate_batch(10, 1)
        results = producer.send_logs_batch(logs)
        
        return {
            "success": True,
            "logs_sent": results["sent"],
            "logs_failed": results["failed"]
        }
    except Exception as e:
        return {"error": str(e)}

@app.post("/api/send-errors")
async def send_error_burst():
    """Send error burst for testing"""
    if not producer:
        return {"error": "Producer not initialized"}
        
    try:
        error_logs = generator.generate_error_burst(5)
        results = producer.send_logs_batch(error_logs)
        
        return {
            "success": True,
            "error_logs_sent": results["sent"],
            "error_logs_failed": results["failed"]
        }
    except Exception as e:
        return {"error": str(e)}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket for real-time updates"""
    await websocket.accept()
    connected_clients.append(websocket)
    
    try:
        while True:
            # Send periodic updates
            if producer:
                stats = producer.get_stats()
                await websocket.send_text(json.dumps({
                    "type": "stats_update",
                    "data": stats,
                    "timestamp": time.time()
                }))
            
            await asyncio.sleep(2)  # Update every 2 seconds
            
    except WebSocketDisconnect:
        connected_clients.remove(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
EOF

# Create dashboard template
mkdir -p web/templates
cat > web/templates/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ title }}</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .metric-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #2196F3;
        }
        .metric-label {
            color: #666;
            font-size: 0.9em;
        }
        .controls {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .btn {
            background: #2196F3;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 10px;
        }
        .btn:hover {
            background: #1976D2;
        }
        .btn.danger {
            background: #f44336;
        }
        .btn.danger:hover {
            background: #d32f2f;
        }
        .status {
            padding: 5px 10px;
            border-radius: 4px;
            font-weight: bold;
        }
        .status.connected {
            background: #4caf50;
            color: white;
        }
        .status.disconnected {
            background: #f44336;
            color: white;
        }
        .chart-container {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            height: 400px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Kafka Producer Dashboard</h1>
            <p>Real-time monitoring of log ingestion performance</p>
            <span id="connection-status" class="status disconnected">Disconnected</span>
        </div>
        
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-value" id="messages-sent">0</div>
                <div class="metric-label">Messages Sent</div>
            </div>
            <div class="metric-card">
                <div class="metric-value" id="messages-failed">0</div>
                <div class="metric-label">Messages Failed</div>
            </div>
            <div class="metric-card">
                <div class="metric-value" id="topics-count">0</div>
                <div class="metric-label">Active Topics</div>
            </div>
            <div class="metric-card">
                <div class="metric-value" id="brokers-count">0</div>
                <div class="metric-label">Kafka Brokers</div>
            </div>
        </div>
        
        <div class="controls">
            <h3>Testing Controls</h3>
            <button class="btn" onclick="sendSampleLogs()">Send Sample Logs</button>
            <button class="btn danger" onclick="sendErrorBurst()">Send Error Burst</button>
            <button class="btn" onclick="refreshStats()">Refresh Stats</button>
        </div>
        
        <div class="chart-container">
            <div id="throughput-chart"></div>
        </div>
    </div>

    <script>
        let socket;
        let messagesSent = 0;
        let messagesFailed = 0;
        let throughputData = [];
        
        function connectWebSocket() {
            socket = new WebSocket(`ws://${window.location.host}/ws`);
            
            socket.onopen = function() {
                document.getElementById('connection-status').textContent = 'Connected';
                document.getElementById('connection-status').className = 'status connected';
            };
            
            socket.onclose = function() {
                document.getElementById('connection-status').textContent = 'Disconnected';
                document.getElementById('connection-status').className = 'status disconnected';
                // Reconnect after 3 seconds
                setTimeout(connectWebSocket, 3000);
            };
            
            socket.onmessage = function(event) {
                const data = JSON.parse(event.data);
                if (data.type === 'stats_update') {
                    updateMetrics(data.data);
                }
            };
        }
        
        function updateMetrics(stats) {
            document.getElementById('topics-count').textContent = stats.topics || 0;
            document.getElementById('brokers-count').textContent = stats.brokers || 0;
            
            // Update throughput chart
            const now = new Date();
            throughputData.push({
                time: now,
                messages: messagesSent
            });
            
            // Keep only last 50 data points
            if (throughputData.length > 50) {
                throughputData.shift();
            }
            
            updateThroughputChart();
        }
        
        function updateThroughputChart() {
            const trace = {
                x: throughputData.map(d => d.time),
                y: throughputData.map(d => d.messages),
                type: 'scatter',
                mode: 'lines+markers',
                name: 'Messages Sent',
                line: { color: '#2196F3' }
            };
            
            const layout = {
                title: 'Message Throughput Over Time',
                xaxis: { title: 'Time' },
                yaxis: { title: 'Messages' },
                margin: { t: 50 }
            };
            
            Plotly.newPlot('throughput-chart', [trace], layout);
        }
        
        async function sendSampleLogs() {
            try {
                const response = await fetch('/api/send-sample', { method: 'POST' });
                const result = await response.json();
                
                if (result.success) {
                    messagesSent += result.logs_sent;
                    messagesFailed += result.logs_failed;
                    document.getElementById('messages-sent').textContent = messagesSent;
                    document.getElementById('messages-failed').textContent = messagesFailed;
                    alert(`Sent ${result.logs_sent} logs, ${result.logs_failed} failed`);
                } else {
                    alert('Error: ' + result.error);
                }
            } catch (error) {
                alert('Request failed: ' + error.message);
            }
        }
        
        async function sendErrorBurst() {
            try {
                const response = await fetch('/api/send-errors', { method: 'POST' });
                const result = await response.json();
                
                if (result.success) {
                    messagesSent += result.error_logs_sent;
                    messagesFailed += result.error_logs_failed;
                    document.getElementById('messages-sent').textContent = messagesSent;
                    document.getElementById('messages-failed').textContent = messagesFailed;
                    alert(`Sent ${result.error_logs_sent} error logs`);
                } else {
                    alert('Error: ' + result.error);
                }
            } catch (error) {
                alert('Request failed: ' + error.message);
            }
        }
        
        async function refreshStats() {
            try {
                const response = await fetch('/api/stats');
                const stats = await response.json();
                updateMetrics(stats);
            } catch (error) {
                alert('Failed to refresh stats: ' + error.message);
            }
        }
        
        // Initialize
        connectWebSocket();
        updateThroughputChart();
    </script>
</body>
</html>
EOF

# Create comprehensive test suite
cat > tests/unit/test_log_entry.py << 'EOF'
import pytest
from datetime import datetime
from src.models.log_entry import LogEntry, LogLevel

def test_log_entry_creation():
    """Test basic log entry creation"""
    log = LogEntry(
        level=LogLevel.INFO,
        message="Test message",
        service="test-service"
    )
    
    assert log.level == LogLevel.INFO
    assert log.message == "Test message"
    assert log.service == "test-service"
    assert log.component == "unknown"  # default value
    assert isinstance(log.timestamp, datetime)

def test_log_entry_serialization():
    """Test log entry serialization to Kafka message"""
    log = LogEntry(
        level=LogLevel.ERROR,
        message="Test error",
        service="test-service",
        user_id="user123"
    )
    
    message = log.to_kafka_message()
    assert isinstance(message, bytes)
    
    # Should be valid JSON
    import json
    data = json.loads(message.decode('utf-8'))
    assert data['level'] == LogLevel.ERROR
    assert data['message'] == "Test error"
    assert data['user_id'] == "user123"

def test_partition_key_logic():
    """Test partition key generation"""
    # Test with user_id
    log1 = LogEntry(
        level=LogLevel.INFO,
        message="Test",
        service="test",
        user_id="user123"
    )
    assert log1.get_partition_key() == "user123"
    
    # Test with session_id when no user_id
    log2 = LogEntry(
        level=LogLevel.INFO,
        message="Test",
        service="test",
        session_id="session456"
    )
    assert log2.get_partition_key() == "session456"
    
    # Test fallback to service
    log3 = LogEntry(
        level=LogLevel.INFO,
        message="Test",
        service="test-service"
    )
    assert log3.get_partition_key() == "test-service"

def test_topic_routing():
    """Test topic routing logic"""
    # Error logs go to error topic
    error_log = LogEntry(
        level=LogLevel.ERROR,
        message="Error",
        service="any-service"
    )
    assert error_log.get_topic() == "logs-errors"
    
    # Database logs go to database topic
    db_log = LogEntry(
        level=LogLevel.INFO,
        message="Query",
        service="database"
    )
    assert db_log.get_topic() == "logs-database"
    
    # Security logs go to security topic
    sec_log = LogEntry(
        level=LogLevel.WARN,
        message="Auth warning",
        service="security"
    )
    assert sec_log.get_topic() == "logs-security"
    
    # Others go to application topic
    app_log = LogEntry(
        level=LogLevel.INFO,
        message="Info",
        service="web-api"
    )
    assert app_log.get_topic() == "logs-application"
EOF

cat > tests/integration/test_producer.py << 'EOF'
import pytest
import time
from unittest.mock import Mock, patch
from src.producer.kafka_producer import KafkaLogProducer
from src.models.log_entry import LogEntry, LogLevel
from src.utils.log_generator import LogGenerator

@pytest.fixture
def mock_producer():
    """Create a mock producer for testing"""
    with patch('src.producer.kafka_producer.Producer') as mock_kafka_producer, \
         patch('src.producer.kafka_producer.AdminClient') as mock_admin:
        
        # Mock the Kafka producer
        producer_instance = Mock()
        mock_kafka_producer.return_value = producer_instance
        
        # Mock admin client
        admin_instance = Mock()
        mock_admin.return_value = admin_instance
        admin_instance.create_topics.return_value = {}
        
        # Create producer with mocked dependencies
        producer = KafkaLogProducer("config/producer_config.yaml")
        
        yield producer, producer_instance

def test_producer_initialization(mock_producer):
    """Test producer initialization"""
    producer, kafka_instance = mock_producer
    
    assert producer.producer is not None
    assert producer.metrics is not None
    assert producer.config is not None

def test_send_single_log(mock_producer):
    """Test sending a single log entry"""
    producer, kafka_instance = mock_producer
    
    log = LogEntry(
        level=LogLevel.INFO,
        message="Test log",
        service="test-service"
    )
    
    # Mock successful send
    kafka_instance.produce.return_value = None
    
    result = producer.send_log(log)
    
    assert result is True
    kafka_instance.produce.assert_called_once()
    
    # Verify the call arguments
    call_args = kafka_instance.produce.call_args
    assert call_args[1]['topic'] == 'logs-application'
    assert call_args[1]['key'] == b'test-service'

def test_send_batch_logs(mock_producer):
    """Test sending a batch of logs"""
    producer, kafka_instance = mock_producer
    
    generator = LogGenerator()
    logs = generator.generate_batch(5, 1)
    
    # Mock successful sends
    kafka_instance.produce.return_value = None
    kafka_instance.poll.return_value = None
    
    results = producer.send_logs_batch(logs)
    
    assert results['sent'] == 5
    assert results['failed'] == 0
    assert kafka_instance.produce.call_count == 5

def test_producer_error_handling(mock_producer):
    """Test error handling in producer"""
    producer, kafka_instance = mock_producer
    
    log = LogEntry(
        level=LogLevel.INFO,
        message="Test log",
        service="test-service"
    )
    
    # Mock failed send
    kafka_instance.produce.side_effect = Exception("Kafka error")
    
    result = producer.send_log(log)
    
    assert result is False

def test_producer_flush(mock_producer):
    """Test producer flush operation"""
    producer, kafka_instance = mock_producer
    
    # Mock flush
    kafka_instance.flush.return_value = 0  # No remaining messages
    
    producer.flush()
    
    kafka_instance.flush.assert_called_once()

def test_producer_stats(mock_producer):
    """Test producer statistics"""
    producer, kafka_instance = mock_producer
    
    # Mock list_topics response
    mock_metadata = Mock()
    mock_metadata.topics = {"topic1": None, "topic2": None}
    mock_metadata.brokers = {"broker1": None}
    kafka_instance.list_topics.return_value = mock_metadata
    
    stats = producer.get_stats()
    
    assert "topics" in stats
    assert "brokers" in stats
    assert stats["topics"] == 2
    assert stats["brokers"] == 1
EOF

cat > tests/performance/test_performance.py << 'EOF'
import pytest
import time
import asyncio
from unittest.mock import Mock, patch
from src.producer.kafka_producer import KafkaLogProducer
from src.utils.log_generator import LogGenerator

@pytest.mark.asyncio
async def test_throughput_performance():
    """Test producer throughput performance"""
    
    with patch('src.producer.kafka_producer.Producer') as mock_kafka_producer, \
         patch('src.producer.kafka_producer.AdminClient') as mock_admin:
        
        # Setup mocks
        producer_instance = Mock()
        mock_kafka_producer.return_value = producer_instance
        producer_instance.produce.return_value = None
        producer_instance.poll.return_value = None
        producer_instance.flush.return_value = 0
        
        admin_instance = Mock()
        mock_admin.return_value = admin_instance
        admin_instance.create_topics.return_value = {}
        
        # Create producer and generator
        producer = KafkaLogProducer("config/producer_config.yaml")
        generator = LogGenerator()
        
        # Performance test parameters
        num_messages = 1000
        start_time = time.time()
        
        # Generate and send logs
        logs = generator.generate_batch(num_messages, 1)
        
        successful_sends = 0
        for log in logs:
            if producer.send_log(log):
                successful_sends += 1
                
        # Flush remaining messages
        producer.flush()
        
        elapsed_time = time.time() - start_time
        throughput = successful_sends / elapsed_time
        
        # Performance assertions
        assert successful_sends == num_messages
        assert throughput > 100  # Should handle >100 messages/second
        assert elapsed_time < 30  # Should complete within 30 seconds
        
        print(f"Throughput: {throughput:.1f} messages/second")
        print(f"Total time: {elapsed_time:.2f} seconds")

def test_batch_performance():
    """Test batch sending performance"""
    
    with patch('src.producer.kafka_producer.Producer') as mock_kafka_producer, \
         patch('src.producer.kafka_producer.AdminClient') as mock_admin:
        
        # Setup mocks
        producer_instance = Mock()
        mock_kafka_producer.return_value = producer_instance
        producer_instance.produce.return_value = None
        producer_instance.poll.return_value = None
        
        admin_instance = Mock()
        mock_admin.return_value = admin_instance
        admin_instance.create_topics.return_value = {}
        
        # Create producer and generator
        producer = KafkaLogProducer("config/producer_config.yaml")
        generator = LogGenerator()
        
        # Test different batch sizes
        batch_sizes = [1, 10, 50, 100]
        
        for batch_size in batch_sizes:
            logs = generator.generate_batch(batch_size, 1)
            
            start_time = time.time()
            results = producer.send_logs_batch(logs)
            elapsed_time = time.time() - start_time
            
            assert results['sent'] == batch_size
            assert results['failed'] == 0
            
            throughput = batch_size / elapsed_time
            print(f"Batch size {batch_size}: {throughput:.1f} messages/second")

def test_memory_usage():
    """Test memory usage doesn't grow excessively"""
    import psutil
    import gc
    
    with patch('src.producer.kafka_producer.Producer') as mock_kafka_producer, \
         patch('src.producer.kafka_producer.AdminClient') as mock_admin:
        
        # Setup mocks
        producer_instance = Mock()
        mock_kafka_producer.return_value = producer_instance
        producer_instance.produce.return_value = None
        producer_instance.poll.return_value = None
        
        admin_instance = Mock()
        mock_admin.return_value = admin_instance
        admin_instance.create_topics.return_value = {}
        
        # Create producer and generator
        producer = KafkaLogProducer("config/producer_config.yaml")
        generator = LogGenerator()
        
        # Measure initial memory
        process = psutil.Process()
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        # Send many logs
        for _ in range(10):
            logs = generator.generate_batch(100, 1)
            producer.send_logs_batch(logs)
            gc.collect()  # Force garbage collection
        
        # Measure final memory
        final_memory = process.memory_info().rss / 1024 / 1024  # MB
        memory_growth = final_memory - initial_memory
        
        print(f"Initial memory: {initial_memory:.1f} MB")
        print(f"Final memory: {final_memory:.1f} MB")
        print(f"Memory growth: {memory_growth:.1f} MB")
        
        # Memory growth should be reasonable
        assert memory_growth < 100  # Less than 100MB growth
EOF

# Create Docker setup
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.6.1
    hostname: zookeeper
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000

  kafka:
    image: confluentinc/cp-kafka:7.6.1
    hostname: kafka
    container_name: kafka
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
      - "29092:29092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'true'

  producer-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: kafka-producer-app
    depends_on:
      - kafka
    ports:
      - "8080:8080"
      - "8000:8000"  # Metrics port
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:29092
    volumes:
      - ./logs:/app/logs
    command: ["python", "web/app.py"]

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    depends_on:
      - kafka
    ports:
      - "8081:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:29092
EOF

cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create logs directory
RUN mkdir -p logs

# Set Python path
ENV PYTHONPATH=/app/src

# Default command
CMD ["python", "src/main.py", "demo"]
EOF

# Create test runner script
cat > run_tests.sh << 'EOF'
#!/bin/bash

echo "🧪 Running Kafka Producer Test Suite"
echo "=================================="

# Activate virtual environment
source venv/bin/activate

# Set Python path
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

echo "📋 Running unit tests..."
python -m pytest tests/unit/ -v --tb=short

echo "🔗 Running integration tests..."  
python -m pytest tests/integration/ -v --tb=short

echo "⚡ Running performance tests..."
python -m pytest tests/performance/ -v --tb=short -s

echo "✅ All tests completed!"
EOF

chmod +x run_tests.sh

# Create build and demo script
cat > build_and_demo.sh << 'EOF'
#!/bin/bash

echo "🚀 Kafka Producer Build and Demo Script"
echo "======================================="

# Check if Kafka is running
check_kafka() {
    echo "🔍 Checking Kafka connectivity..."
    python -c "
from kafka import KafkaProducer
try:
    producer = KafkaProducer(bootstrap_servers=['localhost:9092'], request_timeout_ms=5000)
    producer.close()
    print('✅ Kafka is running')
except:
    print('❌ Kafka not available - starting with Docker')
    exit(1)
" 2>/dev/null || return 1
}

# Start Kafka with Docker if not running
if ! check_kafka; then
    echo "🐳 Starting Kafka with Docker Compose..."
    docker-compose up -d kafka
    
    echo "⏳ Waiting for Kafka to be ready..."
    for i in {1..30}; do
        if check_kafka; then
            break
        fi
        echo "Waiting... ($i/30)"
        sleep 2
    done
    
    if ! check_kafka; then
        echo "❌ Failed to start Kafka"
        exit 1
    fi
fi

# Activate virtual environment
source venv/bin/activate

# Set Python path
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

echo "🧪 Running tests..."
./run_tests.sh

if [ $? -eq 0 ]; then
    echo ""
    echo "🎬 Starting Producer Demo..."
    python src/main.py demo &
    DEMO_PID=$!
    
    echo ""
    echo "📊 Starting Web Dashboard..."
    python web/app.py &
    WEB_PID=$!
    
    echo ""
    echo "⏳ Waiting for services to start..."
    sleep 5
    
    echo ""
    echo "🎯 Demo Information:"
    echo "- Producer Demo: Running (PID: $DEMO_PID)"
    echo "- Web Dashboard: http://localhost:8080"
    echo "- Producer Metrics: http://localhost:8000"
    echo "- Kafka UI: http://localhost:8081"
    echo ""
    echo "💡 Try these commands:"
    echo "  - curl http://localhost:8080/api/stats"
    echo "  - curl -X POST http://localhost:8080/api/send-sample"
    echo ""
    echo "Press Ctrl+C to stop all services"
    
    # Wait for user interrupt
    trap "echo 'Stopping services...'; kill $DEMO_PID $WEB_PID 2>/dev/null; exit" INT
    wait
else
    echo "❌ Tests failed - demo cancelled"
    exit 1
fi
EOF

chmod +x build_and_demo.sh

echo ""
echo "✅ Kafka Producer Project Created Successfully!"
echo ""
echo "📁 Project Structure:"
find . -type f -name "*.py" -o -name "*.yaml" -o -name "*.yml" -o -name "*.sh" | head -20

echo ""
echo "🚀 Quick Start Commands:"
echo "1. Run tests:           ./run_tests.sh"
echo "2. Build and demo:      ./build_and_demo.sh"
echo "3. Docker setup:        docker-compose up -d"
echo "4. Web dashboard:       http://localhost:8080"
echo ""
echo "📊 Expected Demo Results:"
echo "- 100+ sample logs sent to Kafka topics"
echo "- Real-time metrics dashboard"
echo "- Performance >100 messages/second"
echo "- Zero message loss with proper error handling"
echo ""
echo "✨ Ready to build high-performance log producers!"    