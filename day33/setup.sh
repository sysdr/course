#!/bin/bash

# Day 33: Log Consumer Implementation - Complete Setup Script
# Part of 254-Day Hands-On System Design Series

set -e

echo "🚀 Day 33: Setting up Log Consumer Implementation"
echo "=============================================="

# Create project structure
echo "📁 Creating project structure..."
mkdir -p log-consumer-system/{src,tests,config,logs,docs,scripts}
cd log-consumer-system

# Create source directories
mkdir -p src/{consumers,processors,monitoring,utils}
mkdir -p tests/{unit,integration,load}

echo "📝 Creating configuration files..."

# Create requirements.txt with latest compatible libraries
cat > requirements.txt << 'EOF'
redis==5.0.4
pydantic==2.7.1
fastapi==0.111.0
uvicorn==0.29.0
pytest==8.2.0
pytest-asyncio==0.23.6
pytest-cov==5.0.0
aioredis==2.0.1
structlog==24.1.0
prometheus-client==0.20.0
psutil==5.9.8
rich==13.7.1
httpx==0.27.0
asyncio-mqtt==0.16.2
dataclasses-json==0.6.4
typing-extensions==4.11.0
EOF

# Create main consumer implementation
cat > src/consumers/log_consumer.py << 'EOF'
import asyncio
import json
import logging
import time
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional, Callable, Any
import redis.asyncio as redis
from pydantic import BaseModel, Field
import structlog

logger = structlog.get_logger()

@dataclass
class LogMessage:
    id: str
    timestamp: float
    level: str
    message: str
    source: str
    metadata: Dict[str, Any] = None

class ConsumerConfig(BaseModel):
    redis_url: str = "redis://localhost:6379"
    queue_name: str = "logs"
    consumer_group: str = "log-processors"
    consumer_id: str = "consumer-1"
    batch_size: int = 10
    poll_timeout: int = 1000
    max_retries: int = 3

class LogConsumer:
    def __init__(self, config: ConsumerConfig, processor: Callable[[LogMessage], bool]):
        self.config = config
        self.processor = processor
        self.redis_client = None
        self.running = False
        self.processed_count = 0
        self.error_count = 0
        
    async def connect(self):
        """Initialize Redis connection and consumer group"""
        self.redis_client = redis.from_url(self.config.redis_url)
        
        # Create consumer group if it doesn't exist
        try:
            await self.redis_client.xgroup_create(
                self.config.queue_name, 
                self.config.consumer_group, 
                id='0', 
                mkstream=True
            )
            logger.info(f"Created consumer group: {self.config.consumer_group}")
        except redis.ResponseError as e:
            if "BUSYGROUP" not in str(e):
                raise
            logger.info(f"Consumer group already exists: {self.config.consumer_group}")
    
    async def consume(self):
        """Main consumption loop"""
        self.running = True
        logger.info(f"Starting consumer: {self.config.consumer_id}")
        
        while self.running:
            try:
                # Read messages from stream
                messages = await self.redis_client.xreadgroup(
                    self.config.consumer_group,
                    self.config.consumer_id,
                    {self.config.queue_name: '>'},
                    count=self.config.batch_size,
                    block=self.config.poll_timeout
                )
                
                if messages:
                    await self._process_messages(messages)
                
            except Exception as e:
                logger.error(f"Error in consumption loop: {e}")
                self.error_count += 1
                await asyncio.sleep(1)
    
    async def _process_messages(self, messages):
        """Process batch of messages"""
        for stream, msgs in messages:
            for msg_id, fields in msgs:
                try:
                    # Parse message
                    log_data = json.loads(fields[b'data'].decode())
                    log_message = LogMessage(**log_data)
                    
                    # Process message
                    success = await self._process_single_message(log_message)
                    
                    if success:
                        # Acknowledge message
                        await self.redis_client.xack(
                            self.config.queue_name,
                            self.config.consumer_group,
                            msg_id
                        )
                        self.processed_count += 1
                        logger.info(f"Processed message: {msg_id}")
                    else:
                        logger.error(f"Failed to process message: {msg_id}")
                        self.error_count += 1
                        
                except Exception as e:
                    logger.error(f"Error processing message {msg_id}: {e}")
                    self.error_count += 1
    
    async def _process_single_message(self, log_message: LogMessage) -> bool:
        """Process individual log message"""
        try:
            return self.processor(log_message)
        except Exception as e:
            logger.error(f"Processor error: {e}")
            return False
    
    async def stop(self):
        """Gracefully stop consumer"""
        self.running = False
        if self.redis_client:
            await self.redis_client.close()
        logger.info(f"Consumer stopped. Processed: {self.processed_count}, Errors: {self.error_count}")
    
    def get_stats(self) -> Dict[str, int]:
        """Get consumer statistics"""
        return {
            "processed_count": self.processed_count,
            "error_count": self.error_count,
            "success_rate": self.processed_count / max(1, self.processed_count + self.error_count)
        }
EOF

# Create message processor
cat > src/processors/log_processor.py << 'EOF'
import json
import time
from typing import Dict, Any
from dataclasses import asdict
from src.consumers.log_consumer import LogMessage
import structlog

logger = structlog.get_logger()

class LogProcessor:
    def __init__(self):
        self.metrics = {
            "total_processed": 0,
            "error_logs": 0,
            "warn_logs": 0,
            "info_logs": 0,
            "response_times": [],
            "endpoints": {}
        }
    
    def process(self, log_message: LogMessage) -> bool:
        """Process a log message and extract metrics"""
        try:
            self.metrics["total_processed"] += 1
            
            # Count by log level
            level = log_message.level.lower()
            if level == "error":
                self.metrics["error_logs"] += 1
            elif level == "warn":
                self.metrics["warn_logs"] += 1
            elif level == "info":
                self.metrics["info_logs"] += 1
            
            # Extract metrics from web server logs
            if self._is_web_server_log(log_message):
                self._process_web_log(log_message)
            
            # Store processed log (in production, this would go to database)
            self._store_processed_log(log_message)
            
            logger.info(f"Processed log from {log_message.source}: {log_message.level}")
            return True
            
        except Exception as e:
            logger.error(f"Error processing log: {e}")
            return False
    
    def _is_web_server_log(self, log_message: LogMessage) -> bool:
        """Check if this is a web server access log"""
        return (log_message.source == "web-server" and 
                log_message.metadata and 
                "response_time" in log_message.metadata)
    
    def _process_web_log(self, log_message: LogMessage):
        """Extract metrics from web server logs"""
        metadata = log_message.metadata
        
        # Track response times
        if "response_time" in metadata:
            response_time = float(metadata["response_time"])
            self.metrics["response_times"].append(response_time)
        
        # Track endpoints
        if "endpoint" in metadata:
            endpoint = metadata["endpoint"]
            if endpoint not in self.metrics["endpoints"]:
                self.metrics["endpoints"][endpoint] = {
                    "count": 0,
                    "total_response_time": 0,
                    "errors": 0
                }
            
            self.metrics["endpoints"][endpoint]["count"] += 1
            if "response_time" in metadata:
                self.metrics["endpoints"][endpoint]["total_response_time"] += float(metadata["response_time"])
            
            if "status_code" in metadata and int(metadata["status_code"]) >= 400:
                self.metrics["endpoints"][endpoint]["errors"] += 1
    
    def _store_processed_log(self, log_message: LogMessage):
        """Store processed log (mock implementation)"""
        # In production, this would store to database
        log_data = asdict(log_message)
        log_data["processed_at"] = time.time()
        
        # For demo, just log to file
        with open("logs/processed_logs.jsonl", "a") as f:
            f.write(json.dumps(log_data) + "\n")
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get processing metrics"""
        metrics = self.metrics.copy()
        
        # Calculate average response times per endpoint
        for endpoint, data in metrics["endpoints"].items():
            if data["count"] > 0:
                data["avg_response_time"] = data["total_response_time"] / data["count"]
                data["error_rate"] = data["errors"] / data["count"]
        
        # Calculate overall average response time
        if metrics["response_times"]:
            metrics["avg_response_time"] = sum(metrics["response_times"]) / len(metrics["response_times"])
        
        return metrics
EOF

# Create consumer manager
cat > src/consumers/consumer_manager.py << 'EOF'
import asyncio
import signal
from typing import List, Dict, Any
from src.consumers.log_consumer import LogConsumer, ConsumerConfig
from src.processors.log_processor import LogProcessor
import structlog

logger = structlog.get_logger()

class ConsumerManager:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.consumers: List[LogConsumer] = []
        self.processor = LogProcessor()
        self.running = False
    
    async def start(self):
        """Start multiple consumer instances"""
        self.running = True
        
        # Create consumers based on configuration
        num_consumers = self.config.get("num_consumers", 2)
        
        for i in range(num_consumers):
            consumer_config = ConsumerConfig(
                redis_url=self.config.get("redis_url", "redis://localhost:6379"),
                queue_name=self.config.get("queue_name", "logs"),
                consumer_group=self.config.get("consumer_group", "log-processors"),
                consumer_id=f"consumer-{i+1}",
                batch_size=self.config.get("batch_size", 10)
            )
            
            consumer = LogConsumer(consumer_config, self.processor.process)
            await consumer.connect()
            self.consumers.append(consumer)
        
        # Start all consumers
        tasks = [consumer.consume() for consumer in self.consumers]
        
        # Setup signal handlers
        self._setup_signal_handlers()
        
        logger.info(f"Started {len(self.consumers)} consumers")
        
        try:
            await asyncio.gather(*tasks)
        except asyncio.CancelledError:
            logger.info("Consumer tasks cancelled")
    
    async def stop(self):
        """Stop all consumers gracefully"""
        logger.info("Stopping consumer manager...")
        self.running = False
        
        # Stop all consumers
        for consumer in self.consumers:
            await consumer.stop()
        
        logger.info("All consumers stopped")
    
    def _setup_signal_handlers(self):
        """Setup graceful shutdown handlers"""
        def signal_handler(sig, frame):
            logger.info(f"Received signal {sig}, shutting down...")
            asyncio.create_task(self.stop())
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get aggregated statistics from all consumers"""
        stats = {
            "total_processed": 0,
            "total_errors": 0,
            "consumers": []
        }
        
        for i, consumer in enumerate(self.consumers):
            consumer_stats = consumer.get_stats()
            stats["consumers"].append({
                "id": f"consumer-{i+1}",
                **consumer_stats
            })
            stats["total_processed"] += consumer_stats["processed_count"]
            stats["total_errors"] += consumer_stats["error_count"]
        
        # Add processor metrics
        stats["processor_metrics"] = self.processor.get_metrics()
        
        return stats
EOF

# Create monitoring dashboard
cat > src/monitoring/dashboard.py << 'EOF'
import asyncio
import json
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
import uvicorn
from src.consumers.consumer_manager import ConsumerManager
import structlog

logger = structlog.get_logger()

app = FastAPI(title="Log Consumer Dashboard", version="1.0.0")

# Global consumer manager instance
consumer_manager = None

@app.get("/", response_class=HTMLResponse)
async def dashboard():
    """Main dashboard page"""
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Log Consumer Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
            .container { max-width: 1200px; margin: 0 auto; }
            .card { background: white; padding: 20px; margin: 20px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .metric { display: inline-block; margin: 10px 20px; padding: 10px; background: #e3f2fd; border-radius: 4px; }
            .metric-value { font-size: 24px; font-weight: bold; color: #1976d2; }
            .metric-label { font-size: 12px; color: #666; }
            .consumer { margin: 10px 0; padding: 10px; background: #f8f9fa; border-radius: 4px; }
            .refresh-btn { background: #4caf50; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }
            .endpoint-table { width: 100%; border-collapse: collapse; }
            .endpoint-table th, .endpoint-table td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
            .endpoint-table th { background-color: #f2f2f2; }
        </style>
        <script>
            async function refreshStats() {
                try {
                    const response = await fetch('/stats');
                    const stats = await response.json();
                    updateDashboard(stats);
                } catch (error) {
                    console.error('Error fetching stats:', error);
                }
            }
            
            function updateDashboard(stats) {
                document.getElementById('total-processed').textContent = stats.total_processed;
                document.getElementById('total-errors').textContent = stats.total_errors;
                document.getElementById('success-rate').textContent = 
                    ((stats.total_processed / Math.max(1, stats.total_processed + stats.total_errors)) * 100).toFixed(1) + '%';
                
                // Update consumer list
                const consumerList = document.getElementById('consumer-list');
                consumerList.innerHTML = '';
                stats.consumers.forEach(consumer => {
                    const div = document.createElement('div');
                    div.className = 'consumer';
                    div.innerHTML = `
                        <strong>${consumer.id}</strong> - 
                        Processed: ${consumer.processed_count}, 
                        Errors: ${consumer.error_count}, 
                        Success Rate: ${(consumer.success_rate * 100).toFixed(1)}%
                    `;
                    consumerList.appendChild(div);
                });
                
                // Update endpoint metrics
                const metrics = stats.processor_metrics;
                if (metrics && metrics.endpoints) {
                    updateEndpointTable(metrics.endpoints);
                }
            }
            
            function updateEndpointTable(endpoints) {
                const tbody = document.getElementById('endpoint-tbody');
                tbody.innerHTML = '';
                
                Object.entries(endpoints).forEach(([endpoint, data]) => {
                    const row = document.createElement('tr');
                    row.innerHTML = `
                        <td>${endpoint}</td>
                        <td>${data.count}</td>
                        <td>${data.avg_response_time ? data.avg_response_time.toFixed(2) + 'ms' : 'N/A'}</td>
                        <td>${data.errors}</td>
                        <td>${data.error_rate ? (data.error_rate * 100).toFixed(1) + '%' : '0%'}</td>
                    `;
                    tbody.appendChild(row);
                });
            }
            
            // Auto-refresh every 5 seconds
            setInterval(refreshStats, 5000);
            
            // Initial load
            window.onload = refreshStats;
        </script>
    </head>
    <body>
        <div class="container">
            <h1>Log Consumer Dashboard</h1>
            
            <div class="card">
                <h2>Overall Statistics</h2>
                <div class="metric">
                    <div class="metric-value" id="total-processed">0</div>
                    <div class="metric-label">Total Processed</div>
                </div>
                <div class="metric">
                    <div class="metric-value" id="total-errors">0</div>
                    <div class="metric-label">Total Errors</div>
                </div>
                <div class="metric">
                    <div class="metric-value" id="success-rate">0%</div>
                    <div class="metric-label">Success Rate</div>
                </div>
                <button class="refresh-btn" onclick="refreshStats()">Refresh</button>
            </div>
            
            <div class="card">
                <h2>Consumer Status</h2>
                <div id="consumer-list"></div>
            </div>
            
            <div class="card">
                <h2>Endpoint Metrics</h2>
                <table class="endpoint-table">
                    <thead>
                        <tr>
                            <th>Endpoint</th>
                            <th>Requests</th>
                            <th>Avg Response Time</th>
                            <th>Errors</th>
                            <th>Error Rate</th>
                        </tr>
                    </thead>
                    <tbody id="endpoint-tbody"></tbody>
                </table>
            </div>
        </div>
    </body>
    </html>
    """
    return html

@app.get("/stats")
async def get_stats():
    """Get consumer statistics"""
    if not consumer_manager:
        raise HTTPException(status_code=503, detail="Consumer manager not initialized")
    
    return consumer_manager.get_stats()

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": asyncio.get_event_loop().time()}

def set_consumer_manager(manager: ConsumerManager):
    """Set the global consumer manager instance"""
    global consumer_manager
    consumer_manager = manager
EOF

# Create main application
cat > src/main.py << 'EOF'
import asyncio
import json
import signal
import sys
from typing import Dict, Any
from src.consumers.consumer_manager import ConsumerManager
from src.monitoring.dashboard import app, set_consumer_manager
import uvicorn
import structlog

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

async def main():
    """Main application entry point"""
    config = {
        "redis_url": "redis://localhost:6379",
        "queue_name": "logs",
        "consumer_group": "log-processors",
        "num_consumers": 2,
        "batch_size": 10
    }
    
    # Create consumer manager
    manager = ConsumerManager(config)
    set_consumer_manager(manager)
    
    # Start dashboard server in background
    dashboard_task = asyncio.create_task(
        asyncio.to_thread(
            uvicorn.run, app, host="0.0.0.0", port=8000, log_level="info"
        )
    )
    
    logger.info("Starting log consumer system...")
    logger.info("Dashboard available at: http://localhost:8000")
    
    try:
        # Start consumer manager
        await manager.start()
    except KeyboardInterrupt:
        logger.info("Received interrupt signal")
    except Exception as e:
        logger.error(f"Application error: {e}")
    finally:
        await manager.stop()
        dashboard_task.cancel()
        logger.info("Application stopped")

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Create configuration file
cat > config/consumer_config.json << 'EOF'
{
    "redis": {
        "url": "redis://localhost:6379",
        "max_connections": 20
    },
    "consumers": {
        "queue_name": "logs",
        "consumer_group": "log-processors",
        "num_consumers": 2,
        "batch_size": 10,
        "poll_timeout": 1000,
        "max_retries": 3
    },
    "processing": {
        "enable_metrics": true,
        "store_processed_logs": true,
        "log_retention_days": 7
    },
    "monitoring": {
        "dashboard_port": 8000,
        "metrics_enabled": true,
        "health_check_interval": 30
    }
}
EOF

# Create Docker configuration
cat > Dockerfile << 'EOF'
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
COPY . .

# Create logs directory
RUN mkdir -p logs

# Expose port for dashboard
EXPOSE 8000

# Run the application
CMD ["python", "-m", "src.main"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:7.0-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

  log-consumer:
    build: .
    ports:
      - "8000:8000"
    depends_on:
      - redis
    environment:
      - REDIS_URL=redis://redis:6379
    volumes:
      - ./logs:/app/logs
      - ./config:/app/config

volumes:
  redis_data:
EOF

# Create test files
echo "🧪 Creating test files..."

cat > tests/unit/test_log_consumer.py << 'EOF'
import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock
from src.consumers.log_consumer import LogConsumer, ConsumerConfig, LogMessage

@pytest.fixture
def consumer_config():
    return ConsumerConfig(
        redis_url="redis://localhost:6379",
        consumer_id="test-consumer"
    )

@pytest.fixture
def mock_processor():
    return MagicMock(return_value=True)

@pytest.fixture
def log_consumer(consumer_config, mock_processor):
    return LogConsumer(consumer_config, mock_processor)

@pytest.mark.asyncio
async def test_consumer_creation(log_consumer):
    """Test consumer can be created with valid config"""
    assert log_consumer.config.consumer_id == "test-consumer"
    assert log_consumer.processed_count == 0
    assert log_consumer.error_count == 0

@pytest.mark.asyncio
async def test_process_single_message(log_consumer):
    """Test processing a single log message"""
    log_message = LogMessage(
        id="test-1",
        timestamp=1234567890.0,
        level="INFO",
        message="Test log message",
        source="test-app"
    )
    
    result = await log_consumer._process_single_message(log_message)
    assert result is True
    log_consumer.processor.assert_called_once_with(log_message)

def test_get_stats(log_consumer):
    """Test getting consumer statistics"""
    log_consumer.processed_count = 10
    log_consumer.error_count = 2
    
    stats = log_consumer.get_stats()
    assert stats["processed_count"] == 10
    assert stats["error_count"] == 2
    assert abs(stats["success_rate"] - (10/12)) < 0.001
EOF

cat > tests/unit/test_log_processor.py << 'EOF'
import pytest
import tempfile
import os
from src.processors.log_processor import LogProcessor
from src.consumers.log_consumer import LogMessage

@pytest.fixture
def log_processor():
    return LogProcessor()

@pytest.fixture
def web_server_log():
    return LogMessage(
        id="web-1",
        timestamp=1234567890.0,
        level="INFO",
        message="GET /api/users 200",
        source="web-server",
        metadata={
            "endpoint": "/api/users",
            "response_time": 45.2,
            "status_code": 200,
            "method": "GET"
        }
    )

def test_process_basic_log(log_processor):
    """Test processing a basic log message"""
    log_message = LogMessage(
        id="test-1",
        timestamp=1234567890.0,
        level="ERROR",
        message="Database connection failed",
        source="app-server"
    )
    
    result = log_processor.process(log_message)
    assert result is True
    assert log_processor.metrics["total_processed"] == 1
    assert log_processor.metrics["error_logs"] == 1

def test_process_web_server_log(log_processor, web_server_log):
    """Test processing web server log with metrics extraction"""
    result = log_processor.process(web_server_log)
    
    assert result is True
    assert log_processor.metrics["total_processed"] == 1
    assert len(log_processor.metrics["response_times"]) == 1
    assert log_processor.metrics["response_times"][0] == 45.2
    assert "/api/users" in log_processor.metrics["endpoints"]

def test_get_metrics(log_processor, web_server_log):
    """Test getting processor metrics"""
    log_processor.process(web_server_log)
    
    metrics = log_processor.get_metrics()
    assert metrics["total_processed"] == 1
    assert metrics["avg_response_time"] == 45.2
    assert "/api/users" in metrics["endpoints"]
    assert metrics["endpoints"]["/api/users"]["avg_response_time"] == 45.2
EOF

cat > tests/integration/test_consumer_integration.py << 'EOF'
import pytest
import asyncio
import json
import redis.asyncio as redis
from src.consumers.log_consumer import LogConsumer, ConsumerConfig
from src.processors.log_processor import LogProcessor

@pytest.fixture
def integration_config():
    return ConsumerConfig(
        redis_url="redis://localhost:6379",
        queue_name="test-logs",
        consumer_group="test-processors",
        consumer_id="test-consumer-integration"
    )

@pytest.mark.asyncio
async def test_end_to_end_processing(integration_config):
    """Test complete message flow from queue to processing"""
    # Create Redis client
    redis_client = redis.from_url("redis://localhost:6379")
    
    # Setup
    processor = LogProcessor()
    consumer = LogConsumer(integration_config, processor.process)
    
    # Add test message to stream
    test_message = {
        "id": "integration-test-1",
        "timestamp": 1234567890.0,
        "level": "INFO",
        "message": "Integration test message",
        "source": "test-app"
    }
    
    await redis_client.xadd(
        integration_config.queue_name,
        {"data": json.dumps(test_message)}
    )
    
    # Connect consumer and process messages
    await consumer.connect()
    
    # Process for a short time
    consume_task = asyncio.create_task(consumer.consume())
    await asyncio.sleep(2)  # Let it process
    
    await consumer.stop()
    consume_task.cancel()
    
    # Clean up
    await redis_client.close()
    
    # Verify processing
    assert consumer.processed_count > 0
    assert processor.metrics["total_processed"] > 0
EOF

# Create load test
cat > tests/load/test_consumer_load.py << 'EOF'
import pytest
import asyncio
import json
import time
import redis.asyncio as redis
from src.consumers.consumer_manager import ConsumerManager

@pytest.mark.asyncio
async def test_consumer_load():
    """Load test with multiple messages"""
    # Configuration for load test
    config = {
        "redis_url": "redis://localhost:6379",
        "queue_name": "load-test-logs",
        "consumer_group": "load-test-processors",
        "num_consumers": 3,
        "batch_size": 50
    }
    
    # Generate test messages
    redis_client = redis.from_url(config["redis_url"])
    
    print("Generating test messages...")
    start_time = time.time()
    
    # Add 1000 test messages
    for i in range(1000):
        test_message = {
            "id": f"load-test-{i}",
            "timestamp": time.time(),
            "level": "INFO" if i % 4 != 2 else "ERROR",
            "message": f"Load test message {i}",
            "source": "load-test-app",
            "metadata": {
                "endpoint": f"/api/endpoint{i % 10}",
                "response_time": 20 + (i % 100),
                "status_code": 200 if i % 10 != 0 else 500
            }
        }
        
        await redis_client.xadd(
            config["queue_name"],
            {"data": json.dumps(test_message)}
        )
    
    generation_time = time.time() - start_time
    print(f"Generated 1000 messages in {generation_time:.2f} seconds")
    
    # Start consumer manager
    manager = ConsumerManager(config)
    
    processing_start = time.time()
    
    # Start processing (run for 30 seconds max)
    try:
        await asyncio.wait_for(manager.start(), timeout=30.0)
    except asyncio.TimeoutError:
        pass
    finally:
        await manager.stop()
    
    processing_time = time.time() - processing_start
    
    # Get final stats
    stats = manager.get_stats()
    
    print(f"Load Test Results:")
    print(f"Processing time: {processing_time:.2f} seconds")
    print(f"Total processed: {stats['total_processed']}")
    print(f"Total errors: {stats['total_errors']}")
    print(f"Messages per second: {stats['total_processed'] / processing_time:.2f}")
    
    await redis_client.close()
    
    # Assertions
    assert stats['total_processed'] > 0
    assert stats['total_processed'] / processing_time > 10  # At least 10 msg/sec
EOF

# Create demo data generator
cat > scripts/generate_demo_logs.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import json
import random
import time
import redis.asyncio as redis
from datetime import datetime

async def generate_demo_logs():
    """Generate demo log data for testing consumers"""
    client = redis.from_url("redis://localhost:6379")
    
    # Sample log templates
    log_templates = [
        {
            "level": "INFO",
            "source": "web-server",
            "message_template": "{method} {endpoint} {status}",
            "metadata_template": {
                "endpoint": "/api/users",
                "method": "GET",
                "status_code": 200,
                "response_time": lambda: random.uniform(10, 100)
            }
        },
        {
            "level": "ERROR",
            "source": "database",
            "message_template": "Database connection failed: {error}",
            "metadata_template": {
                "error": "Connection timeout",
                "retry_count": lambda: random.randint(1, 5)
            }
        },
        {
            "level": "WARN",
            "source": "auth-service",
            "message_template": "Failed login attempt from {ip}",
            "metadata_template": {
                "ip": lambda: f"192.168.1.{random.randint(1, 255)}",
                "username": lambda: random.choice(["admin", "user", "test"])
            }
        }
    ]
    
    endpoints = ["/api/users", "/api/orders", "/api/products", "/api/auth", "/api/metrics"]
    methods = ["GET", "POST", "PUT", "DELETE"]
    
    print("Generating demo logs...")
    
    for i in range(100):
        template = random.choice(log_templates)
        
        # Create log message
        log_message = {
            "id": f"demo-{i}",
            "timestamp": time.time(),
            "level": template["level"],
            "source": template["source"],
            "message": template["message_template"].format(
                method=random.choice(methods),
                endpoint=random.choice(endpoints),
                status=random.choice([200, 404, 500]),
                error="Connection timeout",
                ip=f"192.168.1.{random.randint(1, 255)}"
            )
        }
        
        # Add metadata
        metadata = {}
        for key, value in template["metadata_template"].items():
            if callable(value):
                metadata[key] = value()
            else:
                metadata[key] = value
        
        # For web server logs, randomize endpoint and response time
        if template["source"] == "web-server":
            metadata["endpoint"] = random.choice(endpoints)
            metadata["method"] = random.choice(methods)
            metadata["status_code"] = random.choice([200, 200, 200, 404, 500])  # Weighted towards 200
            metadata["response_time"] = random.uniform(10, 200)
        
        log_message["metadata"] = metadata
        
        # Send to Redis stream
        await client.xadd("logs", {"data": json.dumps(log_message)})
        
        if (i + 1) % 20 == 0:
            print(f"Generated {i + 1} logs...")
            await asyncio.sleep(0.1)  # Small delay
    
    await client.close()
    print("Demo log generation complete!")

if __name__ == "__main__":
    asyncio.run(generate_demo_logs())
EOF

chmod +x scripts/generate_demo_logs.py

# Create build and test scripts
echo "🔧 Creating build and test scripts..."

cat > scripts/build.sh << 'EOF'
#!/bin/bash

set -e

echo "🏗️  Building Log Consumer System"
echo "================================"

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Create required directories
echo "📁 Creating directories..."
mkdir -p logs
touch logs/processed_logs.jsonl

# Run code quality checks
echo "🔍 Running code quality checks..."
if command -v flake8 &> /dev/null; then
    flake8 src/ --max-line-length=100 --ignore=E203,W503 || echo "Flake8 not available, skipping..."
fi

echo "✅ Build complete!"
EOF

cat > scripts/test.sh << 'EOF'
#!/bin/bash

set -e

echo "🧪 Running Tests"
echo "==============="

# Unit tests
echo "Running unit tests..."
python -m pytest tests/unit/ -v --tb=short

# Integration tests (if Redis is available)
if redis-cli ping &> /dev/null; then
    echo "Running integration tests..."
    python -m pytest tests/integration/ -v --tb=short
else
    echo "⚠️  Redis not available, skipping integration tests"
fi

echo "✅ All tests passed!"
EOF

cat > scripts/demo.sh << 'EOF'
#!/bin/bash

set -e

echo "🎮 Running Consumer Demo"
echo "======================="

# Check if Redis is running
if ! redis-cli ping &> /dev/null; then
    echo "❌ Redis is not running. Please start Redis first:"
    echo "   docker run -d -p 6379:6379 redis:7.0-alpine"
    exit 1
fi

# Generate demo data
echo "📊 Generating demo logs..."
python scripts/generate_demo_logs.py &

# Wait a moment for data generation
sleep 2

# Start consumer system
echo "🚀 Starting consumer system..."
echo "Dashboard will be available at: http://localhost:8000"
python -m src.main
EOF

chmod +x scripts/*.sh

# Create one-click setup script
cat > setup.sh << 'EOF'
#!/bin/bash

set -e

echo "🚀 Day 33: Log Consumer System - One-Click Setup"
echo "================================================"

# Install system dependencies if needed
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y python3-pip redis-server
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &> /dev/null; then
        brew install redis python3
    fi
fi

# Build the project
echo "🏗️  Building project..."
bash scripts/build.sh

# Start Redis if not running
if ! redis-cli ping &> /dev/null 2>&1; then
    echo "🔴 Starting Redis..."
    if command -v redis-server &> /dev/null; then
        redis-server --daemonize yes
        sleep 2
    else
        echo "Starting Redis with Docker..."
        docker run -d -p 6379:6379 --name redis-consumer redis:7.0-alpine
        sleep 5
    fi
fi

# Run tests
echo "🧪 Running tests..."
bash scripts/test.sh

# Run demo
echo "🎮 Starting demo..."
bash scripts/demo.sh
EOF

chmod +x setup.sh

# Create verification script
cat > scripts/verify.sh << 'EOF'
#!/bin/bash

echo "🔍 Verifying Log Consumer Implementation"
echo "======================================"

# Check file structure
echo "📁 Checking project structure..."
files=(
    "src/consumers/log_consumer.py"
    "src/processors/log_processor.py"
    "src/consumers/consumer_manager.py"
    "src/monitoring/dashboard.py"
    "src/main.py"
    "tests/unit/test_log_consumer.py"
    "tests/unit/test_log_processor.py"
    "tests/integration/test_consumer_integration.py"
    "config/consumer_config.json"
    "requirements.txt"
    "Dockerfile"
    "docker-compose.yml"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (missing)"
    fi
done

# Check Python syntax
echo -e "\n🐍 Checking Python syntax..."
python -m py_compile src/consumers/log_consumer.py
python -m py_compile src/processors/log_processor.py
python -m py_compile src/consumers/consumer_manager.py
python -m py_compile src/monitoring/dashboard.py
python -m py_compile src/main.py

echo "✅ All Python files have valid syntax!"

# Check if Redis is accessible
echo -e "\n🔴 Testing Redis connection..."
if redis-cli ping &> /dev/null; then
    echo "✅ Redis is running and accessible"
else
    echo "⚠️  Redis is not running"
fi

# Test import functionality
echo -e "\n📦 Testing imports..."
python -c "
try:
    from src.consumers.log_consumer import LogConsumer, ConsumerConfig
    from src.processors.log_processor import LogProcessor
    from src.consumers.consumer_manager import ConsumerManager
    print('✅ All imports successful')
except ImportError as e:
    print(f'❌ Import error: {e}')
    exit(1)
"

echo -e "\n🎉 Verification complete!"
EOF

chmod +x scripts/verify.sh

echo "✅ Project structure created successfully!"
echo "🔍 Running verification..."
bash scripts/verify.sh

echo ""
echo "🎉 Day 33: Log Consumer Implementation Complete!"
echo "=============================================="
echo ""
echo "📁 Project Structure:"
echo "   src/consumers/     - Consumer implementations"
echo "   src/processors/    - Log processing logic"
echo "   src/monitoring/    - Dashboard and monitoring"
echo "   tests/            - Unit, integration, and load tests"
echo "   scripts/          - Build, test, and demo scripts"
echo ""
echo "🚀 Quick Start:"
echo "   1. Install dependencies: pip install -r requirements.txt"
echo "   2. Start Redis: redis-server"
echo "   3. Generate demo data: python scripts/generate_demo_logs.py"
echo "   4. Run consumers: python -m src.main"
echo "   5. View dashboard: http://localhost:8000"
echo ""
echo "🐳 Docker Quick Start:"
echo "   docker-compose up --build"
echo ""
echo "🧪 Run Tests:"
echo "   bash scripts/test.sh"
echo ""
echo "📊 Generate Demo Data:"
echo "   python scripts/generate_demo_logs.py"
EOF