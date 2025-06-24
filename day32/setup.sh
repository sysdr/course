#!/bin/bash

# Day 32: Log Producer Implementation Script
# Complete project setup, build, test, and verification

set -e  # Exit on any error

echo "🚀 Starting Day 32: Log Producer Implementation"
echo "=============================================="

# Clean up any existing setup
rm -rf log_producer_project
mkdir -p log_producer_project
cd log_producer_project

echo "📁 Creating project structure..."
mkdir -p {src,tests,config,scripts,docker,docs}
mkdir -p src/{producer,utils,models}

echo "📝 Creating project files..."

# Package init files
touch src/__init__.py
touch src/producer/__init__.py
touch src/models/__init__.py
touch src/utils/__init__.py

# Main producer service
cat > src/producer/producer.py << 'EOF'
import asyncio
import json
import logging
import time
from datetime import datetime
from typing import List, Dict, Any
import pika
import aiohttp
from aiohttp import web
import signal
import sys
import os

try:
    from .batch_manager import BatchManager
    from .connection_pool import ConnectionPool
    from .health_monitor import HealthMonitor
    from ..models.log_entry import LogEntry
except ImportError:
    # Fallback for direct execution
    from producer.batch_manager import BatchManager
    from producer.connection_pool import ConnectionPool
    from producer.health_monitor import HealthMonitor
    from models.log_entry import LogEntry

class LogProducer:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.batch_manager = BatchManager(
            max_size=config.get('batch_size', 50),
            max_wait_ms=config.get('batch_timeout_ms', 100)
        )
        self.connection_pool = ConnectionPool(config['rabbitmq'])
        self.health_monitor = HealthMonitor()
        self.running = True
        
    async def start(self):
        """Start the producer service"""
        logging.info("Starting Log Producer service...")
        
        # Initialize connection pool
        await self.connection_pool.initialize()
        
        # Start batch processing
        asyncio.create_task(self._batch_processor())
        
        # Start HTTP server
        app = web.Application()
        app.router.add_post('/logs', self.handle_log_submission)
        app.router.add_get('/health', self.handle_health_check)
        app.router.add_get('/metrics', self.handle_metrics)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', self.config.get('port', 8080))
        await site.start()
        
        logging.info(f"Producer service started on port {self.config.get('port', 8080)}")
        
    async def handle_log_submission(self, request):
        """Handle incoming log submission"""
        try:
            data = await request.json()
            log_entry = LogEntry.from_dict(data)
            
            await self.batch_manager.add_log(log_entry)
            self.health_monitor.record_log_received()
            
            return web.json_response({'status': 'accepted'})
        except Exception as e:
            logging.error(f"Error processing log submission: {e}")
            return web.json_response({'error': str(e)}, status=400)
    
    async def handle_health_check(self, request):
        """Health check endpoint"""
        health_status = await self.health_monitor.get_health_status()
        status_code = 200 if health_status['healthy'] else 503
        return web.json_response(health_status, status=status_code)
    
    async def handle_metrics(self, request):
        """Metrics endpoint"""
        metrics = await self.health_monitor.get_metrics()
        return web.json_response(metrics)
    
    async def _batch_processor(self):
        """Background task to process batches"""
        while self.running:
            try:
                batch = await self.batch_manager.get_batch()
                if batch:
                    await self._publish_batch(batch)
                await asyncio.sleep(0.01)  # Small delay to prevent busy waiting
            except Exception as e:
                logging.error(f"Batch processing error: {e}")
                await asyncio.sleep(1)  # Back off on error
    
    async def _publish_batch(self, batch: List[LogEntry]):
        """Publish a batch of logs to RabbitMQ"""
        try:
            start_time = time.time()
            
            # Serialize batch
            messages = [log.to_json() for log in batch]
            
            # Publish to RabbitMQ
            success = await self.connection_pool.publish_batch(messages)
            
            if success:
                duration = time.time() - start_time
                self.health_monitor.record_batch_published(len(batch), duration)
                logging.debug(f"Published batch of {len(batch)} logs in {duration:.3f}s")
            else:
                self.health_monitor.record_batch_failed(len(batch))
                logging.error(f"Failed to publish batch of {len(batch)} logs")
                
        except Exception as e:
            logging.error(f"Error publishing batch: {e}")
            self.health_monitor.record_batch_failed(len(batch))
    
    async def shutdown(self):
        """Graceful shutdown"""
        logging.info("Shutting down Log Producer...")
        self.running = False
        
        # Flush remaining logs
        await self.batch_manager.flush_all()
        
        # Close connections
        await self.connection_pool.close()
        
        logging.info("Log Producer shutdown complete")

async def main():
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Load configuration
    config = {
    'rabbitmq': {
        'host': os.environ.get('RABBITMQ_HOST', 'localhost'),
        'port': int(os.environ.get('RABBITMQ_PORT', 5672)),
        'exchange': 'logs_exchange',
        'routing_key': 'application.logs'
    },
    'batch_size': 50,
    'batch_timeout_ms': 100,
    'port': 8080
    }
    
    # Create and start producer
    producer = LogProducer(config)
    
    # Handle graceful shutdown
    def signal_handler():
        asyncio.create_task(producer.shutdown())
    
    # Setup signal handlers
    for sig in [signal.SIGTERM, signal.SIGINT]:
        signal.signal(sig, lambda s, f: signal_handler())
    
    try:
        await producer.start()
        # Keep running
        while producer.running:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        await producer.shutdown()

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Batch Manager
cat > src/producer/batch_manager.py << 'EOF'
import asyncio
import time
from typing import List, Optional

try:
    from ..models.log_entry import LogEntry
except ImportError:
    from models.log_entry import LogEntry

class BatchManager:
    def __init__(self, max_size: int = 50, max_wait_ms: int = 100):
        self.max_size = max_size
        self.max_wait_ms = max_wait_ms
        self.current_batch = []
        self.last_flush_time = time.time()
        self.lock = asyncio.Lock()
        self.batch_queue = asyncio.Queue()
        
    async def add_log(self, log_entry):
        """Add a log entry to the current batch"""
        async with self.lock:
            self.current_batch.append(log_entry)
            
            # Check if we should flush
            should_flush = (
                len(self.current_batch) >= self.max_size or
                (time.time() - self.last_flush_time) * 1000 >= self.max_wait_ms
            )
            
            if should_flush:
                await self._flush_current_batch()
    
    async def get_batch(self) -> Optional[List]:
        """Get the next batch to process"""
        try:
            # Check time-based flush
            async with self.lock:
                if (self.current_batch and 
                    (time.time() - self.last_flush_time) * 1000 >= self.max_wait_ms):
                    await self._flush_current_batch()
            
            # Get batch from queue (with timeout)
            return await asyncio.wait_for(self.batch_queue.get(), timeout=0.1)
        except asyncio.TimeoutError:
            return None
    
    async def _flush_current_batch(self):
        """Flush the current batch to the queue"""
        if self.current_batch:
            batch_copy = self.current_batch.copy()
            self.current_batch.clear()
            self.last_flush_time = time.time()
            await self.batch_queue.put(batch_copy)
    
    async def flush_all(self):
        """Flush all remaining logs"""
        async with self.lock:
            if self.current_batch:
                await self._flush_current_batch()
EOF

# Connection Pool
cat > src/producer/connection_pool.py << 'EOF'
import asyncio
import logging
import json
from typing import List, Dict, Any
import pika
import time

class ConnectionPool:
    def __init__(self, rabbitmq_config: Dict[str, Any]):
        self.config = rabbitmq_config
        self.connection = None
        self.channel = None
        self.circuit_breaker = CircuitBreaker()
        
    async def initialize(self):
        """Initialize RabbitMQ connection"""
        try:
            # Create connection
            connection_params = pika.ConnectionParameters(
                host=self.config['host'],
                port=self.config['port'],
                heartbeat=600,
                blocked_connection_timeout=300
            )
            
            self.connection = pika.BlockingConnection(connection_params)
            self.channel = self.connection.channel()
            
            # Declare exchange
            self.channel.exchange_declare(
                exchange=self.config['exchange'],
                exchange_type='topic',
                durable=True
            )
            
            logging.info("RabbitMQ connection established")
            self.circuit_breaker.reset()
            
        except Exception as e:
            logging.error(f"Failed to initialize RabbitMQ connection: {e}")
            self.circuit_breaker.record_failure()
            raise
    
    async def publish_batch(self, messages: List[str]) -> bool:
        """Publish a batch of messages"""
        if self.circuit_breaker.is_open():
            logging.warning("Circuit breaker is open, skipping publish")
            return False
        
        try:
            for message in messages:
                self.channel.basic_publish(
                    exchange=self.config['exchange'],
                    routing_key=self.config['routing_key'],
                    body=message,
                    properties=pika.BasicProperties(
                        delivery_mode=2,  # Make message persistent
                        timestamp=int(time.time())
                    )
                )
            
            self.circuit_breaker.record_success()
            return True
            
        except Exception as e:
            logging.error(f"Failed to publish batch: {e}")
            self.circuit_breaker.record_failure()
            
            # Attempt to reconnect
            try:
                await self.initialize()
            except:
                pass
            
            return False
    
    async def close(self):
        """Close connection"""
        try:
            if self.channel:
                self.channel.close()
            if self.connection:
                self.connection.close()
        except Exception as e:
            logging.error(f"Error closing connection: {e}")

class CircuitBreaker:
    def __init__(self, failure_threshold: int = 5, recovery_timeout: int = 60):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.failure_count = 0
        self.last_failure_time = None
        self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN
    
    def record_success(self):
        """Record a successful operation"""
        self.failure_count = 0
        self.state = "CLOSED"
    
    def record_failure(self):
        """Record a failed operation"""
        self.failure_count += 1
        self.last_failure_time = time.time()
        
        if self.failure_count >= self.failure_threshold:
            self.state = "OPEN"
    
    def is_open(self) -> bool:
        """Check if circuit breaker is open"""
        if self.state == "CLOSED":
            return False
        
        if self.state == "OPEN":
            # Check if we should move to half-open
            if (time.time() - self.last_failure_time) > self.recovery_timeout:
                self.state = "HALF_OPEN"
                return False
            return True
        
        return False  # HALF_OPEN
    
    def reset(self):
        """Reset circuit breaker"""
        self.failure_count = 0
        self.last_failure_time = None
        self.state = "CLOSED"
EOF

# Health Monitor
cat > src/producer/health_monitor.py << 'EOF'
import time
from typing import Dict, Any
from collections import deque
import asyncio

class HealthMonitor:
    def __init__(self):
        self.logs_received = 0
        self.logs_published = 0
        self.logs_failed = 0
        self.batch_count = 0
        self.start_time = time.time()
        
        # Sliding window for metrics (last 60 seconds)
        self.recent_logs = deque(maxlen=60)
        self.recent_batches = deque(maxlen=60)
        
    def record_log_received(self):
        """Record a log received"""
        self.logs_received += 1
        current_time = int(time.time())
        self.recent_logs.append(current_time)
    
    def record_batch_published(self, log_count: int, duration: float):
        """Record a successful batch publication"""
        self.logs_published += log_count
        self.batch_count += 1
        current_time = int(time.time())
        self.recent_batches.append({
            'timestamp': current_time,
            'log_count': log_count,
            'duration': duration
        })
    
    def record_batch_failed(self, log_count: int):
        """Record a failed batch"""
        self.logs_failed += log_count
    
    async def get_health_status(self) -> Dict[str, Any]:
        """Get current health status"""
        uptime = time.time() - self.start_time
        
        # Calculate recent throughput
        current_time = int(time.time())
        recent_log_count = sum(1 for t in self.recent_logs if current_time - t <= 60)
        recent_batch_count = sum(1 for b in self.recent_batches if current_time - b['timestamp'] <= 60)
        
        # Health determination
        healthy = (
            self.logs_failed / max(self.logs_received, 1) < 0.05 and  # Less than 5% failure rate
            recent_log_count > 0 if uptime > 60 else True  # Has recent activity if running > 1 min
        )
        
        return {
            'healthy': healthy,
            'uptime_seconds': uptime,
            'logs_received': self.logs_received,
            'logs_published': self.logs_published,
            'logs_failed': self.logs_failed,
            'recent_logs_per_minute': recent_log_count,
            'recent_batches_per_minute': recent_batch_count,
            'failure_rate': self.logs_failed / max(self.logs_received, 1)
        }
    
    async def get_metrics(self) -> Dict[str, Any]:
        """Get detailed metrics"""
        health_status = await self.get_health_status()
        
        # Calculate average batch metrics
        recent_batches = [b for b in self.recent_batches if time.time() - b['timestamp'] <= 60]
        avg_batch_size = sum(b['log_count'] for b in recent_batches) / max(len(recent_batches), 1)
        avg_batch_duration = sum(b['duration'] for b in recent_batches) / max(len(recent_batches), 1)
        
        return {
            **health_status,
            'average_batch_size': avg_batch_size,
            'average_batch_duration_ms': avg_batch_duration * 1000,
            'total_batches': self.batch_count
        }
EOF

# Log Entry Model
cat > src/models/log_entry.py << 'EOF'
import json
import time
from datetime import datetime
from typing import Dict, Any, Optional

class LogEntry:
    def __init__(self, level: str, message: str, source: str, 
                 timestamp: Optional[float] = None, **kwargs):
        self.level = level.upper()
        self.message = message
        self.source = source
        self.timestamp = timestamp or time.time()
        self.metadata = kwargs
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'LogEntry':
        """Create LogEntry from dictionary"""
        level = data.get('level', 'INFO')
        message = data.get('message', '')
        source = data.get('source', 'unknown')
        timestamp = data.get('timestamp')
        
        # Extract metadata (any additional fields)
        metadata = {k: v for k, v in data.items() 
                   if k not in ['level', 'message', 'source', 'timestamp']}
        
        return cls(level, message, source, timestamp, **metadata)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            'level': self.level,
            'message': self.message,
            'source': self.source,
            'timestamp': self.timestamp,
            'formatted_time': datetime.fromtimestamp(self.timestamp).isoformat(),
            **self.metadata
        }
    
    def to_json(self) -> str:
        """Convert to JSON string"""
        return json.dumps(self.to_dict())
EOF

# Requirements file
cat > requirements.txt << 'EOF'
pika==1.3.2
aiohttp==3.9.5
pytest==8.2.1
pytest-asyncio==0.23.6
requests==2.31.0
uvloop==0.19.0
EOF

# Configuration file
cat > config/config.json << 'EOF'
{
    "rabbitmq": {
        "host": "localhost",
        "port": 5672,
        "exchange": "logs_exchange",
        "routing_key": "application.logs",
        "username": "guest",
        "password": "guest"
    },
    "producer": {
        "batch_size": 50,
        "batch_timeout_ms": 100,
        "port": 8080,
        "log_level": "INFO"
    },
    "health": {
        "check_interval_seconds": 30,
        "failure_threshold": 5
    }
}
EOF

# Test files
cat > tests/test_producer.py << 'EOF'
import pytest
import asyncio
import json
from unittest.mock import AsyncMock, MagicMock
import sys
import os

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from producer.producer import LogProducer
from models.log_entry import LogEntry

@pytest.mark.asyncio
async def test_log_entry_creation():
    """Test LogEntry creation and serialization"""
    log_data = {
        'level': 'INFO',
        'message': 'Test message',
        'source': 'test_app',
        'user_id': 12345
    }
    
    entry = LogEntry.from_dict(log_data)
    assert entry.level == 'INFO'
    assert entry.message == 'Test message'
    assert entry.source == 'test_app'
    assert entry.metadata['user_id'] == 12345
    
    # Test JSON serialization
    json_str = entry.to_json()
    parsed = json.loads(json_str)
    assert parsed['level'] == 'INFO'
    assert 'formatted_time' in parsed

@pytest.mark.asyncio
async def test_batch_manager():
    """Test batch manager functionality"""
    from producer.batch_manager import BatchManager
    
    batch_manager = BatchManager(max_size=3, max_wait_ms=50)
    
    # Add logs
    for i in range(2):
        log = LogEntry('INFO', f'Message {i}', 'test')
        await batch_manager.add_log(log)
    
    # Should not have a batch yet (size < 3)
    batch = await batch_manager.get_batch()
    assert batch is None
    
    # Add one more to trigger size-based flush
    log = LogEntry('INFO', 'Message 2', 'test')
    await batch_manager.add_log(log)
    
    # Should have a batch now
    batch = await batch_manager.get_batch()
    assert batch is not None
    assert len(batch) == 3

@pytest.mark.asyncio
async def test_health_monitor():
    """Test health monitoring"""
    from producer.health_monitor import HealthMonitor
    
    monitor = HealthMonitor()
    
    # Record some activity
    monitor.record_log_received()
    monitor.record_batch_published(5, 0.1)
    
    status = await monitor.get_health_status()
    assert status['healthy'] is True
    assert status['logs_received'] == 1
    assert status['logs_published'] == 5
    
    metrics = await monitor.get_metrics()
    assert 'average_batch_size' in metrics

def test_circuit_breaker():
    """Test circuit breaker functionality"""
    from producer.connection_pool import CircuitBreaker
    
    cb = CircuitBreaker(failure_threshold=3, recovery_timeout=1)
    
    # Initially closed
    assert not cb.is_open()
    
    # Record failures
    for _ in range(3):
        cb.record_failure()
    
    # Should be open now
    assert cb.is_open()
    
    # Record success should reset
    cb.record_success()
    assert not cb.is_open()

if __name__ == "__main__":
    pytest.main([__file__])
EOF

# Load test script
cat > tests/load_test.py << 'EOF'
import asyncio
import aiohttp
import json
import time
import statistics
from typing import List

class LoadTester:
    def __init__(self, base_url: str = "http://localhost:8080"):
        self.base_url = base_url
        self.response_times = []
        self.errors = 0
        
    async def send_log(self, session: aiohttp.ClientSession, log_data: dict):
        """Send a single log and measure response time"""
        start_time = time.time()
        try:
            async with session.post(f"{self.base_url}/logs", json=log_data) as response:
                duration = time.time() - start_time
                self.response_times.append(duration)
                
                if response.status != 200:
                    self.errors += 1
                    
        except Exception as e:
            self.errors += 1
            print(f"Error sending log: {e}")
    
    async def run_load_test(self, total_logs: int = 1000, concurrent_requests: int = 50):
        """Run load test with specified parameters"""
        print(f"Starting load test: {total_logs} logs, {concurrent_requests} concurrent requests")
        
        start_time = time.time()
        
        async with aiohttp.ClientSession() as session:
            # Create semaphore to limit concurrency
            semaphore = asyncio.Semaphore(concurrent_requests)
            
            async def bounded_send_log(i):
                async with semaphore:
                    log_data = {
                        'level': 'INFO',
                        'message': f'Load test message {i}',
                        'source': 'load_tester',
                        'request_id': i,
                        'timestamp': time.time()
                    }
                    await self.send_log(session, log_data)
            
            # Send all logs concurrently
            tasks = [bounded_send_log(i) for i in range(total_logs)]
            await asyncio.gather(*tasks)
        
        total_duration = time.time() - start_time
        
        # Calculate statistics
        avg_response_time = statistics.mean(self.response_times) if self.response_times else 0
        p95_response_time = statistics.quantiles(self.response_times, n=20)[18] if len(self.response_times) > 20 else 0
        throughput = total_logs / total_duration
        error_rate = self.errors / total_logs
        
        print(f"\n=== Load Test Results ===")
        print(f"Total logs sent: {total_logs}")
        print(f"Duration: {total_duration:.2f} seconds")
        print(f"Throughput: {throughput:.2f} logs/second")
        print(f"Average response time: {avg_response_time*1000:.2f} ms")
        print(f"95th percentile response time: {p95_response_time*1000:.2f} ms")
        print(f"Error rate: {error_rate*100:.2f}%")
        print(f"Errors: {self.errors}")
        
        return {
            'throughput': throughput,
            'avg_response_time': avg_response_time,
            'p95_response_time': p95_response_time,
            'error_rate': error_rate,
            'total_errors': self.errors
        }

async def main():
    tester = LoadTester()
    
    # Wait for service to be ready
    print("Waiting for service to be ready...")
    await asyncio.sleep(2)
    
    # Run load test
    results = await tester.run_load_test(total_logs=1000, concurrent_requests=50)
    
    # Verify requirements
    print(f"\n=== Requirement Verification ===")
    print(f"✓ Throughput > 1000 logs/sec: {results['throughput'] > 1000}")
    print(f"✓ Error rate < 1%: {results['error_rate'] < 0.01}")
    print(f"✓ P95 latency < 100ms: {results['p95_response_time'] < 0.1}")

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Docker files
cat > docker/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ src/
COPY config/ config/

# Set PYTHONPATH for module imports
ENV PYTHONPATH="/app/src:$PYTHONPATH"

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
CMD ["python", "-m", "producer.producer"]
EOF

cat > docker/docker-compose.yml << 'EOF'
version: '3.8'

services:
  rabbitmq:
    image: rabbitmq:3.12-management
    container_name: log_rabbitmq
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
      RABBITMQ_HOST: rabbitmq
      RABBITMQ_PORT: 5672
      PYTHONPATH: /app/src
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

  log_producer:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    container_name: log_producer
    ports:
      - "8080:8080"
    depends_on:
      rabbitmq:
        condition: service_healthy
    environment:
      RABBITMQ_HOST: rabbitmq
      RABBITMQ_PORT: 5672
    volumes:
      - ../config:/app/config:ro
    restart: unless-stopped

volumes:
  rabbitmq_data:
EOF

# Build and test scripts
cat > scripts/build.sh << 'EOF'
#!/bin/bash
set -e

echo "🔨 Building Log Producer..."

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Run syntax checks
echo "🔍 Running syntax checks..."
python -m py_compile src/producer/*.py
python -m py_compile src/models/*.py

echo "✅ Build completed successfully!"
EOF

cat > scripts/test.sh << 'EOF'
#!/bin/bash
set -e

echo "🧪 Running tests..."

# Set PYTHONPATH for imports
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Unit tests
echo "Running unit tests..."
python -m pytest tests/test_producer.py -v

echo "✅ All tests passed!"
EOF

cat > scripts/run_local.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Log Producer locally..."

# Set PYTHONPATH
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Check if RabbitMQ is running
if ! nc -z localhost 5672; then
    echo "❌ RabbitMQ is not running on localhost:5672"
    echo "Please start RabbitMQ first:"
    echo "  docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3.12-management"
    exit 1
fi

echo "✅ RabbitMQ is running"

# Start the producer
echo "Starting producer service..."
cd src && python -m producer.producer
EOF

cat > scripts/run_docker.sh << 'EOF'
#!/bin/bash
set -e

echo "🐳 Starting with Docker..."

cd docker
docker-compose up --build
EOF

cat > scripts/verify.sh << 'EOF'
#!/bin/bash
set -e

echo "🔍 Verifying Log Producer..."

# Wait for service to start
echo "Waiting for service to start..."
sleep 5

# Check health endpoint
echo "Checking health endpoint..."
response=$(curl -s http://localhost:8080/health)
echo "Health response: $response"

# Send test logs
echo "Sending test logs..."
for i in {1..10}; do
    curl -s -X POST http://localhost:8080/logs \
        -H "Content-Type: application/json" \
        -d "{\"level\":\"INFO\",\"message\":\"Test log $i\",\"source\":\"test\"}"
done

# Check metrics
echo "Checking metrics..."
metrics=$(curl -s http://localhost:8080/metrics)
echo "Metrics: $metrics"

# Run load test
echo "Running load test..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
python tests/load_test.py

echo "✅ Verification completed!"
EOF

# Make scripts executable
chmod +x scripts/*.sh

echo "📚 Creating documentation..."
cat > README.md << 'EOF'
# Day 32: Log Producer Implementation

A high-performance, resilient log producer for distributed message queues.

## Features

- **Intelligent Batching**: Combines time-based and size-based batching
- **Circuit Breaker**: Handles RabbitMQ failures gracefully  
- **Health Monitoring**: Comprehensive metrics and health checks
- **Async Processing**: Non-blocking log processing
- **Production Ready**: Proper error handling and observability

## Quick Start

### Local Development
```bash
# 1. Start RabbitMQ
docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3.12-management

# 2. Install dependencies
pip install -r requirements.txt

# 3. Run producer
./scripts/run_local.sh
```

### Docker Deployment
```bash
./scripts/run_docker.sh
```

## Testing

```bash
# Unit tests
./scripts/test.sh

# Load testing
python tests/load_test.py

# Full verification
./scripts/verify.sh
```

## API Endpoints

- `POST /logs` - Submit log entries
- `GET /health` - Health check
- `GET /metrics` - Detailed metrics

## Configuration

Edit `config/config.json` to customize:
- Batch sizes and timeouts
- RabbitMQ connection settings
- Health check parameters

## Architecture

The producer uses a multi-layered architecture:
1. **HTTP API**: Receives log submissions
2. **Batch Manager**: Intelligently groups logs
3. **Connection Pool**: Manages RabbitMQ connections with resilience
4. **Health Monitor**: Tracks performance and failures

## Performance Targets

- **Throughput**: 1000+ logs/second
- **Latency**: <100ms P95
- **Reliability**: 99.9% delivery guarantee
- **Availability**: Graceful degradation during outages
EOF

echo "🧪 Running build and tests..."

# Install dependencies
pip install -r requirements.txt

# Set PYTHONPATH for proper imports
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Run build
./scripts/build.sh

# Run tests
./scripts/test.sh

echo ""
echo "✅ Project setup completed successfully!"
echo ""
echo "🎯 Next Steps:"
echo "1. Start RabbitMQ: docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3.12-management"
echo "2. Run producer: ./scripts/run_local.sh"
echo "3. Verify: ./scripts/verify.sh"
echo "4. Load test: python tests/load_test.py"
echo ""
echo "📊 Docker deployment: ./scripts/run_docker.sh"
echo "🔍 RabbitMQ Management: http://localhost:15672 (guest/guest)"
echo "📈 Producer Health: http://localhost:8080/health"
echo ""
echo "🏆 Assignment: Achieve 1000 logs/sec with 99.9% delivery guarantee!"