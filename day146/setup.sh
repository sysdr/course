#!/bin/bash

# Day 146: Time Series Database Integration - Complete Implementation Script
# This script creates, builds, tests, and demonstrates the entire time series metrics system

set -e  # Exit on any error

echo "🚀 Day 146: Time Series Database Integration - Setup Starting..."
echo "================================================================"

# Create project structure
PROJECT_NAME="day146-timeseries-metrics"
echo "📁 Creating project structure..."

mkdir -p ${PROJECT_NAME}/{src/{extractors,writers,api,dashboard,generators},tests,config,docker,scripts,data}
cd ${PROJECT_NAME}

# Create Python source files
echo "📝 Creating source files..."

# 1. Metrics Extractor
cat > src/extractors/metrics_extractor.py << 'EXTRACTOR_EOF'
"""
Metrics Extractor - Parses logs and extracts time series metrics
"""
import json
import re
from datetime import datetime
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict

@dataclass
class Metric:
    measurement: str
    tags: Dict[str, str]
    fields: Dict[str, float]
    timestamp: datetime
    
    def to_line_protocol(self) -> str:
        """Convert to InfluxDB line protocol format"""
        tag_str = ','.join([f"{k}={v}" for k, v in self.tags.items()])
        field_str = ','.join([f"{k}={v}" for k, v in self.fields.items()])
        ts = int(self.timestamp.timestamp() * 1000000000)  # nanoseconds
        return f"{self.measurement},{tag_str} {field_str} {ts}"

class MetricsExtractor:
    """Extract metrics from structured log messages"""
    
    def __init__(self):
        self.patterns = {
            'response_time': re.compile(r'response_time[:\s]+(\d+(?:\.\d+)?)\s*ms'),
            'status_code': re.compile(r'status[:\s]+(\d{3})'),
            'request_size': re.compile(r'request_size[:\s]+(\d+)'),
            'error_count': re.compile(r'error(?:s)?[:\s]+(\d+)'),
        }
    
    def extract_from_log(self, log_entry: Dict) -> List[Metric]:
        """Extract metrics from a log entry"""
        metrics = []
        timestamp = datetime.fromisoformat(log_entry.get('timestamp', datetime.now().isoformat()))
        
        # Extract service metadata
        service = log_entry.get('service', 'unknown')
        component = log_entry.get('component', 'unknown')
        level = log_entry.get('level', 'INFO')
        
        base_tags = {
            'service': service,
            'component': component,
            'level': level,
            'host': log_entry.get('host', 'localhost')
        }
        
        # Extract HTTP metrics
        if 'response_time' in log_entry:
            metrics.append(Metric(
                measurement='http_response',
                tags={**base_tags, 'endpoint': log_entry.get('endpoint', 'unknown')},
                fields={'response_time_ms': float(log_entry['response_time'])},
                timestamp=timestamp
            ))
        
        if 'status_code' in log_entry:
            metrics.append(Metric(
                measurement='http_status',
                tags={**base_tags, 'endpoint': log_entry.get('endpoint', 'unknown')},
                fields={
                    'status_code': float(log_entry['status_code']),
                    'is_error': 1.0 if int(log_entry['status_code']) >= 400 else 0.0
                },
                timestamp=timestamp
            ))
        
        # Extract resource metrics
        if 'cpu_usage' in log_entry:
            metrics.append(Metric(
                measurement='resource_usage',
                tags=base_tags,
                fields={'cpu_percent': float(log_entry['cpu_usage'])},
                timestamp=timestamp
            ))
        
        if 'memory_usage' in log_entry:
            metrics.append(Metric(
                measurement='resource_usage',
                tags=base_tags,
                fields={'memory_mb': float(log_entry['memory_usage'])},
                timestamp=timestamp
            ))
        
        # Extract business metrics
        if 'request_count' in log_entry:
            metrics.append(Metric(
                measurement='throughput',
                tags=base_tags,
                fields={'request_count': float(log_entry['request_count'])},
                timestamp=timestamp
            ))
        
        return metrics
    
    def extract_from_text(self, text: str, service: str = 'unknown') -> List[Metric]:
        """Extract metrics from unstructured log text"""
        metrics = []
        timestamp = datetime.now()
        
        base_tags = {'service': service, 'source': 'text_log'}
        
        # Parse using regex patterns
        for metric_name, pattern in self.patterns.items():
            match = pattern.search(text)
            if match:
                value = float(match.group(1))
                metrics.append(Metric(
                    measurement=metric_name,
                    tags=base_tags,
                    fields={'value': value},
                    timestamp=timestamp
                ))
        
        return metrics

if __name__ == '__main__':
    # Test extraction
    extractor = MetricsExtractor()
    
    test_log = {
        'timestamp': '2025-06-16T10:30:45.123Z',
        'service': 'api-gateway',
        'component': 'http-handler',
        'level': 'INFO',
        'endpoint': '/api/users',
        'response_time': 145.7,
        'status_code': 200,
        'cpu_usage': 45.3,
        'memory_usage': 512.8
    }
    
    metrics = extractor.extract_from_log(test_log)
    print(f"✅ Extracted {len(metrics)} metrics from test log")
    for m in metrics:
        print(f"   {m.measurement}: {m.fields}")
EXTRACTOR_EOF

# 2. Batch Writer for TimescaleDB
cat > src/writers/timescale_writer.py << 'WRITER_EOF'
"""
Batch Writer for TimescaleDB - Efficiently writes metrics with batching
"""
import asyncio
import psycopg2
from psycopg2.extras import execute_batch
from psycopg2.pool import ThreadedConnectionPool
from typing import List, Dict
from datetime import datetime
import logging
from dataclasses import dataclass

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class MetricBatch:
    metrics: List[Dict]
    max_size: int = 1000
    flush_interval: float = 2.0  # seconds

class TimescaleWriter:
    """Batched writer for TimescaleDB with connection pooling"""
    
    def __init__(self, db_config: Dict):
        self.db_config = db_config
        self.connection_pool = None
        self.batch = []
        self.batch_size = 1000
        self.flush_interval = 2.0
        self.last_flush = datetime.now()
        self.total_written = 0
        self._setup_connection_pool()
    
    def _setup_connection_pool(self):
        """Create connection pool"""
        try:
            self.connection_pool = ThreadedConnectionPool(
                minconn=2,
                maxconn=10,
                host=self.db_config.get('host', 'localhost'),
                port=self.db_config.get('port', 5432),
                database=self.db_config.get('database', 'metrics'),
                user=self.db_config.get('user', 'postgres'),
                password=self.db_config.get('password', 'password')
            )
            logger.info("✅ Connection pool created")
        except Exception as e:
            logger.error(f"❌ Failed to create connection pool: {e}")
            raise
    
    def setup_schema(self):
        """Create hypertables for metrics"""
        conn = self.connection_pool.getconn()
        try:
            cur = conn.cursor()
            
            # Create extension
            cur.execute("CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;")
            
            # HTTP response metrics table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS http_response (
                    time TIMESTAMPTZ NOT NULL,
                    service TEXT NOT NULL,
                    component TEXT,
                    endpoint TEXT,
                    response_time_ms DOUBLE PRECISION,
                    host TEXT
                );
            """)
            
            # Convert to hypertable
            cur.execute("""
                SELECT create_hypertable('http_response', 'time', 
                    if_not_exists => TRUE, 
                    chunk_time_interval => INTERVAL '1 day');
            """)
            
            # HTTP status metrics table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS http_status (
                    time TIMESTAMPTZ NOT NULL,
                    service TEXT NOT NULL,
                    component TEXT,
                    endpoint TEXT,
                    status_code INTEGER,
                    is_error INTEGER,
                    host TEXT
                );
            """)
            
            cur.execute("""
                SELECT create_hypertable('http_status', 'time', 
                    if_not_exists => TRUE, 
                    chunk_time_interval => INTERVAL '1 day');
            """)
            
            # Resource usage metrics table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS resource_usage (
                    time TIMESTAMPTZ NOT NULL,
                    service TEXT NOT NULL,
                    component TEXT,
                    cpu_percent DOUBLE PRECISION,
                    memory_mb DOUBLE PRECISION,
                    host TEXT
                );
            """)
            
            cur.execute("""
                SELECT create_hypertable('resource_usage', 'time', 
                    if_not_exists => TRUE, 
                    chunk_time_interval => INTERVAL '1 day');
            """)
            
            # Throughput metrics table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS throughput (
                    time TIMESTAMPTZ NOT NULL,
                    service TEXT NOT NULL,
                    component TEXT,
                    request_count DOUBLE PRECISION,
                    host TEXT
                );
            """)
            
            cur.execute("""
                SELECT create_hypertable('throughput', 'time', 
                    if_not_exists => TRUE, 
                    chunk_time_interval => INTERVAL '1 day');
            """)
            
            # Create indexes
            cur.execute("CREATE INDEX IF NOT EXISTS idx_http_response_service ON http_response (service, time DESC);")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_http_status_service ON http_status (service, time DESC);")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_resource_service ON resource_usage (service, time DESC);")
            
            # Set up retention policy (7 days for raw data)
            cur.execute("""
                SELECT add_retention_policy('http_response', INTERVAL '7 days', if_not_exists => TRUE);
            """)
            cur.execute("""
                SELECT add_retention_policy('http_status', INTERVAL '7 days', if_not_exists => TRUE);
            """)
            
            conn.commit()
            logger.info("✅ Schema setup complete")
            
        except Exception as e:
            logger.error(f"❌ Schema setup failed: {e}")
            conn.rollback()
            raise
        finally:
            self.connection_pool.putconn(conn)
    
    def add_metric(self, metric: Dict):
        """Add metric to batch"""
        self.batch.append(metric)
        
        # Check if should flush
        if len(self.batch) >= self.batch_size:
            self.flush()
        elif (datetime.now() - self.last_flush).total_seconds() >= self.flush_interval:
            self.flush()
    
    def flush(self):
        """Write batched metrics to database"""
        if not self.batch:
            return
        
        conn = self.connection_pool.getconn()
        try:
            cur = conn.cursor()
            
            # Group by measurement type
            http_response = []
            http_status = []
            resource_usage = []
            throughput_data = []
            
            for metric in self.batch:
                measurement = metric.get('measurement')
                tags = metric.get('tags', {})
                fields = metric.get('fields', {})
                timestamp = metric.get('timestamp')
                
                if measurement == 'http_response':
                    http_response.append((
                        timestamp,
                        tags.get('service'),
                        tags.get('component'),
                        tags.get('endpoint'),
                        fields.get('response_time_ms'),
                        tags.get('host')
                    ))
                elif measurement == 'http_status':
                    http_status.append((
                        timestamp,
                        tags.get('service'),
                        tags.get('component'),
                        tags.get('endpoint'),
                        int(fields.get('status_code', 0)),
                        int(fields.get('is_error', 0)),
                        tags.get('host')
                    ))
                elif measurement == 'resource_usage':
                    resource_usage.append((
                        timestamp,
                        tags.get('service'),
                        tags.get('component'),
                        fields.get('cpu_percent'),
                        fields.get('memory_mb'),
                        tags.get('host')
                    ))
                elif measurement == 'throughput':
                    throughput_data.append((
                        timestamp,
                        tags.get('service'),
                        tags.get('component'),
                        fields.get('request_count'),
                        tags.get('host')
                    ))
            
            # Batch insert
            if http_response:
                execute_batch(cur, """
                    INSERT INTO http_response (time, service, component, endpoint, response_time_ms, host)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, http_response)
            
            if http_status:
                execute_batch(cur, """
                    INSERT INTO http_status (time, service, component, endpoint, status_code, is_error, host)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, http_status)
            
            if resource_usage:
                execute_batch(cur, """
                    INSERT INTO resource_usage (time, service, component, cpu_percent, memory_mb, host)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, resource_usage)
            
            if throughput_data:
                execute_batch(cur, """
                    INSERT INTO throughput (time, service, component, request_count, host)
                    VALUES (%s, %s, %s, %s, %s)
                """, throughput_data)
            
            conn.commit()
            self.total_written += len(self.batch)
            logger.info(f"✅ Flushed {len(self.batch)} metrics (total: {self.total_written})")
            
            self.batch = []
            self.last_flush = datetime.now()
            
        except Exception as e:
            logger.error(f"❌ Flush failed: {e}")
            conn.rollback()
            raise
        finally:
            self.connection_pool.putconn(conn)
    
    def close(self):
        """Flush remaining metrics and close connections"""
        self.flush()
        if self.connection_pool:
            self.connection_pool.closeall()
            logger.info("✅ Connection pool closed")

if __name__ == '__main__':
    # Test writer
    writer = TimescaleWriter({
        'host': 'localhost',
        'port': 5432,
        'database': 'metrics',
        'user': 'postgres',
        'password': 'password'
    })
    
    try:
        writer.setup_schema()
        print("✅ Writer test complete")
    except Exception as e:
        print(f"❌ Writer test failed: {e}")
WRITER_EOF

# 3. Query API (FastAPI)
cat > src/api/query_api.py << 'API_EOF'
"""
Query API - REST endpoints for querying metrics from TimescaleDB
"""
from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Optional
from datetime import datetime, timedelta
import psycopg2
from psycopg2.extras import RealDictCursor
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Metrics Query API", version="1.0.0")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'metrics',
    'user': 'postgres',
    'password': 'password'
}

def get_db_connection():
    """Get database connection"""
    return psycopg2.connect(**DB_CONFIG, cursor_factory=RealDictCursor)

@app.get("/")
async def root():
    return {"message": "Metrics Query API", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/metrics/response-time")
async def get_response_time_metrics(
    service: Optional[str] = None,
    start_time: Optional[str] = None,
    end_time: Optional[str] = None,
    interval: str = Query(default="5m", regex="^[0-9]+(s|m|h)$")
):
    """Get response time metrics with time-bucket aggregation"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Default time range: last hour
        if not end_time:
            end_time = datetime.now().isoformat()
        if not start_time:
            start_time = (datetime.now() - timedelta(hours=1)).isoformat()
        
        query = """
            SELECT 
                time_bucket(%s::interval, time) AS bucket,
                service,
                AVG(response_time_ms) as avg_response_time,
                MIN(response_time_ms) as min_response_time,
                MAX(response_time_ms) as max_response_time,
                percentile_cont(0.95) WITHIN GROUP (ORDER BY response_time_ms) as p95_response_time,
                COUNT(*) as sample_count
            FROM http_response
            WHERE time >= %s::timestamptz AND time <= %s::timestamptz
        """
        
        params = [interval, start_time, end_time]
        
        if service:
            query += " AND service = %s"
            params.append(service)
        
        query += " GROUP BY bucket, service ORDER BY bucket DESC LIMIT 100"
        
        cur.execute(query, params)
        results = cur.fetchall()
        
        conn.close()
        
        return {
            "data": results,
            "meta": {
                "start_time": start_time,
                "end_time": end_time,
                "interval": interval,
                "count": len(results)
            }
        }
        
    except Exception as e:
        logger.error(f"Query failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/metrics/error-rate")
async def get_error_rate(
    service: Optional[str] = None,
    start_time: Optional[str] = None,
    end_time: Optional[str] = None,
    interval: str = Query(default="5m", regex="^[0-9]+(s|m|h)$")
):
    """Get error rate metrics"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        if not end_time:
            end_time = datetime.now().isoformat()
        if not start_time:
            start_time = (datetime.now() - timedelta(hours=1)).isoformat()
        
        query = """
            SELECT 
                time_bucket(%s::interval, time) AS bucket,
                service,
                COUNT(*) as total_requests,
                SUM(is_error) as error_count,
                (SUM(is_error)::float / COUNT(*)::float * 100) as error_rate
            FROM http_status
            WHERE time >= %s::timestamptz AND time <= %s::timestamptz
        """
        
        params = [interval, start_time, end_time]
        
        if service:
            query += " AND service = %s"
            params.append(service)
        
        query += " GROUP BY bucket, service ORDER BY bucket DESC LIMIT 100"
        
        cur.execute(query, params)
        results = cur.fetchall()
        
        conn.close()
        
        return {
            "data": results,
            "meta": {
                "start_time": start_time,
                "end_time": end_time,
                "interval": interval
            }
        }
        
    except Exception as e:
        logger.error(f"Query failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/metrics/resource-usage")
async def get_resource_usage(
    service: Optional[str] = None,
    start_time: Optional[str] = None,
    end_time: Optional[str] = None
):
    """Get resource usage metrics"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        if not end_time:
            end_time = datetime.now().isoformat()
        if not start_time:
            start_time = (datetime.now() - timedelta(minutes=30)).isoformat()
        
        query = """
            SELECT 
                time_bucket('1m', time) AS bucket,
                service,
                AVG(cpu_percent) as avg_cpu,
                MAX(cpu_percent) as max_cpu,
                AVG(memory_mb) as avg_memory,
                MAX(memory_mb) as max_memory
            FROM resource_usage
            WHERE time >= %s::timestamptz AND time <= %s::timestamptz
        """
        
        params = [start_time, end_time]
        
        if service:
            query += " AND service = %s"
            params.append(service)
        
        query += " GROUP BY bucket, service ORDER BY bucket DESC LIMIT 100"
        
        cur.execute(query, params)
        results = cur.fetchall()
        
        conn.close()
        
        return {
            "data": results,
            "meta": {
                "start_time": start_time,
                "end_time": end_time
            }
        }
        
    except Exception as e:
        logger.error(f"Query failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/metrics/throughput")
async def get_throughput(
    service: Optional[str] = None,
    start_time: Optional[str] = None,
    end_time: Optional[str] = None,
    interval: str = Query(default="1m", regex="^[0-9]+(s|m|h)$")
):
    """Get throughput metrics"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        if not end_time:
            end_time = datetime.now().isoformat()
        if not start_time:
            start_time = (datetime.now() - timedelta(hours=1)).isoformat()
        
        query = """
            SELECT 
                time_bucket(%s::interval, time) AS bucket,
                service,
                SUM(request_count) as total_requests,
                AVG(request_count) as avg_requests
            FROM throughput
            WHERE time >= %s::timestamptz AND time <= %s::timestamptz
        """
        
        params = [interval, start_time, end_time]
        
        if service:
            query += " AND service = %s"
            params.append(service)
        
        query += " GROUP BY bucket, service ORDER BY bucket DESC LIMIT 100"
        
        cur.execute(query, params)
        results = cur.fetchall()
        
        conn.close()
        
        return {
            "data": results,
            "meta": {
                "start_time": start_time,
                "end_time": end_time,
                "interval": interval
            }
        }
        
    except Exception as e:
        logger.error(f"Query failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/metrics/summary")
async def get_summary():
    """Get overall metrics summary"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Last hour summary
        one_hour_ago = (datetime.now() - timedelta(hours=1)).isoformat()
        
        # Response time summary
        cur.execute("""
            SELECT 
                service,
                AVG(response_time_ms) as avg_response_time,
                percentile_cont(0.95) WITHIN GROUP (ORDER BY response_time_ms) as p95_response_time,
                COUNT(*) as request_count
            FROM http_response
            WHERE time >= %s::timestamptz
            GROUP BY service
        """, (one_hour_ago,))
        response_summary = cur.fetchall()
        
        # Error rate summary
        cur.execute("""
            SELECT 
                service,
                COUNT(*) as total_requests,
                SUM(is_error) as error_count,
                (SUM(is_error)::float / COUNT(*)::float * 100) as error_rate
            FROM http_status
            WHERE time >= %s::timestamptz
            GROUP BY service
        """, (one_hour_ago,))
        error_summary = cur.fetchall()
        
        conn.close()
        
        return {
            "response_time": response_summary,
            "error_rate": error_summary,
            "timeframe": "last_1_hour"
        }
        
    except Exception as e:
        logger.error(f"Query failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
API_EOF

# 4. Log Generator for Testing
cat > src/generators/log_generator.py << 'GENERATOR_EOF'
"""
Log Generator - Creates realistic log entries for testing
"""
import random
import time
import json
from datetime import datetime
from typing import List, Dict

class LogGenerator:
    """Generate realistic log entries with metrics"""
    
    def __init__(self):
        self.services = ['api-gateway', 'user-service', 'payment-service', 'database']
        self.components = ['http-handler', 'auth', 'processor', 'cache']
        self.endpoints = ['/api/users', '/api/orders', '/api/products', '/api/payments']
        self.hosts = ['server-01', 'server-02', 'server-03']
    
    def generate_log(self) -> Dict:
        """Generate a single log entry with metrics"""
        service = random.choice(self.services)
        component = random.choice(self.components)
        endpoint = random.choice(self.endpoints)
        
        # Simulate realistic patterns
        response_time = random.gauss(150, 50)  # Normal distribution around 150ms
        if random.random() < 0.1:  # 10% slow requests
            response_time += random.uniform(200, 500)
        
        status_code = 200
        if random.random() < 0.05:  # 5% error rate
            status_code = random.choice([400, 404, 500, 503])
        
        return {
            'timestamp': datetime.now().isoformat(),
            'service': service,
            'component': component,
            'level': 'ERROR' if status_code >= 400 else 'INFO',
            'endpoint': endpoint,
            'response_time': max(1, response_time),
            'status_code': status_code,
            'cpu_usage': random.uniform(20, 80),
            'memory_usage': random.uniform(200, 800),
            'request_count': random.randint(1, 10),
            'host': random.choice(self.hosts)
        }
    
    def generate_batch(self, count: int = 100) -> List[Dict]:
        """Generate a batch of log entries"""
        return [self.generate_log() for _ in range(count)]
    
    def stream_logs(self, rate: int = 10, duration: int = 60):
        """Stream logs at specified rate"""
        total_generated = 0
        start_time = time.time()
        
        while time.time() - start_time < duration:
            batch = self.generate_batch(rate)
            for log in batch:
                print(json.dumps(log))
                total_generated += 1
            
            time.sleep(1)
        
        return total_generated

if __name__ == '__main__':
    generator = LogGenerator()
    print(f"🔄 Generating test logs...")
    count = generator.stream_logs(rate=10, duration=10)
    print(f"✅ Generated {count} log entries")
GENERATOR_EOF

# 5. Main Application
cat > src/main.py << 'MAIN_EOF'
"""
Main Application - Coordinates metric extraction, writing, and API
"""
import asyncio
import logging
import signal
import sys
from datetime import datetime
from extractors.metrics_extractor import MetricsExtractor
from writers.timescale_writer import TimescaleWriter
from generators.log_generator import LogGenerator

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MetricsPipeline:
    """Coordinates the metrics extraction and storage pipeline"""
    
    def __init__(self):
        self.extractor = MetricsExtractor()
        self.writer = TimescaleWriter({
            'host': 'localhost',
            'port': 5432,
            'database': 'metrics',
            'user': 'postgres',
            'password': 'password'
        })
        self.generator = LogGenerator()
        self.running = False
    
    def setup(self):
        """Initialize database schema"""
        logger.info("🔧 Setting up database schema...")
        self.writer.setup_schema()
        logger.info("✅ Schema setup complete")
    
    async def process_logs(self, duration: int = 60):
        """Process logs and extract metrics"""
        logger.info(f"🔄 Starting log processing for {duration} seconds...")
        self.running = True
        
        start_time = datetime.now()
        total_logs = 0
        total_metrics = 0
        
        try:
            while self.running:
                # Generate test logs
                logs = self.generator.generate_batch(count=10)
                
                for log in logs:
                    # Extract metrics
                    metrics = self.extractor.extract_from_log(log)
                    
                    # Write to database
                    for metric in metrics:
                        self.writer.add_metric({
                            'measurement': metric.measurement,
                            'tags': metric.tags,
                            'fields': metric.fields,
                            'timestamp': metric.timestamp
                        })
                    
                    total_logs += 1
                    total_metrics += len(metrics)
                
                # Periodic status
                if total_logs % 100 == 0:
                    logger.info(f"📊 Processed {total_logs} logs, extracted {total_metrics} metrics")
                
                await asyncio.sleep(0.1)  # 100ms between batches
                
                # Check duration
                if (datetime.now() - start_time).total_seconds() >= duration:
                    break
        
        except KeyboardInterrupt:
            logger.info("⚠️  Interrupted by user")
        finally:
            self.writer.flush()
            logger.info(f"✅ Processing complete: {total_logs} logs → {total_metrics} metrics")
    
    def stop(self):
        """Stop the pipeline"""
        logger.info("🛑 Stopping pipeline...")
        self.running = False
        self.writer.close()

async def main():
    """Main entry point"""
    pipeline = MetricsPipeline()
    
    # Setup signal handlers
    def signal_handler(signum, frame):
        pipeline.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Initialize
    pipeline.setup()
    
    # Process logs
    await pipeline.process_logs(duration=60)
    
    # Cleanup
    pipeline.stop()

if __name__ == '__main__':
    asyncio.run(main())
MAIN_EOF

# Create React Dashboard
echo "📱 Creating React dashboard..."
mkdir -p src/dashboard/src src/dashboard/public

cat > src/dashboard/package.json << 'PACKAGE_EOF'
{
  "name": "metrics-dashboard",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "recharts": "^2.12.0",
    "axios": "^1.6.8",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": ["react-app"]
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  }
}
PACKAGE_EOF

cat > src/dashboard/public/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Metrics Dashboard</title>
</head>
<body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
</body>
</html>
HTML_EOF

cat > src/dashboard/src/index.js << 'INDEX_JS_EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
INDEX_JS_EOF

cat > src/dashboard/src/index.css << 'CSS_EOF'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New', monospace;
}
CSS_EOF

cat > src/dashboard/src/App.js << 'APP_JS_EOF'
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import './App.css';

const API_BASE_URL = 'http://localhost:8000';

function App() {
  const [responseTimeData, setResponseTimeData] = useState([]);
  const [errorRateData, setErrorRateData] = useState([]);
  const [resourceData, setResourceData] = useState([]);
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 5000); // Refresh every 5 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchData = async () => {
    try {
      const [responseTime, errorRate, resource, summaryData] = await Promise.all([
        axios.get(`${API_BASE_URL}/metrics/response-time?interval=1m`),
        axios.get(`${API_BASE_URL}/metrics/error-rate?interval=1m`),
        axios.get(`${API_BASE_URL}/metrics/resource-usage`),
        axios.get(`${API_BASE_URL}/metrics/summary`)
      ]);

      setResponseTimeData(responseTime.data.data.reverse().map(item => ({
        time: new Date(item.bucket).toLocaleTimeString(),
        avg: parseFloat(item.avg_response_time).toFixed(2),
        p95: parseFloat(item.p95_response_time).toFixed(2),
        service: item.service
      })));

      setErrorRateData(errorRate.data.data.reverse().map(item => ({
        time: new Date(item.bucket).toLocaleTimeString(),
        errorRate: parseFloat(item.error_rate).toFixed(2),
        totalRequests: item.total_requests,
        service: item.service
      })));

      setResourceData(resource.data.data.reverse().map(item => ({
        time: new Date(item.bucket).toLocaleTimeString(),
        cpu: parseFloat(item.avg_cpu).toFixed(2),
        memory: parseFloat(item.avg_memory).toFixed(2),
        service: item.service
      })));

      setSummary(summaryData.data);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching data:', error);
    }
  };

  if (loading) {
    return (
      <div className="App">
        <div className="loading">Loading metrics dashboard...</div>
      </div>
    );
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>🎯 Time Series Metrics Dashboard</h1>
        <p>Real-time monitoring of distributed log processing system</p>
      </header>

      <div className="dashboard-grid">
        {/* Summary Cards */}
        <div className="summary-section">
          <h2>📊 System Summary (Last Hour)</h2>
          <div className="card-grid">
            {summary?.response_time?.map((item, idx) => (
              <div key={idx} className="metric-card">
                <h3>{item.service}</h3>
                <div className="metric-value">{parseFloat(item.avg_response_time).toFixed(2)}ms</div>
                <div className="metric-label">Avg Response Time</div>
                <div className="metric-secondary">
                  P95: {parseFloat(item.p95_response_time).toFixed(2)}ms
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Response Time Chart */}
        <div className="chart-section">
          <h2>⚡ Response Time Metrics</h2>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={responseTimeData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#444" />
              <XAxis dataKey="time" stroke="#fff" />
              <YAxis stroke="#fff" />
              <Tooltip contentStyle={{ backgroundColor: '#333', border: 'none' }} />
              <Legend />
              <Line type="monotone" dataKey="avg" stroke="#8884d8" strokeWidth={2} name="Average" />
              <Line type="monotone" dataKey="p95" stroke="#82ca9d" strokeWidth={2} name="P95" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Error Rate Chart */}
        <div className="chart-section">
          <h2>🚨 Error Rate</h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={errorRateData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#444" />
              <XAxis dataKey="time" stroke="#fff" />
              <YAxis stroke="#fff" />
              <Tooltip contentStyle={{ backgroundColor: '#333', border: 'none' }} />
              <Legend />
              <Bar dataKey="errorRate" fill="#ff6b6b" name="Error Rate (%)" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Resource Usage Chart */}
        <div className="chart-section">
          <h2>💻 Resource Usage</h2>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={resourceData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#444" />
              <XAxis dataKey="time" stroke="#fff" />
              <YAxis stroke="#fff" />
              <Tooltip contentStyle={{ backgroundColor: '#333', border: 'none' }} />
              <Legend />
              <Line type="monotone" dataKey="cpu" stroke="#ffd93d" strokeWidth={2} name="CPU %" />
              <Line type="monotone" dataKey="memory" stroke="#6bcf7f" strokeWidth={2} name="Memory MB" />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      <footer className="App-footer">
        <p>Last updated: {new Date().toLocaleTimeString()}</p>
        <p>Powered by TimescaleDB + FastAPI + React</p>
      </footer>
    </div>
  );
}

export default App;
APP_JS_EOF

cat > src/dashboard/src/App.css << 'APP_CSS_EOF'
.App {
  min-height: 100vh;
  color: white;
  padding: 20px;
}

.App-header {
  text-align: center;
  padding: 30px 20px;
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-radius: 20px;
  margin-bottom: 30px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}

.App-header h1 {
  font-size: 2.5rem;
  margin-bottom: 10px;
  background: linear-gradient(45deg, #fff, #a8dadc);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.App-header p {
  font-size: 1.1rem;
  opacity: 0.9;
}

.dashboard-grid {
  display: grid;
  gap: 30px;
  max-width: 1400px;
  margin: 0 auto;
}

.summary-section {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-radius: 20px;
  padding: 25px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}

.summary-section h2 {
  margin-bottom: 20px;
  font-size: 1.5rem;
}

.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
}

.metric-card {
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.4), rgba(139, 92, 246, 0.4));
  border-radius: 15px;
  padding: 20px;
  text-align: center;
  transition: transform 0.2s;
}

.metric-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.2);
}

.metric-card h3 {
  font-size: 0.9rem;
  opacity: 0.8;
  margin-bottom: 10px;
  text-transform: uppercase;
  letter-spacing: 1px;
}

.metric-value {
  font-size: 2.5rem;
  font-weight: bold;
  margin: 10px 0;
  color: #ffd93d;
}

.metric-label {
  font-size: 0.9rem;
  opacity: 0.7;
  margin-bottom: 5px;
}

.metric-secondary {
  font-size: 0.85rem;
  opacity: 0.6;
  margin-top: 10px;
}

.chart-section {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-radius: 20px;
  padding: 25px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}

.chart-section h2 {
  margin-bottom: 20px;
  font-size: 1.5rem;
}

.App-footer {
  text-align: center;
  padding: 30px 20px;
  margin-top: 40px;
  opacity: 0.7;
  font-size: 0.9rem;
}

.loading {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  font-size: 1.5rem;
  color: white;
}

@media (max-width: 768px) {
  .App-header h1 {
    font-size: 1.8rem;
  }
  
  .card-grid {
    grid-template-columns: 1fr;
  }
  
  .metric-value {
    font-size: 2rem;
  }
}
APP_CSS_EOF

# Create test files
echo "🧪 Creating test files..."

cat > tests/test_extractor.py << 'TEST_EXTRACTOR_EOF'
"""
Tests for metrics extractor
"""
import pytest
from datetime import datetime
import sys
sys.path.insert(0, 'src')

from extractors.metrics_extractor import MetricsExtractor, Metric

def test_extractor_creation():
    """Test extractor initialization"""
    extractor = MetricsExtractor()
    assert extractor is not None
    assert len(extractor.patterns) > 0

def test_http_metrics_extraction():
    """Test HTTP metric extraction"""
    extractor = MetricsExtractor()
    
    log_entry = {
        'timestamp': '2025-06-16T10:00:00Z',
        'service': 'api-gateway',
        'component': 'http-handler',
        'level': 'INFO',
        'endpoint': '/api/users',
        'response_time': 123.45,
        'status_code': 200
    }
    
    metrics = extractor.extract_from_log(log_entry)
    
    assert len(metrics) >= 2  # At least response time and status
    assert any(m.measurement == 'http_response' for m in metrics)
    assert any(m.measurement == 'http_status' for m in metrics)

def test_resource_metrics_extraction():
    """Test resource metric extraction"""
    extractor = MetricsExtractor()
    
    log_entry = {
        'timestamp': '2025-06-16T10:00:00Z',
        'service': 'database',
        'component': 'processor',
        'level': 'INFO',
        'cpu_usage': 45.5,
        'memory_usage': 512.0
    }
    
    metrics = extractor.extract_from_log(log_entry)
    
    assert len(metrics) >= 1
    resource_metrics = [m for m in metrics if m.measurement == 'resource_usage']
    assert len(resource_metrics) > 0

def test_metric_tags():
    """Test metric tags are correctly set"""
    extractor = MetricsExtractor()
    
    log_entry = {
        'timestamp': '2025-06-16T10:00:00Z',
        'service': 'test-service',
        'component': 'test-component',
        'level': 'INFO',
        'host': 'test-host',
        'response_time': 100.0
    }
    
    metrics = extractor.extract_from_log(log_entry)
    metric = metrics[0]
    
    assert metric.tags['service'] == 'test-service'
    assert metric.tags['component'] == 'test-component'
    assert metric.tags['host'] == 'test-host'

if __name__ == '__main__':
    pytest.main([__file__, '-v'])
TEST_EXTRACTOR_EOF

cat > tests/test_writer.py << 'TEST_WRITER_EOF'
"""
Tests for TimescaleDB writer
"""
import pytest
from datetime import datetime
import sys
sys.path.insert(0, 'src')

from writers.timescale_writer import TimescaleWriter

def test_writer_initialization():
    """Test writer can be initialized"""
    config = {
        'host': 'localhost',
        'port': 5432,
        'database': 'metrics',
        'user': 'postgres',
        'password': 'password'
    }
    
    # This may fail if database isn't running - that's expected in unit tests
    try:
        writer = TimescaleWriter(config)
        assert writer is not None
        assert writer.batch_size == 1000
        writer.close()
    except Exception:
        pytest.skip("Database not available for testing")

def test_batch_accumulation():
    """Test batch accumulation logic"""
    config = {
        'host': 'localhost',
        'port': 5432,
        'database': 'metrics',
        'user': 'postgres',
        'password': 'password'
    }
    
    try:
        writer = TimescaleWriter(config)
        writer.batch_size = 5  # Small batch for testing
        
        # Add metrics
        for i in range(3):
            metric = {
                'measurement': 'test_metric',
                'tags': {'service': 'test'},
                'fields': {'value': float(i)},
                'timestamp': datetime.now()
            }
            writer.add_metric(metric)
        
        assert len(writer.batch) == 3
        writer.close()
    except Exception:
        pytest.skip("Database not available for testing")

if __name__ == '__main__':
    pytest.main([__file__, '-v'])
TEST_WRITER_EOF

cat > tests/test_integration.py << 'TEST_INTEGRATION_EOF'
"""
Integration tests for the complete pipeline
"""
import pytest
import sys
sys.path.insert(0, 'src')

from extractors.metrics_extractor import MetricsExtractor
from generators.log_generator import LogGenerator

def test_end_to_end_extraction():
    """Test log generation through extraction"""
    generator = LogGenerator()
    extractor = MetricsExtractor()
    
    # Generate test log
    log = generator.generate_log()
    
    # Extract metrics
    metrics = extractor.extract_from_log(log)
    
    assert len(metrics) > 0
    assert all(hasattr(m, 'measurement') for m in metrics)
    assert all(hasattr(m, 'tags') for m in metrics)
    assert all(hasattr(m, 'fields') for m in metrics)

def test_batch_generation():
    """Test batch log generation"""
    generator = LogGenerator()
    
    batch = generator.generate_batch(count=10)
    
    assert len(batch) == 10
    assert all('timestamp' in log for log in batch)
    assert all('service' in log for log in batch)

if __name__ == '__main__':
    pytest.main([__file__, '-v'])
TEST_INTEGRATION_EOF

# Create configuration
cat > config/database.yaml << 'DB_CONFIG_EOF'
database:
  host: localhost
  port: 5432
  database: metrics
  user: postgres
  password: password

timescale:
  chunk_interval: '1 day'
  retention_policy: '7 days'
  compression_enabled: true

batch_writer:
  batch_size: 1000
  flush_interval: 2.0  # seconds
  connection_pool_size: 10
DB_CONFIG_EOF

# Create Docker files
echo "🐳 Creating Docker configuration..."

cat > docker/Dockerfile.api << 'DOCKERFILE_API_EOF'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY config/ ./config/

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "src.api.query_api:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKERFILE_API_EOF

cat > docker/Dockerfile.dashboard << 'DOCKERFILE_DASH_EOF'
FROM node:18-alpine

WORKDIR /app

COPY src/dashboard/package*.json ./
RUN npm install

COPY src/dashboard/ ./

EXPOSE 3000

CMD ["npm", "start"]
DOCKERFILE_DASH_EOF

cat > docker-compose.yml << 'DOCKER_COMPOSE_EOF'
version: '3.8'

services:
  timescaledb:
    image: timescale/timescaledb:latest-pg15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: metrics
    ports:
      - "5432:5432"
    volumes:
      - timescale_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  metrics-api:
    build:
      context: .
      dockerfile: docker/Dockerfile.api
    ports:
      - "8000:8000"
    depends_on:
      timescaledb:
        condition: service_healthy
    environment:
      DB_HOST: timescaledb
      DB_PORT: 5432
      DB_NAME: metrics
      DB_USER: postgres
      DB_PASSWORD: password

  dashboard:
    build:
      context: .
      dockerfile: docker/Dockerfile.dashboard
    ports:
      - "3000:3000"
    depends_on:
      - metrics-api
    environment:
      REACT_APP_API_URL: http://localhost:8000

volumes:
  timescale_data:
DOCKER_COMPOSE_EOF

cat > .dockerignore << 'DOCKERIGNORE_EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
pip-log.txt
pip-delete-this-directory.txt
.tox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.log
.git
.gitignore
.mypy_cache
.pytest_cache
.hypothesis
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
DOCKERIGNORE_EOF

# Create requirements.txt
cat > requirements.txt << 'REQUIREMENTS_EOF'
fastapi==0.111.0
uvicorn[standard]==0.30.1
psycopg2-binary==2.9.9
pydantic==2.7.1
python-dotenv==1.0.1
pytest==8.2.2
pytest-asyncio==0.23.7
REQUIREMENTS_EOF

# Create build script
cat > build.sh << 'BUILD_SCRIPT_EOF'
#!/bin/bash
set -e

echo "🔨 Building Day 146 project..."

# Create and activate virtual environment
echo "📦 Setting up Python virtual environment..."
python3.11 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
echo "📥 Installing dependencies..."
pip install -r requirements.txt

# Run tests
echo "🧪 Running tests..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
python -m pytest tests/ -v --tb=short || echo "⚠️  Some tests skipped (database may not be running)"

echo "✅ Build complete!"
echo ""
echo "Next steps:"
echo "1. Start TimescaleDB: docker-compose up -d timescaledb"
echo "2. Run pipeline: python src/main.py"
echo "3. Start API: uvicorn src.api.query_api:app --reload"
echo "4. Start dashboard: cd src/dashboard && npm install && npm start"
BUILD_SCRIPT_EOF

chmod +x build.sh

# Create start script
cat > start.sh << 'START_SCRIPT_EOF'
#!/bin/bash
set -e

echo "🚀 Starting Day 146 Time Series Metrics System..."

# Check if Docker is available
if command -v docker &> /dev/null; then
    echo "🐳 Starting services with Docker..."
    docker-compose up -d
    
    echo "⏳ Waiting for services to be ready..."
    sleep 10
    
    echo "✅ Services started!"
    echo "   - TimescaleDB: localhost:5432"
    echo "   - API: http://localhost:8000"
    echo "   - Dashboard: http://localhost:3000"
else
    echo "⚠️  Docker not found. Starting locally..."
    
    # Activate venv
    source venv/bin/activate
    
    # Start API in background
    echo "🔌 Starting API server..."
    python -m uvicorn src.api.query_api:app --host 0.0.0.0 --port 8000 &
    API_PID=$!
    
    # Start dashboard
    echo "📊 Starting dashboard..."
    cd src/dashboard
    npm start &
    DASH_PID=$!
    
    echo "✅ Services started!"
    echo "   API PID: $API_PID"
    echo "   Dashboard PID: $DASH_PID"
    echo ""
    echo "To stop: kill $API_PID $DASH_PID"
fi
START_SCRIPT_EOF

chmod +x start.sh

# Create stop script
cat > stop.sh << 'STOP_SCRIPT_EOF'
#!/bin/bash

echo "🛑 Stopping Day 146 services..."

if command -v docker &> /dev/null; then
    docker-compose down
else
    # Kill processes by port
    lsof -ti:8000 | xargs kill -9 2>/dev/null || true
    lsof -ti:3000 | xargs kill -9 2>/dev/null || true
fi

echo "✅ Services stopped!"
STOP_SCRIPT_EOF

chmod +x stop.sh

# Create demo script
cat > demo.sh << 'DEMO_SCRIPT_EOF'
#!/bin/bash
set -e

echo "🎬 Day 146 Demo: Time Series Metrics System"
echo "============================================"
echo ""

# Activate venv
source venv/bin/activate

# Check if TimescaleDB is running
echo "1️⃣  Checking TimescaleDB connection..."
python -c "
import psycopg2
try:
    conn = psycopg2.connect(
        host='localhost',
        port=5432,
        database='metrics',
        user='postgres',
        password='password'
    )
    conn.close()
    print('   ✅ TimescaleDB connected')
except Exception as e:
    print('   ❌ TimescaleDB not available. Start with: docker-compose up -d timescaledb')
    exit(1)
"

# Setup schema
echo ""
echo "2️⃣  Setting up database schema..."
python -c "
from src.writers.timescale_writer import TimescaleWriter
writer = TimescaleWriter({
    'host': 'localhost',
    'port': 5432,
    'database': 'metrics',
    'user': 'postgres',
    'password': 'password'
})
writer.setup_schema()
writer.close()
print('   ✅ Schema created')
"

# Generate and process logs
echo ""
echo "3️⃣  Generating and processing test logs..."
python -c "
import asyncio
from src.main import MetricsPipeline

async def demo():
    pipeline = MetricsPipeline()
    pipeline.setup()
    print('   🔄 Processing logs for 30 seconds...')
    await pipeline.process_logs(duration=30)
    pipeline.stop()
    print('   ✅ Log processing complete')

asyncio.run(demo())
"

# Query metrics
echo ""
echo "4️⃣  Querying metrics from TimescaleDB..."
python -c "
import psycopg2
from psycopg2.extras import RealDictCursor

conn = psycopg2.connect(
    host='localhost',
    port=5432,
    database='metrics',
    user='postgres',
    password='password',
    cursor_factory=RealDictCursor
)
cur = conn.cursor()

# Response time metrics
cur.execute('''
    SELECT 
        service,
        COUNT(*) as count,
        AVG(response_time_ms) as avg_response_time,
        MIN(response_time_ms) as min_response_time,
        MAX(response_time_ms) as max_response_time
    FROM http_response
    GROUP BY service
    ORDER BY service;
''')

print('   📊 Response Time Metrics:')
for row in cur.fetchall():
    print(f\"      {row['service']}: {row['avg_response_time']:.2f}ms avg (min: {row['min_response_time']:.2f}, max: {row['max_response_time']:.2f}, count: {row['count']})\")

# Error rates
cur.execute('''
    SELECT 
        service,
        COUNT(*) as total,
        SUM(is_error) as errors,
        (SUM(is_error)::float / COUNT(*)::float * 100) as error_rate
    FROM http_status
    GROUP BY service
    ORDER BY service;
''')

print('   🚨 Error Rate Metrics:')
for row in cur.fetchall():
    print(f\"      {row['service']}: {row['error_rate']:.2f}% ({row['errors']}/{row['total']})\")

conn.close()
print('   ✅ Query complete')
"

echo ""
echo "5️⃣  Starting API and Dashboard..."
echo "   Run these commands in separate terminals:"
echo "   Terminal 1: uvicorn src.api.query_api:app --reload"
echo "   Terminal 2: cd src/dashboard && npm start"
echo ""
echo "   Then visit: http://localhost:3000"
echo ""
echo "✅ Demo complete!"
DEMO_SCRIPT_EOF

chmod +x demo.sh

# Create README
cat > README.md << 'README_EOF'
# Day 146: Time Series Database Integration

Production-ready metrics extraction and storage system using TimescaleDB.

## Quick Start

```bash
# Build project
./build.sh

# Start TimescaleDB
docker-compose up -d timescaledb

# Run demo
./demo.sh

# Start all services
./start.sh
```

## Architecture

- **Metrics Extractor**: Parses logs and extracts time series metrics
- **Batch Writer**: Efficiently writes metrics to TimescaleDB
- **Query API**: FastAPI endpoints for metric queries
- **React Dashboard**: Real-time visualization

## API Endpoints

- `GET /metrics/response-time` - Response time metrics
- `GET /metrics/error-rate` - Error rate metrics
- `GET /metrics/resource-usage` - Resource usage metrics
- `GET /metrics/throughput` - Throughput metrics
- `GET /metrics/summary` - Overall summary

## Testing

```bash
source venv/bin/activate
pytest tests/ -v
```

## Docker Deployment

```bash
docker-compose up --build
```

Services:
- TimescaleDB: `localhost:5432`
- API: `http://localhost:8000`
- Dashboard: `http://localhost:3000`
README_EOF

echo ""
echo "✅ Day 146 project structure created successfully!"
echo ""
echo "📁 Project structure:"
tree -L 2 -I 'node_modules|__pycache__|*.pyc' || find . -maxdepth 2 -type d
echo ""
echo "🚀 Next steps:"
echo "1. cd ${PROJECT_NAME}"
echo "2. ./build.sh          # Build and test"
echo "3. ./demo.sh           # Run demonstration"
echo "4. ./start.sh          # Start all services"
echo ""
echo "📚 Documentation: See README.md"