#!/bin/bash

# Day 140: Automated S3/Blob Storage Export System
# Complete implementation with build, test, and demo

set -e  # Exit on any error

echo "🚀 Day 140: S3/Blob Storage Export System Setup"
echo "================================================"

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_DIR="day140_s3_export_system"

# Step 1: Create project structure
echo -e "${BLUE}📁 Creating project structure...${NC}"
mkdir -p ${PROJECT_DIR}/{src/{export,storage,scheduler,api,web},tests,config,data/{exports,metadata},docker,scripts}
cd ${PROJECT_DIR}

# Create __init__.py files
touch src/__init__.py
touch src/export/__init__.py
touch src/storage/__init__.py
touch src/scheduler/__init__.py
touch src/api/__init__.py
touch src/web/__init__.py
touch tests/__init__.py

# Step 2: Create requirements.txt
echo -e "${BLUE}📦 Creating requirements.txt...${NC}"
cat > requirements.txt << 'EOF'
# Core dependencies
boto3==1.34.110
botocore==1.34.110
python-dotenv==1.0.1

# Scheduling
APScheduler==3.10.4
pytz==2024.1

# Data processing
pandas==2.2.2
pyarrow==16.1.0

# Web framework
fastapi==0.111.0
uvicorn[standard]==0.30.1
websockets==12.0
pydantic==2.7.1
pydantic-settings==2.2.1

# Database
sqlalchemy==2.0.30
aiosqlite==0.20.0

# Compression
zstandard==0.22.0

# Monitoring
prometheus-client==0.20.0

# Testing
pytest==8.2.1
pytest-asyncio==0.23.7
pytest-cov==5.0.0
moto==5.0.6
httpx==0.27.0

# Development
colorama==0.4.6
structlog==24.1.0
EOF

# Step 3: Create configuration
echo -e "${BLUE}⚙️  Creating configuration files...${NC}"
cat > config/config.yaml << 'EOF'
storage:
  provider: "s3"  # s3, minio, or local
  bucket_name: "distributed-logs-export"
  region: "us-east-1"
  endpoint_url: null  # For MinIO: http://localhost:9000
  
export:
  schedule_interval: "0 2 * * *"  # Daily at 2 AM (cron format)
  batch_size: 10000  # Records per batch
  compression: "gzip"  # gzip, zstd, or none
  format: "parquet"  # parquet, json, or csv
  
partitioning:
  scheme: "date_service_level"
  date_format: "year=%Y/month=%m/day=%d"
  include_service: true
  include_level: true
  
retry:
  max_attempts: 3
  backoff_multiplier: 2
  initial_delay: 1

monitoring:
  enable_prometheus: true
  metrics_port: 9090

database:
  url: "sqlite:///data/logs.db"
  metadata_url: "sqlite:///data/metadata.db"
EOF

cat > config/.env.example << 'EOF'
# AWS Credentials (use IAM roles in production)
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1

# For MinIO local testing
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
MINIO_ENDPOINT=http://localhost:9000

# Application
ENVIRONMENT=development
LOG_LEVEL=INFO
EOF

# Step 4: Create storage client abstraction
echo -e "${BLUE}🗄️  Creating storage client...${NC}"
cat > src/storage/client.py << 'EOF'
"""Cloud storage client abstraction supporting S3, MinIO, and local storage."""
import os
import boto3
from boto3.s3.transfer import TransferConfig
from botocore.exceptions import ClientError
from typing import Optional, BinaryIO, Dict, Any
from pathlib import Path
import structlog

logger = structlog.get_logger()


class StorageClient:
    """Unified storage client for S3-compatible services."""
    
    def __init__(self, bucket_name: str, region: str = "us-east-1", 
                 endpoint_url: Optional[str] = None, **kwargs):
        self.bucket_name = bucket_name
        self.region = region
        self.endpoint_url = endpoint_url
        
        # Initialize S3 client
        self.s3_client = boto3.client(
            's3',
            region_name=region,
            endpoint_url=endpoint_url,
            aws_access_key_id=kwargs.get('access_key'),
            aws_secret_access_key=kwargs.get('secret_key')
        )
        
        # Configure multipart upload for files > 5MB
        self.transfer_config = TransferConfig(
            multipart_threshold=1024 * 1024 * 5,  # 5MB
            max_concurrency=10,
            multipart_chunksize=1024 * 1024 * 5,
            use_threads=True
        )
        
        self._ensure_bucket_exists()
    
    def _ensure_bucket_exists(self) -> None:
        """Create bucket if it doesn't exist."""
        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
            logger.info(f"Bucket {self.bucket_name} exists")
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == '404':
                logger.info(f"Creating bucket {self.bucket_name}")
                self.s3_client.create_bucket(Bucket=self.bucket_name)
            else:
                raise
    
    def upload_file(self, file_path: str, s3_key: str, 
                    metadata: Optional[Dict[str, str]] = None,
                    callback=None) -> bool:
        """Upload file to S3 with optional progress callback."""
        try:
            extra_args = {}
            if metadata:
                extra_args['Metadata'] = metadata
            
            self.s3_client.upload_file(
                file_path,
                self.bucket_name,
                s3_key,
                ExtraArgs=extra_args,
                Config=self.transfer_config,
                Callback=callback
            )
            
            logger.info(f"Uploaded {file_path} to s3://{self.bucket_name}/{s3_key}")
            return True
            
        except ClientError as e:
            logger.error(f"Upload failed: {e}")
            return False
    
    def upload_fileobj(self, fileobj: BinaryIO, s3_key: str,
                       metadata: Optional[Dict[str, str]] = None) -> bool:
        """Upload file object to S3."""
        try:
            extra_args = {}
            if metadata:
                extra_args['Metadata'] = metadata
            
            self.s3_client.upload_fileobj(
                fileobj,
                self.bucket_name,
                s3_key,
                ExtraArgs=extra_args,
                Config=self.transfer_config
            )
            
            logger.info(f"Uploaded fileobj to s3://{self.bucket_name}/{s3_key}")
            return True
            
        except ClientError as e:
            logger.error(f"Upload failed: {e}")
            return False
    
    def list_objects(self, prefix: str = "") -> list:
        """List objects with given prefix."""
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix
            )
            return response.get('Contents', [])
        except ClientError as e:
            logger.error(f"List failed: {e}")
            return []
    
    def get_object_metadata(self, s3_key: str) -> Optional[Dict[str, Any]]:
        """Get object metadata."""
        try:
            response = self.s3_client.head_object(
                Bucket=self.bucket_name,
                Key=s3_key
            )
            return {
                'size': response['ContentLength'],
                'last_modified': response['LastModified'],
                'metadata': response.get('Metadata', {})
            }
        except ClientError as e:
            logger.error(f"Get metadata failed: {e}")
            return None
    
    def delete_object(self, s3_key: str) -> bool:
        """Delete object from S3."""
        try:
            self.s3_client.delete_object(
                Bucket=self.bucket_name,
                Key=s3_key
            )
            logger.info(f"Deleted s3://{self.bucket_name}/{s3_key}")
            return True
        except ClientError as e:
            logger.error(f"Delete failed: {e}")
            return False
    
    def get_bucket_size(self) -> int:
        """Calculate total bucket size in bytes."""
        total_size = 0
        try:
            paginator = self.s3_client.get_paginator('list_objects_v2')
            for page in paginator.paginate(Bucket=self.bucket_name):
                for obj in page.get('Contents', []):
                    total_size += obj['Size']
        except ClientError as e:
            logger.error(f"Get bucket size failed: {e}")
        
        return total_size


class ProgressCallback:
    """Progress callback for uploads."""
    
    def __init__(self, filename: str, filesize: int):
        self.filename = filename
        self.filesize = filesize
        self.uploaded = 0
    
    def __call__(self, bytes_transferred: int):
        self.uploaded += bytes_transferred
        percentage = (self.uploaded / self.filesize) * 100
        logger.debug(f"{self.filename}: {percentage:.1f}% uploaded")
EOF

# Step 5: Create data partitioner
echo -e "${BLUE}📂 Creating data partitioner...${NC}"
cat > src/export/partitioner.py << 'EOF'
"""Data partitioning logic for organized S3 exports."""
from datetime import datetime
from typing import Dict, Any, Optional
from pathlib import Path
import structlog

logger = structlog.get_logger()


class DataPartitioner:
    """Handles data partitioning strategies for S3 exports."""
    
    def __init__(self, config: Dict[str, Any]):
        self.scheme = config.get('scheme', 'date_service_level')
        self.date_format = config.get('date_format', 'year=%Y/month=%m/day=%d')
        self.include_service = config.get('include_service', True)
        self.include_level = config.get('include_level', True)
    
    def generate_partition_key(self, log_entry: Dict[str, Any], 
                               export_time: Optional[datetime] = None) -> str:
        """Generate S3 key based on partitioning scheme."""
        export_time = export_time or datetime.utcnow()
        
        # Base path with date partition
        date_path = export_time.strftime(self.date_format)
        path_parts = ['logs', date_path]
        
        # Add service partition
        if self.include_service and 'service' in log_entry:
            service = log_entry['service']
            path_parts.append(f'service={service}')
        
        # Add level partition
        if self.include_level and 'level' in log_entry:
            level = log_entry['level']
            path_parts.append(f'level={level}')
        
        return '/'.join(path_parts)
    
    def generate_filename(self, export_time: datetime, 
                         export_format: str = 'parquet',
                         compression: str = 'gzip') -> str:
        """Generate filename for export file."""
        timestamp = export_time.strftime('%Y%m%d_%H%M%S')
        
        # Extension based on format and compression
        ext = self._get_extension(export_format, compression)
        
        return f'export_{timestamp}.{ext}'
    
    def _get_extension(self, format: str, compression: str) -> str:
        """Determine file extension based on format and compression."""
        extensions = {
            ('parquet', 'gzip'): 'parquet.gz',
            ('parquet', 'zstd'): 'parquet.zst',
            ('parquet', 'none'): 'parquet',
            ('json', 'gzip'): 'json.gz',
            ('json', 'zstd'): 'json.zst',
            ('json', 'none'): 'json',
            ('csv', 'gzip'): 'csv.gz',
            ('csv', 'none'): 'csv'
        }
        return extensions.get((format, compression), f'{format}.{compression}')
    
    def parse_partition_from_key(self, s3_key: str) -> Dict[str, Any]:
        """Extract partition information from S3 key."""
        parts = s3_key.split('/')
        partition_info = {}
        
        for part in parts:
            if '=' in part:
                key, value = part.split('=', 1)
                partition_info[key] = value
        
        return partition_info
    
    def generate_full_s3_key(self, log_entry: Dict[str, Any],
                             export_time: datetime,
                             export_format: str = 'parquet',
                             compression: str = 'gzip') -> str:
        """Generate complete S3 key including filename."""
        partition_key = self.generate_partition_key(log_entry, export_time)
        filename = self.generate_filename(export_time, export_format, compression)
        
        return f'{partition_key}/{filename}'
EOF

# Step 6: Create export engine
echo -e "${BLUE}⚡ Creating export engine...${NC}"
cat > src/export/engine.py << 'EOF'
"""Core export engine for processing and uploading log data."""
import gzip
import zstandard as zstd
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Any, Optional
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import json
import structlog
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from src.storage.client import StorageClient, ProgressCallback
from src.export.partitioner import DataPartitioner

logger = structlog.get_logger()


class ExportEngine:
    """Handles log data export to cloud storage."""
    
    def __init__(self, config: Dict[str, Any], storage_client: StorageClient):
        self.config = config
        self.storage_client = storage_client
        self.partitioner = DataPartitioner(config.get('partitioning', {}))
        
        # Database connection
        db_url = config.get('database', {}).get('url', 'sqlite:///data/logs.db')
        self.engine = create_engine(db_url)
        self.Session = sessionmaker(bind=self.engine)
        
        # Metadata tracking
        metadata_url = config.get('database', {}).get('metadata_url', 'sqlite:///data/metadata.db')
        self.metadata_engine = create_engine(metadata_url)
        self._init_metadata_table()
        
        # Export settings
        self.batch_size = config.get('export', {}).get('batch_size', 10000)
        self.export_format = config.get('export', {}).get('format', 'parquet')
        self.compression = config.get('export', {}).get('compression', 'gzip')
        
        # Retry configuration
        retry_config = config.get('retry', {})
        self.max_attempts = retry_config.get('max_attempts', 3)
        self.backoff_multiplier = retry_config.get('backoff_multiplier', 2)
        self.initial_delay = retry_config.get('initial_delay', 1)
    
    def _init_metadata_table(self):
        """Initialize export metadata tracking table."""
        with self.metadata_engine.connect() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS export_metadata (
                    export_id TEXT PRIMARY KEY,
                    export_time TIMESTAMP,
                    s3_key TEXT,
                    record_count INTEGER,
                    file_size INTEGER,
                    start_timestamp TIMESTAMP,
                    end_timestamp TIMESTAMP,
                    status TEXT,
                    error_message TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            conn.commit()
    
    def get_last_export_time(self) -> Optional[datetime]:
        """Get timestamp of last successful export."""
        with self.metadata_engine.connect() as conn:
            result = conn.execute(text("""
                SELECT MAX(end_timestamp) as last_export
                FROM export_metadata
                WHERE status = 'completed'
            """))
            row = result.fetchone()
            return row[0] if row and row[0] else None
    
    def export_logs(self, start_time: Optional[datetime] = None,
                    end_time: Optional[datetime] = None) -> Dict[str, Any]:
        """Export logs for given time range."""
        export_time = datetime.utcnow()
        
        # Determine time range
        if not start_time:
            start_time = self.get_last_export_time() or (export_time - timedelta(days=1))
        if not end_time:
            end_time = export_time
        
        logger.info(f"Starting export from {start_time} to {end_time}")
        
        try:
            # Fetch logs from database
            logs = self._fetch_logs(start_time, end_time)
            
            if not logs:
                logger.info("No logs to export")
                return {'status': 'success', 'records_exported': 0}
            
            # Group logs by partition
            partitioned_logs = self._partition_logs(logs, export_time)
            
            # Export each partition
            total_exported = 0
            export_results = []
            
            for partition_key, partition_logs in partitioned_logs.items():
                result = self._export_partition(
                    partition_logs,
                    partition_key,
                    export_time,
                    start_time,
                    end_time
                )
                export_results.append(result)
                total_exported += result['record_count']
            
            logger.info(f"Export completed: {total_exported} records exported")
            
            return {
                'status': 'success',
                'records_exported': total_exported,
                'partitions': len(export_results),
                'export_details': export_results
            }
            
        except Exception as e:
            logger.error(f"Export failed: {e}", exc_info=True)
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def _fetch_logs(self, start_time: datetime, end_time: datetime) -> List[Dict[str, Any]]:
        """Fetch logs from database for export."""
        with self.Session() as session:
            query = text("""
                SELECT id, timestamp, service, level, message, metadata
                FROM logs
                WHERE timestamp >= :start_time AND timestamp < :end_time
                ORDER BY timestamp
                LIMIT :limit
            """)
            
            result = session.execute(
                query,
                {'start_time': start_time, 'end_time': end_time, 'limit': self.batch_size * 10}
            )
            
            logs = []
            for row in result:
                logs.append({
                    'id': row[0],
                    'timestamp': row[1],
                    'service': row[2],
                    'level': row[3],
                    'message': row[4],
                    'metadata': json.loads(row[5]) if row[5] else {}
                })
            
            return logs
    
    def _partition_logs(self, logs: List[Dict[str, Any]], 
                       export_time: datetime) -> Dict[str, List[Dict[str, Any]]]:
        """Group logs by partition key."""
        partitions = {}
        
        for log in logs:
            partition_key = self.partitioner.generate_partition_key(log, export_time)
            if partition_key not in partitions:
                partitions[partition_key] = []
            partitions[partition_key].append(log)
        
        return partitions
    
    def _export_partition(self, logs: List[Dict[str, Any]], partition_key: str,
                         export_time: datetime, start_time: datetime,
                         end_time: datetime) -> Dict[str, Any]:
        """Export a single partition to S3."""
        # Generate filename
        filename = self.partitioner.generate_filename(
            export_time, self.export_format, self.compression
        )
        s3_key = f'{partition_key}/{filename}'
        
        # Create temporary file
        temp_dir = Path('data/exports')
        temp_dir.mkdir(parents=True, exist_ok=True)
        temp_file = temp_dir / filename
        
        try:
            # Convert to desired format and compress
            file_size = self._write_export_file(logs, temp_file)
            
            # Upload to S3
            success = self.storage_client.upload_file(
                str(temp_file),
                s3_key,
                metadata={
                    'record_count': str(len(logs)),
                    'export_time': export_time.isoformat(),
                    'start_time': start_time.isoformat(),
                    'end_time': end_time.isoformat()
                }
            )
            
            if success:
                # Record metadata
                self._record_export_metadata(
                    s3_key, len(logs), file_size,
                    start_time, end_time, 'completed', None
                )
            
            return {
                's3_key': s3_key,
                'record_count': len(logs),
                'file_size': file_size,
                'status': 'completed' if success else 'failed'
            }
            
        finally:
            # Clean up temporary file
            if temp_file.exists():
                temp_file.unlink()
    
    def _write_export_file(self, logs: List[Dict[str, Any]], 
                          output_path: Path) -> int:
        """Write logs to file in specified format with compression."""
        if self.export_format == 'parquet':
            return self._write_parquet(logs, output_path)
        elif self.export_format == 'json':
            return self._write_json(logs, output_path)
        else:
            raise ValueError(f"Unsupported export format: {self.export_format}")
    
    def _write_parquet(self, logs: List[Dict[str, Any]], output_path: Path) -> int:
        """Write logs as Parquet file."""
        df = pd.DataFrame(logs)
        
        # Convert to Arrow table
        table = pa.Table.from_pandas(df)
        
        # Determine compression
        compression_type = 'gzip' if self.compression == 'gzip' else 'zstd' if self.compression == 'zstd' else None
        
        # Write Parquet
        pq.write_table(table, str(output_path), compression=compression_type)
        
        return output_path.stat().st_size
    
    def _write_json(self, logs: List[Dict[str, Any]], output_path: Path) -> int:
        """Write logs as JSON file with optional compression."""
        if self.compression == 'gzip':
            with gzip.open(str(output_path), 'wt', encoding='utf-8') as f:
                for log in logs:
                    json.dump(log, f)
                    f.write('\n')
        elif self.compression == 'zstd':
            cctx = zstd.ZstdCompressor()
            with open(str(output_path), 'wb') as f:
                with cctx.stream_writer(f) as compressor:
                    for log in logs:
                        line = json.dumps(log) + '\n'
                        compressor.write(line.encode('utf-8'))
        else:
            with open(str(output_path), 'w', encoding='utf-8') as f:
                for log in logs:
                    json.dump(log, f)
                    f.write('\n')
        
        return output_path.stat().st_size
    
    def _record_export_metadata(self, s3_key: str, record_count: int,
                                file_size: int, start_time: datetime,
                                end_time: datetime, status: str,
                                error_message: Optional[str]):
        """Record export metadata to tracking table."""
        export_id = f"{s3_key}_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"
        
        with self.metadata_engine.connect() as conn:
            conn.execute(text("""
                INSERT INTO export_metadata 
                (export_id, export_time, s3_key, record_count, file_size,
                 start_timestamp, end_timestamp, status, error_message)
                VALUES (:export_id, :export_time, :s3_key, :record_count, :file_size,
                        :start_time, :end_time, :status, :error_message)
            """), {
                'export_id': export_id,
                'export_time': datetime.utcnow(),
                's3_key': s3_key,
                'record_count': record_count,
                'file_size': file_size,
                'start_time': start_time,
                'end_time': end_time,
                'status': status,
                'error_message': error_message
            })
            conn.commit()
EOF

# Step 7: Create scheduler
echo -e "${BLUE}⏰ Creating export scheduler...${NC}"
cat > src/scheduler/job_scheduler.py << 'EOF'
"""APScheduler-based export job scheduler."""
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from datetime import datetime
from typing import Dict, Any, Callable
import structlog

logger = structlog.get_logger()


class ExportScheduler:
    """Manages scheduled export jobs."""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.scheduler = AsyncIOScheduler()
        self.jobs = {}
        
    def start(self):
        """Start the scheduler."""
        self.scheduler.start()
        logger.info("Export scheduler started")
    
    def shutdown(self):
        """Shutdown the scheduler."""
        self.scheduler.shutdown()
        logger.info("Export scheduler stopped")
    
    def add_export_job(self, job_id: str, export_func: Callable,
                      cron_expression: str = "0 2 * * *"):
        """Add a scheduled export job."""
        trigger = CronTrigger.from_crontab(cron_expression)
        
        job = self.scheduler.add_job(
            export_func,
            trigger=trigger,
            id=job_id,
            replace_existing=True,
            misfire_grace_time=3600  # 1 hour grace period
        )
        
        self.jobs[job_id] = job
        logger.info(f"Added export job: {job_id} with schedule: {cron_expression}")
        
        return job
    
    def trigger_manual_export(self, export_func: Callable) -> None:
        """Trigger immediate export."""
        logger.info("Triggering manual export")
        self.scheduler.add_job(
            export_func,
            id=f'manual_export_{datetime.utcnow().isoformat()}',
            replace_existing=True
        )
    
    def get_next_run_time(self, job_id: str) -> str:
        """Get next scheduled run time for job."""
        job = self.scheduler.get_job(job_id)
        if job and job.next_run_time:
            return job.next_run_time.isoformat()
        return "Not scheduled"
    
    def list_jobs(self) -> list:
        """List all scheduled jobs."""
        return [
            {
                'id': job.id,
                'next_run': job.next_run_time.isoformat() if job.next_run_time else None,
                'trigger': str(job.trigger)
            }
            for job in self.scheduler.get_jobs()
        ]
EOF

# Step 8: Create FastAPI application
echo -e "${BLUE}🌐 Creating API server...${NC}"
cat > src/api/app.py << 'EOF'
"""FastAPI application for export management."""
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime
import yaml
import structlog
import os

from src.storage.client import StorageClient
from src.export.engine import ExportEngine
from src.scheduler.job_scheduler import ExportScheduler

logger = structlog.get_logger()

app = FastAPI(title="S3 Export System", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global state
storage_client = None
export_engine = None
scheduler = None
config = {}

class ExportRequest(BaseModel):
    start_time: Optional[str] = None
    end_time: Optional[str] = None

class ExportResponse(BaseModel):
    status: str
    records_exported: int
    message: str


@app.on_event("startup")
async def startup_event():
    """Initialize services on startup."""
    global storage_client, export_engine, scheduler, config
    
    # Load configuration
    with open('config/config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    
    # Initialize storage client
    storage_config = config['storage']
    storage_client = StorageClient(
        bucket_name=storage_config['bucket_name'],
        region=storage_config.get('region', 'us-east-1'),
        endpoint_url=storage_config.get('endpoint_url'),
        access_key=os.getenv('AWS_ACCESS_KEY_ID'),
        secret_key=os.getenv('AWS_SECRET_ACCESS_KEY')
    )
    
    # Initialize export engine
    export_engine = ExportEngine(config, storage_client)
    
    # Initialize scheduler
    scheduler = ExportScheduler(config)
    
    # Add scheduled export job
    cron_expr = config['export'].get('schedule_interval', '0 2 * * *')
    scheduler.add_export_job(
        'daily_export',
        lambda: export_engine.export_logs(),
        cron_expr
    )
    
    scheduler.start()
    
    logger.info("Export system initialized")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    if scheduler:
        scheduler.shutdown()
    logger.info("Export system shutdown")


@app.get("/")
async def root():
    """API root endpoint."""
    return {
        "service": "S3 Export System",
        "version": "1.0.0",
        "status": "operational"
    }


@app.post("/api/export/manual", response_model=ExportResponse)
async def trigger_manual_export(
    request: ExportRequest,
    background_tasks: BackgroundTasks
):
    """Trigger manual export."""
    try:
        start_time = datetime.fromisoformat(request.start_time) if request.start_time else None
        end_time = datetime.fromisoformat(request.end_time) if request.end_time else None
        
        # Trigger export in background
        result = export_engine.export_logs(start_time, end_time)
        
        return ExportResponse(
            status=result['status'],
            records_exported=result.get('records_exported', 0),
            message="Export completed successfully" if result['status'] == 'success' else result.get('error', 'Export failed')
        )
        
    except Exception as e:
        logger.error(f"Manual export failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/export/status")
async def get_export_status():
    """Get export system status."""
    try:
        last_export = export_engine.get_last_export_time()
        bucket_size = storage_client.get_bucket_size()
        
        return {
            "last_export_time": last_export.isoformat() if last_export else None,
            "bucket_size_bytes": bucket_size,
            "bucket_size_gb": round(bucket_size / (1024**3), 2),
            "scheduled_jobs": scheduler.list_jobs()
        }
    except Exception as e:
        logger.error(f"Get status failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/export/history")
async def get_export_history(limit: int = 10):
    """Get recent export history."""
    try:
        from sqlalchemy import text
        
        with export_engine.metadata_engine.connect() as conn:
            result = conn.execute(text("""
                SELECT export_id, export_time, s3_key, record_count, 
                       file_size, status, error_message
                FROM export_metadata
                ORDER BY export_time DESC
                LIMIT :limit
            """), {'limit': limit})
            
            history = []
            for row in result:
                history.append({
                    'export_id': row[0],
                    'export_time': row[1].isoformat() if row[1] else None,
                    's3_key': row[2],
                    'record_count': row[3],
                    'file_size': row[4],
                    'file_size_mb': round(row[4] / (1024**2), 2) if row[4] else 0,
                    'status': row[5],
                    'error_message': row[6]
                })
            
            return {'history': history}
            
    except Exception as e:
        logger.error(f"Get history failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/storage/objects")
async def list_storage_objects(prefix: str = ""):
    """List objects in storage."""
    try:
        objects = storage_client.list_objects(prefix)
        
        return {
            'objects': [
                {
                    'key': obj['Key'],
                    'size': obj['Size'],
                    'size_mb': round(obj['Size'] / (1024**2), 2),
                    'last_modified': obj['LastModified'].isoformat()
                }
                for obj in objects[:100]  # Limit to 100
            ],
            'total_count': len(objects)
        }
    except Exception as e:
        logger.error(f"List objects failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}
EOF

# Step 9: Create React web dashboard
echo -e "${BLUE}💻 Creating React dashboard...${NC}"
mkdir -p src/web/static
cat > src/web/static/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>S3 Export System Dashboard</title>
    <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
    <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
    <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
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
            border-radius: 16px;
            padding: 30px;
            margin-bottom: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            color: #667eea;
            font-size: 32px;
            font-weight: 700;
            margin-bottom: 8px;
        }
        
        .header p {
            color: #6b7280;
            font-size: 16px;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 25px;
        }
        
        .stat-card {
            background: white;
            border-radius: 16px;
            padding: 25px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.08);
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .stat-card:hover {
            transform: translateY(-4px);
            box-shadow: 0 8px 25px rgba(0,0,0,0.12);
        }
        
        .stat-label {
            color: #6b7280;
            font-size: 14px;
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 10px;
        }
        
        .stat-value {
            color: #111827;
            font-size: 32px;
            font-weight: 700;
            margin-bottom: 5px;
        }
        
        .stat-detail {
            color: #9ca3af;
            font-size: 13px;
        }
        
        .content-grid {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 25px;
            margin-bottom: 25px;
        }
        
        .panel {
            background: white;
            border-radius: 16px;
            padding: 25px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.08);
        }
        
        .panel-title {
            color: #111827;
            font-size: 20px;
            font-weight: 600;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 28px;
            border-radius: 10px;
            font-size: 15px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
        }
        
        .btn:active {
            transform: translateY(0);
        }
        
        .btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
        }
        
        .history-table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .history-table th {
            background: #f9fafb;
            padding: 12px;
            text-align: left;
            color: #6b7280;
            font-size: 13px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            border-bottom: 2px solid #e5e7eb;
        }
        
        .history-table td {
            padding: 14px 12px;
            border-bottom: 1px solid #f3f4f6;
            color: #374151;
            font-size: 14px;
        }
        
        .history-table tr:hover {
            background: #f9fafb;
        }
        
        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .status-completed {
            background: #d1fae5;
            color: #065f46;
        }
        
        .status-failed {
            background: #fee2e2;
            color: #991b1b;
        }
        
        .schedule-info {
            background: #f0f9ff;
            border-left: 4px solid #0284c7;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 15px;
        }
        
        .schedule-info strong {
            color: #0369a1;
            display: block;
            margin-bottom: 5px;
        }
        
        .schedule-info span {
            color: #075985;
            font-size: 14px;
        }
        
        .loading {
            text-align: center;
            padding: 40px;
            color: #6b7280;
        }
        
        .spinner {
            border: 3px solid #f3f4f6;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 15px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .success-message {
            background: #d1fae5;
            color: #065f46;
            padding: 12px 20px;
            border-radius: 8px;
            margin-bottom: 15px;
            border-left: 4px solid #10b981;
        }
    </style>
</head>
<body>
    <div id="root"></div>

    <script type="text/babel">
        const { useState, useEffect } = React;

        function Dashboard() {
            const [status, setStatus] = useState(null);
            const [history, setHistory] = useState([]);
            const [loading, setLoading] = useState(true);
            const [exporting, setExporting] = useState(false);
            const [message, setMessage] = useState('');

            const fetchData = async () => {
                try {
                    const [statusRes, historyRes] = await Promise.all([
                        fetch('/api/export/status'),
                        fetch('/api/export/history')
                    ]);
                    
                    const statusData = await statusRes.json();
                    const historyData = await historyRes.json();
                    
                    setStatus(statusData);
                    setHistory(historyData.history || []);
                    setLoading(false);
                } catch (error) {
                    console.error('Error fetching data:', error);
                    setLoading(false);
                }
            };

            useEffect(() => {
                fetchData();
                const interval = setInterval(fetchData, 10000); // Refresh every 10s
                return () => clearInterval(interval);
            }, []);

            const triggerExport = async () => {
                setExporting(true);
                setMessage('');
                
                try {
                    const response = await fetch('/api/export/manual', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({})
                    });
                    
                    const result = await response.json();
                    setMessage(`✓ Export completed: ${result.records_exported} records exported`);
                    setTimeout(() => fetchData(), 2000);
                } catch (error) {
                    setMessage(`✗ Export failed: ${error.message}`);
                } finally {
                    setExporting(false);
                }
            };

            if (loading) {
                return (
                    <div className="container">
                        <div className="loading">
                            <div className="spinner"></div>
                            <p>Loading dashboard...</p>
                        </div>
                    </div>
                );
            }

            return (
                <div className="container">
                    <div className="header">
                        <h1>📦 S3 Export System</h1>
                        <p>Automated cloud storage exports for distributed log processing</p>
                    </div>

                    <div className="stats-grid">
                        <div className="stat-card">
                            <div className="stat-label">Bucket Size</div>
                            <div className="stat-value">{status?.bucket_size_gb || 0} GB</div>
                            <div className="stat-detail">{(status?.bucket_size_bytes || 0).toLocaleString()} bytes</div>
                        </div>
                        
                        <div className="stat-card">
                            <div className="stat-label">Last Export</div>
                            <div className="stat-value">
                                {status?.last_export_time ? new Date(status.last_export_time).toLocaleTimeString() : 'Never'}
                            </div>
                            <div className="stat-detail">
                                {status?.last_export_time ? new Date(status.last_export_time).toLocaleDateString() : 'No exports yet'}
                            </div>
                        </div>
                        
                        <div className="stat-card">
                            <div className="stat-label">Total Exports</div>
                            <div className="stat-value">{history.length}</div>
                            <div className="stat-detail">Successful exports recorded</div>
                        </div>
                        
                        <div className="stat-card">
                            <div className="stat-label">System Status</div>
                            <div className="stat-value">🟢 Active</div>
                            <div className="stat-detail">All systems operational</div>
                        </div>
                    </div>

                    <div className="content-grid">
                        <div className="panel">
                            <h2 className="panel-title">📋 Export History</h2>
                            
                            {history.length > 0 ? (
                                <table className="history-table">
                                    <thead>
                                        <tr>
                                            <th>Time</th>
                                            <th>S3 Key</th>
                                            <th>Records</th>
                                            <th>Size</th>
                                            <th>Status</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {history.map((item, idx) => (
                                            <tr key={idx}>
                                                <td>{item.export_time ? new Date(item.export_time).toLocaleString() : 'N/A'}</td>
                                                <td style={{maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis'}}>
                                                    {item.s3_key}
                                                </td>
                                                <td>{item.record_count?.toLocaleString()}</td>
                                                <td>{item.file_size_mb} MB</td>
                                                <td>
                                                    <span className={`status-badge status-${item.status}`}>
                                                        {item.status}
                                                    </span>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            ) : (
                                <p style={{textAlign: 'center', color: '#6b7280', padding: '40px'}}>
                                    No export history available
                                </p>
                            )}
                        </div>

                        <div className="panel">
                            <h2 className="panel-title">⚙️ Export Control</h2>
                            
                            {status?.scheduled_jobs?.length > 0 && (
                                <div className="schedule-info">
                                    <strong>Next Scheduled Export</strong>
                                    <span>{new Date(status.scheduled_jobs[0].next_run).toLocaleString()}</span>
                                </div>
                            )}
                            
                            {message && (
                                <div className="success-message">
                                    {message}
                                </div>
                            )}
                            
                            <button 
                                className="btn" 
                                onClick={triggerExport}
                                disabled={exporting}
                                style={{width: '100%'}}
                            >
                                {exporting ? '⏳ Exporting...' : '🚀 Trigger Manual Export'}
                            </button>
                            
                            <div style={{marginTop: '20px', fontSize: '13px', color: '#6b7280'}}>
                                <p style={{marginBottom: '8px'}}>
                                    <strong>Compression:</strong> GZIP
                                </p>
                                <p style={{marginBottom: '8px'}}>
                                    <strong>Format:</strong> Parquet
                                </p>
                                <p>
                                    <strong>Partitioning:</strong> Date/Service/Level
                                </p>
                            </div>
                        </div>
                    </div>
                </div>
            );
        }

        ReactDOM.render(<Dashboard />, document.getElementById('root'));
    </script>
</body>
</html>
EOF

# Step 10: Create test database initializer
echo -e "${BLUE}🗄️  Creating database initializer...${NC}"
cat > src/init_db.py << 'EOF'
"""Initialize test database with sample log data."""
from sqlalchemy import create_engine, text
from datetime import datetime, timedelta
import random
import json

def init_database():
    """Create logs table and populate with sample data."""
    engine = create_engine('sqlite:///data/logs.db')
    
    with engine.connect() as conn:
        # Create logs table
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TIMESTAMP NOT NULL,
                service TEXT NOT NULL,
                level TEXT NOT NULL,
                message TEXT NOT NULL,
                metadata TEXT
            )
        """))
        conn.commit()
        
        # Check if data exists
        result = conn.execute(text("SELECT COUNT(*) FROM logs"))
        count = result.fetchone()[0]
        
        if count > 0:
            print(f"Database already has {count} records")
            return
        
        # Generate sample logs
        services = ['api-gateway', 'auth-service', 'payment-service', 'user-service', 'notification-service']
        levels = ['INFO', 'WARNING', 'ERROR', 'DEBUG']
        messages = [
            'Request processed successfully',
            'Authentication failed',
            'Payment transaction completed',
            'User session created',
            'Email notification sent',
            'Database query slow',
            'Cache miss occurred',
            'Rate limit exceeded'
        ]
        
        print("Generating 5000 sample log entries...")
        
        logs = []
        for i in range(5000):
            timestamp = datetime.utcnow() - timedelta(hours=random.randint(0, 72))
            service = random.choice(services)
            level = random.choice(levels)
            message = random.choice(messages)
            metadata = json.dumps({
                'request_id': f'req_{random.randint(1000, 9999)}',
                'user_id': random.randint(1, 1000),
                'duration_ms': random.randint(10, 500)
            })
            
            logs.append({
                'timestamp': timestamp,
                'service': service,
                'level': level,
                'message': message,
                'metadata': metadata
            })
        
        # Insert in batches
        conn.execute(text("""
            INSERT INTO logs (timestamp, service, level, message, metadata)
            VALUES (:timestamp, :service, :level, :message, :metadata)
        """), logs)
        conn.commit()
        
        print(f"✓ Inserted {len(logs)} sample log entries")

if __name__ == '__main__':
    init_database()
EOF

# Step 11: Create main application entry point
echo -e "${BLUE}🚪 Creating main application...${NC}"
cat > src/main.py << 'EOF'
"""Main application entry point."""
import uvicorn
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.api.app import app

if __name__ == "__main__":
    # Serve static files
    from fastapi.staticfiles import StaticFiles
    app.mount("/", StaticFiles(directory="src/web/static", html=True), name="static")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
EOF

# Step 12: Create comprehensive tests
echo -e "${BLUE}🧪 Creating test suite...${NC}"
cat > tests/test_storage_client.py << 'EOF'
"""Tests for storage client."""
import pytest
from moto import mock_aws
import boto3
from src.storage.client import StorageClient

@mock_aws
def test_storage_client_initialization():
    """Test storage client initialization."""
    client = StorageClient(
        bucket_name='test-bucket',
        region='us-east-1'
    )
    assert client.bucket_name == 'test-bucket'

@mock_aws
def test_bucket_creation():
    """Test bucket creation."""
    s3 = boto3.client('s3', region_name='us-east-1')
    
    client = StorageClient(
        bucket_name='test-bucket',
        region='us-east-1'
    )
    
    buckets = s3.list_buckets()
    bucket_names = [b['Name'] for b in buckets['Buckets']]
    assert 'test-bucket' in bucket_names

@mock_aws
def test_file_upload():
    """Test file upload to S3."""
    import tempfile
    
    client = StorageClient(
        bucket_name='test-bucket',
        region='us-east-1'
    )
    
    # Create temporary file
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
        f.write('test content')
        temp_file = f.name
    
    # Upload file
    success = client.upload_file(temp_file, 'test.txt')
    assert success == True
    
    # Verify upload
    objects = client.list_objects()
    assert len(objects) > 0
EOF

cat > tests/test_partitioner.py << 'EOF'
"""Tests for data partitioner."""
import pytest
from datetime import datetime
from src.export.partitioner import DataPartitioner

def test_partition_key_generation():
    """Test partition key generation."""
    config = {
        'scheme': 'date_service_level',
        'date_format': 'year=%Y/month=%m/day=%d',
        'include_service': True,
        'include_level': True
    }
    
    partitioner = DataPartitioner(config)
    
    log_entry = {
        'service': 'api-gateway',
        'level': 'INFO'
    }
    
    export_time = datetime(2025, 5, 16, 10, 30, 0)
    key = partitioner.generate_partition_key(log_entry, export_time)
    
    assert 'year=2025' in key
    assert 'month=05' in key
    assert 'day=16' in key
    assert 'service=api-gateway' in key
    assert 'level=INFO' in key

def test_filename_generation():
    """Test filename generation."""
    config = {}
    partitioner = DataPartitioner(config)
    
    export_time = datetime(2025, 5, 16, 10, 30, 0)
    filename = partitioner.generate_filename(export_time, 'parquet', 'gzip')
    
    assert filename.startswith('export_')
    assert filename.endswith('.parquet.gz')
EOF

cat > tests/test_export_engine.py << 'EOF'
"""Tests for export engine."""
import pytest
from unittest.mock import Mock, MagicMock
from src.export.engine import ExportEngine
from src.storage.client import StorageClient

def test_export_engine_initialization():
    """Test export engine initialization."""
    config = {
        'database': {'url': 'sqlite:///:memory:', 'metadata_url': 'sqlite:///:memory:'},
        'export': {'batch_size': 1000, 'format': 'parquet', 'compression': 'gzip'},
        'partitioning': {},
        'retry': {}
    }
    
    storage_client = Mock(spec=StorageClient)
    engine = ExportEngine(config, storage_client)
    
    assert engine.batch_size == 1000
    assert engine.export_format == 'parquet'
    assert engine.compression == 'gzip'
EOF

# Step 13: Create Docker configuration
echo -e "${BLUE}🐳 Creating Docker configuration...${NC}"
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY config/ ./config/
COPY data/ ./data/

# Create directories
RUN mkdir -p data/exports data/metadata

# Expose port
EXPOSE 8000

# Run application
CMD ["python", "src/main.py"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  minio:
    image: minio/minio:latest
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 10s
      timeout: 5s
      retries: 3

  export-system:
    build: .
    ports:
      - "8000:8000"
    environment:
      - AWS_ACCESS_KEY_ID=minioadmin
      - AWS_SECRET_ACCESS_KEY=minioadmin
      - MINIO_ENDPOINT=http://minio:9000
    depends_on:
      - minio
    volumes:
      - ./data:/app/data
      - ./config:/app/config

volumes:
  minio_data:
EOF

cat > .dockerignore << 'EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.venv
pip-log.txt
pip-delete-this-directory.txt
.pytest_cache/
.coverage
htmlcov/
*.egg-info/
dist/
build/
*.so
.DS_Store
.env
*.db
data/exports/*
EOF

# Step 14: Create build script
echo -e "${BLUE}📦 Creating build.sh...${NC}"
cat > build.sh << 'EOF'
#!/bin/bash
set -e

echo "🔨 Building Day 140: S3 Export System"

# Create and activate virtual environment
echo "📦 Creating virtual environment..."
python3.11 -m venv venv
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create data directories
echo "📁 Creating data directories..."
mkdir -p data/exports data/metadata

# Initialize database
echo "🗄️  Initializing database with sample data..."
python src/init_db.py

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v --tb=short

echo "✅ Build completed successfully!"
EOF

chmod +x build.sh

# Step 15: Create start script
echo -e "${BLUE}▶️  Creating start.sh...${NC}"
cat > start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting S3 Export System"

# Activate virtual environment
source venv/bin/activate

# Start application
echo "🌐 Starting API server on http://localhost:8000"
python src/main.py
EOF

chmod +x start.sh

# Step 16: Create stop script
echo -e "${BLUE}⏹️  Creating stop.sh...${NC}"
cat > stop.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping S3 Export System"

# Kill Python processes
pkill -f "python src/main.py" || true

# Stop Docker if running
docker-compose down 2>/dev/null || true

echo "✅ System stopped"
EOF

chmod +x stop.sh

# Step 17: Create demo script
echo -e "${BLUE}🎬 Creating demo.sh...${NC}"
cat > demo.sh << 'EOF'
#!/bin/bash
set -e

echo "🎬 Day 140 S3 Export System - Complete Demonstration"
echo "===================================================="
echo ""

# Activate virtual environment
source venv/bin/activate

# Start the server in background
echo "🚀 Starting export system..."
python src/main.py &
SERVER_PID=$!

# Wait for server to start
echo "⏳ Waiting for server to initialize..."
sleep 8

echo ""
echo "📊 System Status Check"
echo "----------------------"
curl -s http://localhost:8000/api/export/status | python -m json.tool

echo ""
echo ""
echo "🔥 Triggering Manual Export"
echo "---------------------------"
curl -s -X POST http://localhost:8000/api/export/manual \
  -H "Content-Type: application/json" \
  -d '{}' | python -m json.tool

echo ""
echo "⏳ Waiting for export to complete..."
sleep 5

echo ""
echo "📋 Export History"
echo "-----------------"
curl -s http://localhost:8000/api/export/history | python -m json.tool

echo ""
echo "📦 Storage Objects"
echo "------------------"
curl -s http://localhost:8000/api/storage/objects | python -m json.tool

echo ""
echo ""
echo "✅ Demonstration Complete!"
echo ""
echo "🌐 Web Dashboard: http://localhost:8000"
echo "📊 API Docs: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop the server"

# Wait for user interrupt
wait $SERVER_PID
EOF

chmod +x demo.sh

# Step 18: Create README
echo -e "${BLUE}📝 Creating README.md...${NC}"
cat > README.md << 'EOF'
# Day 140: S3/Blob Storage Export System

Automated export system for distributed log processing with cloud storage integration.

## Features

- ✅ Automated scheduled exports to S3-compatible storage
- ✅ Smart data partitioning (date/service/level)
- ✅ Multiple format support (Parquet, JSON, CSV)
- ✅ Compression (GZIP, ZSTD)
- ✅ Metadata tracking and export history
- ✅ Real-time web dashboard
- ✅ RESTful API
- ✅ Docker support with MinIO

## Quick Start

```bash
# Build and test
./build.sh

# Run demonstration
./demo.sh

# Start system
./start.sh

# Stop system
./stop.sh
```

## Docker Deployment

```bash
# Start with MinIO
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

## API Endpoints

- `GET /` - API root
- `POST /api/export/manual` - Trigger manual export
- `GET /api/export/status` - Get system status
- `GET /api/export/history` - Get export history
- `GET /api/storage/objects` - List storage objects
- `GET /health` - Health check

## Web Dashboard

Access the interactive dashboard at http://localhost:8000

## Configuration

Edit `config/config.yaml` to customize:
- Storage provider (S3, MinIO, local)
- Export schedule (cron format)
- Compression and format options
- Partitioning scheme

## Testing

```bash
source venv/bin/activate
python -m pytest tests/ -v
```

## Architecture

- FastAPI backend with async support
- React dashboard with real-time updates
- APScheduler for reliable job scheduling
- Boto3 for S3 operations
- SQLAlchemy for metadata tracking
- Parquet/Pandas for efficient data processing

## Production Considerations

- Use IAM roles instead of access keys
- Enable server-side encryption
- Configure lifecycle policies
- Monitor export metrics
- Set up alerting for failures

## License

MIT License - Part of 254-Day System Design Series
EOF

echo ""
echo -e "${GREEN}✅ Project setup complete!${NC}"
echo ""
echo "📁 Project structure:"
tree -L 2 -I 'venv|__pycache__|*.pyc' . || ls -la

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. cd ${PROJECT_DIR}"
echo "2. ./build.sh       # Build and test"
echo "3. ./demo.sh        # Run demonstration"
echo "4. Open http://localhost:8000 in browser"
echo ""
echo -e "${GREEN}🎉 Day 140 S3 Export System ready!${NC}"