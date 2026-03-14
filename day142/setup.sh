#!/bin/bash

# Day 142: Elasticsearch Integration for Advanced Log Search
# Complete Implementation Script
# This script creates the full project, builds, tests, and demonstrates the system

set -e  # Exit on any error

echo "🚀 Day 142: Elasticsearch Integration Setup"
echo "=========================================="

# Project setup
PROJECT_NAME="elasticsearch-log-integration"
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

echo "📁 Creating project structure..."
mkdir -p {src/{indexer,search,api,dashboard},tests,config,scripts,docker,data,logs}

# Create requirements.txt
cat > requirements.txt << 'EOF'
elasticsearch==8.13.0
pika==1.3.2
fastapi==0.111.0
uvicorn==0.30.1
aiohttp==3.9.5
pydantic==2.7.1
python-dateutil==2.9.0
pytest==8.2.2
pytest-asyncio==0.23.7
requests==2.32.3
websockets==12.0
jinja2==3.1.4
structlog==24.1.0
colorama==0.4.6
pyyaml==6.0.1
EOF

# Configuration file
cat > config/elasticsearch_config.yaml << 'EOF'
elasticsearch:
  hosts:
    - http://localhost:9200
  index_prefix: "logs"
  batch_size: 100
  bulk_timeout: 5
  max_retries: 3
  
rabbitmq:
  host: localhost
  port: 5672
  exchange: logs_topic
  queue: elasticsearch_indexing
  routing_key: "logs.*.#"
  
indexing:
  flush_interval: 2
  max_queue_size: 1000
  daily_indices: true
  retention_days: 30
  
api:
  host: 0.0.0.0
  port: 8000
  cors_origins: ["*"]
  
dashboard:
  refresh_interval: 5
  max_results: 100
EOF

# Main indexer implementation
cat > src/indexer/log_indexer.py << 'EOF'
import asyncio
import json
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from elasticsearch import AsyncElasticsearch, helpers
from elasticsearch.exceptions import ConnectionError, TransportError
import structlog

logger = structlog.get_logger()

class LogIndexer:
    """Handles bulk indexing of logs to Elasticsearch"""
    
    def __init__(self, es_client: AsyncElasticsearch, config: Dict[str, Any]):
        self.es = es_client
        self.config = config
        self.batch: List[Dict] = []
        self.index_prefix = config.get('index_prefix', 'logs')
        self.batch_size = config.get('batch_size', 100)
        self.last_flush = datetime.now()
        self.flush_interval = config.get('flush_interval', 2)
        self.stats = {
            'indexed': 0,
            'failed': 0,
            'batches': 0
        }
        
    async def add_log(self, log_entry: Dict[str, Any]) -> bool:
        """Add log to indexing batch"""
        try:
            # Enrich log with indexing metadata
            doc = self._prepare_document(log_entry)
            self.batch.append(doc)
            
            # Check if batch is ready to flush
            if len(self.batch) >= self.batch_size:
                await self.flush_batch()
                
            return True
            
        except Exception as e:
            logger.error("add_log_failed", error=str(e), log=log_entry)
            self.stats['failed'] += 1
            return False
    
    def _prepare_document(self, log_entry: Dict[str, Any]) -> Dict[str, Any]:
        """Prepare log document for Elasticsearch indexing"""
        timestamp = log_entry.get('timestamp', datetime.now().isoformat())
        
        # Parse timestamp if string
        if isinstance(timestamp, str):
            try:
                dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            except:
                dt = datetime.now()
        else:
            dt = timestamp
            
        # Determine index name (daily indices)
        index_name = f"{self.index_prefix}-{dt.strftime('%Y.%m.%d')}"
        
        # Prepare document
        doc = {
            '_index': index_name,
            '_source': {
                '@timestamp': dt.isoformat(),
                'message': log_entry.get('message', ''),
                'level': log_entry.get('level', 'INFO'),
                'service': log_entry.get('service', 'unknown'),
                'component': log_entry.get('component', ''),
                'metadata': log_entry.get('metadata', {}),
                'tags': log_entry.get('tags', []),
                'indexed_at': datetime.now().isoformat()
            }
        }
        
        # Add custom fields from metadata
        if 'response_time' in log_entry.get('metadata', {}):
            doc['_source']['response_time_ms'] = log_entry['metadata']['response_time']
        
        if 'status_code' in log_entry.get('metadata', {}):
            doc['_source']['status_code'] = log_entry['metadata']['status_code']
            
        return doc
    
    async def flush_batch(self) -> Dict[str, int]:
        """Flush current batch to Elasticsearch"""
        if not self.batch:
            return {'indexed': 0, 'failed': 0}
            
        logger.info("flushing_batch", size=len(self.batch))
        
        try:
            # Bulk index using helpers
            success, failed = await helpers.async_bulk(
                self.es,
                self.batch,
                raise_on_error=False,
                raise_on_exception=False
            )
            
            self.stats['indexed'] += success
            self.stats['failed'] += len(failed) if isinstance(failed, list) else 0
            self.stats['batches'] += 1
            
            logger.info("batch_flushed", 
                       success=success, 
                       failed=len(failed) if isinstance(failed, list) else 0,
                       total_indexed=self.stats['indexed'])
            
            self.batch.clear()
            self.last_flush = datetime.now()
            
            return {'indexed': success, 'failed': len(failed) if isinstance(failed, list) else 0}
            
        except Exception as e:
            logger.error("flush_failed", error=str(e))
            self.stats['failed'] += len(self.batch)
            self.batch.clear()
            return {'indexed': 0, 'failed': len(self.batch)}
    
    async def periodic_flush(self):
        """Background task to flush based on time interval"""
        while True:
            await asyncio.sleep(self.flush_interval)
            
            time_since_flush = (datetime.now() - self.last_flush).total_seconds()
            if self.batch and time_since_flush >= self.flush_interval:
                await self.flush_batch()
    
    def get_stats(self) -> Dict[str, int]:
        """Get indexing statistics"""
        return self.stats.copy()
EOF

# Index manager for lifecycle management
cat > src/indexer/index_manager.py << 'EOF'
from datetime import datetime, timedelta
from typing import Dict, List
from elasticsearch import AsyncElasticsearch
import structlog

logger = structlog.get_logger()

class IndexManager:
    """Manages Elasticsearch index lifecycle"""
    
    def __init__(self, es_client: AsyncElasticsearch, config: Dict):
        self.es = es_client
        self.index_prefix = config.get('index_prefix', 'logs')
        self.retention_days = config.get('retention_days', 30)
        
    async def create_index_template(self):
        """Create index template for log indices"""
        template = {
            "index_patterns": [f"{self.index_prefix}-*"],
            "template": {
                "settings": {
                    "number_of_shards": 1,
                    "number_of_replicas": 0,
                    "refresh_interval": "5s",
                    "index.mapping.total_fields.limit": 2000
                },
                "mappings": {
                    "properties": {
                        "@timestamp": {"type": "date"},
                        "message": {
                            "type": "text",
                            "fields": {"keyword": {"type": "keyword", "ignore_above": 256}}
                        },
                        "level": {"type": "keyword"},
                        "service": {"type": "keyword"},
                        "component": {"type": "keyword"},
                        "response_time_ms": {"type": "integer"},
                        "status_code": {"type": "integer"},
                        "tags": {"type": "keyword"},
                        "indexed_at": {"type": "date"}
                    }
                }
            }
        }
        
        try:
            await self.es.indices.put_index_template(
                name=f"{self.index_prefix}_template",
                body=template
            )
            logger.info("index_template_created", prefix=self.index_prefix)
            return True
        except Exception as e:
            logger.error("template_creation_failed", error=str(e))
            return False
    
    async def ensure_today_index(self) -> str:
        """Ensure today's index exists"""
        index_name = f"{self.index_prefix}-{datetime.now().strftime('%Y.%m.%d')}"
        
        try:
            exists = await self.es.indices.exists(index=index_name)
            if not exists:
                await self.es.indices.create(index=index_name)
                logger.info("index_created", index=index_name)
            return index_name
        except Exception as e:
            logger.error("index_ensure_failed", error=str(e), index=index_name)
            return index_name
    
    async def cleanup_old_indices(self) -> int:
        """Delete indices older than retention period"""
        cutoff_date = datetime.now() - timedelta(days=self.retention_days)
        deleted_count = 0
        
        try:
            # Get all indices matching prefix
            indices = await self.es.indices.get(index=f"{self.index_prefix}-*")
            
            for index_name in indices:
                try:
                    # Extract date from index name
                    date_str = index_name.split('-', 1)[1]
                    index_date = datetime.strptime(date_str, '%Y.%m.%d')
                    
                    if index_date < cutoff_date:
                        await self.es.indices.delete(index=index_name)
                        logger.info("index_deleted", index=index_name)
                        deleted_count += 1
                except (ValueError, IndexError) as e:
                    logger.warning("index_date_parse_failed", index=index_name, error=str(e))
                    
            return deleted_count
            
        except Exception as e:
            logger.error("cleanup_failed", error=str(e))
            return deleted_count
    
    async def get_index_stats(self) -> List[Dict]:
        """Get statistics for all log indices"""
        try:
            stats = await self.es.indices.stats(index=f"{self.index_prefix}-*")
            
            indices_info = []
            for index_name, index_stats in stats['indices'].items():
                indices_info.append({
                    'name': index_name,
                    'docs': index_stats['primaries']['docs']['count'],
                    'size': index_stats['primaries']['store']['size_in_bytes'],
                    'size_mb': round(index_stats['primaries']['store']['size_in_bytes'] / 1024 / 1024, 2)
                })
                
            return sorted(indices_info, key=lambda x: x['name'], reverse=True)
            
        except Exception as e:
            logger.error("stats_failed", error=str(e))
            return []
EOF

# Search engine implementation
cat > src/search/search_engine.py << 'EOF'
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
from elasticsearch import AsyncElasticsearch
import structlog

logger = structlog.get_logger()

class SearchEngine:
    """Handles search operations on indexed logs"""
    
    def __init__(self, es_client: AsyncElasticsearch, config: Dict):
        self.es = es_client
        self.index_prefix = config.get('index_prefix', 'logs')
        self.max_results = config.get('max_results', 100)
    
    async def search_logs(self, 
                         query: Optional[str] = None,
                         level: Optional[str] = None,
                         service: Optional[str] = None,
                         time_range_minutes: int = 60,
                         size: int = 50) -> Dict[str, Any]:
        """Search logs with various filters"""
        
        # Build query
        must_clauses = []
        
        # Time range filter
        time_filter = {
            "range": {
                "@timestamp": {
                    "gte": f"now-{time_range_minutes}m",
                    "lte": "now"
                }
            }
        }
        must_clauses.append(time_filter)
        
        # Text search
        if query:
            must_clauses.append({
                "match": {
                    "message": {
                        "query": query,
                        "operator": "and"
                    }
                }
            })
        
        # Level filter
        if level:
            must_clauses.append({"term": {"level": level}})
        
        # Service filter
        if service:
            must_clauses.append({"term": {"service": service}})
        
        # Execute search
        search_body = {
            "query": {
                "bool": {
                    "must": must_clauses
                }
            },
            "sort": [{"@timestamp": {"order": "desc"}}],
            "size": min(size, self.max_results)
        }
        
        try:
            result = await self.es.search(
                index=f"{self.index_prefix}-*",
                body=search_body
            )
            
            hits = result['hits']['hits']
            logs = [self._format_hit(hit) for hit in hits]
            
            return {
                'total': result['hits']['total']['value'],
                'logs': logs,
                'took_ms': result['took']
            }
            
        except Exception as e:
            logger.error("search_failed", error=str(e))
            return {'total': 0, 'logs': [], 'took_ms': 0}
    
    async def aggregate_by_level(self, time_range_minutes: int = 60) -> Dict[str, int]:
        """Aggregate log counts by level"""
        agg_body = {
            "query": {
                "range": {
                    "@timestamp": {
                        "gte": f"now-{time_range_minutes}m"
                    }
                }
            },
            "aggs": {
                "levels": {
                    "terms": {
                        "field": "level",
                        "size": 10
                    }
                }
            },
            "size": 0
        }
        
        try:
            result = await self.es.search(
                index=f"{self.index_prefix}-*",
                body=agg_body
            )
            
            buckets = result['aggregations']['levels']['buckets']
            return {bucket['key']: bucket['doc_count'] for bucket in buckets}
            
        except Exception as e:
            logger.error("aggregation_failed", error=str(e))
            return {}
    
    async def aggregate_over_time(self, 
                                  interval: str = "1m",
                                  time_range_minutes: int = 60) -> List[Dict]:
        """Get log volume over time"""
        agg_body = {
            "query": {
                "range": {
                    "@timestamp": {
                        "gte": f"now-{time_range_minutes}m"
                    }
                }
            },
            "aggs": {
                "logs_over_time": {
                    "date_histogram": {
                        "field": "@timestamp",
                        "fixed_interval": interval,
                        "min_doc_count": 0
                    }
                }
            },
            "size": 0
        }
        
        try:
            result = await self.es.search(
                index=f"{self.index_prefix}-*",
                body=agg_body
            )
            
            buckets = result['aggregations']['logs_over_time']['buckets']
            return [
                {
                    'timestamp': bucket['key_as_string'],
                    'count': bucket['doc_count']
                }
                for bucket in buckets
            ]
            
        except Exception as e:
            logger.error("time_aggregation_failed", error=str(e))
            return []
    
    def _format_hit(self, hit: Dict) -> Dict:
        """Format Elasticsearch hit for API response"""
        source = hit['_source']
        return {
            'id': hit['_id'],
            'timestamp': source.get('@timestamp'),
            'level': source.get('level'),
            'service': source.get('service'),
            'message': source.get('message'),
            'metadata': source.get('metadata', {}),
            'score': hit['_score']
        }
EOF

# RabbitMQ consumer for indexing
cat > src/indexer/consumer.py << 'EOF'
import asyncio
import json
import pika
from typing import Callable, Dict
import structlog

logger = structlog.get_logger()

class IndexingConsumer:
    """Consumes logs from RabbitMQ and sends to indexer"""
    
    def __init__(self, rabbitmq_config: Dict, indexer):
        self.config = rabbitmq_config
        self.indexer = indexer
        self.connection = None
        self.channel = None
        self.consuming = False
        
    def connect(self):
        """Connect to RabbitMQ"""
        try:
            self.connection = pika.BlockingConnection(
                pika.ConnectionParameters(
                    host=self.config['host'],
                    port=self.config['port']
                )
            )
            self.channel = self.connection.channel()
            
            # Declare exchange and queue
            self.channel.exchange_declare(
                exchange=self.config['exchange'],
                exchange_type='topic',
                durable=True
            )
            
            self.channel.queue_declare(
                queue=self.config['queue'],
                durable=True
            )
            
            self.channel.queue_bind(
                queue=self.config['queue'],
                exchange=self.config['exchange'],
                routing_key=self.config['routing_key']
            )
            
            logger.info("rabbitmq_connected", 
                       exchange=self.config['exchange'],
                       queue=self.config['queue'])
            return True
            
        except Exception as e:
            logger.error("rabbitmq_connection_failed", error=str(e))
            return False
    
    def start_consuming(self, callback: Callable):
        """Start consuming messages"""
        self.channel.basic_qos(prefetch_count=10)
        self.channel.basic_consume(
            queue=self.config['queue'],
            on_message_callback=callback,
            auto_ack=False
        )
        
        self.consuming = True
        logger.info("started_consuming", queue=self.config['queue'])
        
        try:
            self.channel.start_consuming()
        except KeyboardInterrupt:
            self.stop_consuming()
    
    def stop_consuming(self):
        """Stop consuming messages"""
        if self.channel and self.consuming:
            self.channel.stop_consuming()
            self.consuming = False
            logger.info("stopped_consuming")
    
    def close(self):
        """Close connection"""
        if self.connection:
            self.connection.close()
            logger.info("rabbitmq_closed")
EOF

# FastAPI application
cat > src/api/app.py << 'EOF'
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
from typing import Optional
from pydantic import BaseModel
import structlog

logger = structlog.get_logger()

app = FastAPI(title="Elasticsearch Log Search API")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global search engine reference (set by main)
search_engine = None
index_manager = None
log_indexer = None

class SearchRequest(BaseModel):
    query: Optional[str] = None
    level: Optional[str] = None
    service: Optional[str] = None
    time_range_minutes: int = 60
    size: int = 50

@app.get("/")
async def root():
    """Root endpoint"""
    return {"message": "Elasticsearch Log Search API", "status": "running"}

@app.post("/api/search")
async def search(request: SearchRequest):
    """Search logs"""
    if not search_engine:
        raise HTTPException(status_code=503, detail="Search engine not initialized")
    
    result = await search_engine.search_logs(
        query=request.query,
        level=request.level,
        service=request.service,
        time_range_minutes=request.time_range_minutes,
        size=request.size
    )
    
    return result

@app.get("/api/search")
async def search_get(
    q: Optional[str] = Query(None, description="Search query"),
    level: Optional[str] = Query(None, description="Log level filter"),
    service: Optional[str] = Query(None, description="Service filter"),
    time_range: int = Query(60, description="Time range in minutes"),
    size: int = Query(50, description="Number of results")
):
    """Search logs via GET"""
    if not search_engine:
        raise HTTPException(status_code=503, detail="Search engine not initialized")
    
    result = await search_engine.search_logs(
        query=q,
        level=level,
        service=service,
        time_range_minutes=time_range,
        size=size
    )
    
    return result

@app.get("/api/aggregations/levels")
async def aggregate_levels(time_range: int = Query(60, description="Time range in minutes")):
    """Get log counts by level"""
    if not search_engine:
        raise HTTPException(status_code=503, detail="Search engine not initialized")
    
    result = await search_engine.aggregate_by_level(time_range_minutes=time_range)
    return result

@app.get("/api/aggregations/timeline")
async def aggregate_timeline(
    interval: str = Query("1m", description="Time interval (1m, 5m, 1h)"),
    time_range: int = Query(60, description="Time range in minutes")
):
    """Get log volume over time"""
    if not search_engine:
        raise HTTPException(status_code=503, detail="Search engine not initialized")
    
    result = await search_engine.aggregate_over_time(
        interval=interval,
        time_range_minutes=time_range
    )
    return result

@app.get("/api/stats/indexing")
async def indexing_stats():
    """Get indexing statistics"""
    if not log_indexer:
        raise HTTPException(status_code=503, detail="Indexer not initialized")
    
    stats = log_indexer.get_stats()
    return stats

@app.get("/api/stats/indices")
async def indices_stats():
    """Get index statistics"""
    if not index_manager:
        raise HTTPException(status_code=503, detail="Index manager not initialized")
    
    stats = await index_manager.get_index_stats()
    return {'indices': stats}

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "components": {
            "search_engine": search_engine is not None,
            "index_manager": index_manager is not None,
            "log_indexer": log_indexer is not None
        }
    }
EOF

# Dashboard HTML
cat > src/dashboard/dashboard.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Elasticsearch Log Search Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
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
            padding: 25px;
            border-radius: 12px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        
        .header h1 {
            color: #667eea;
            font-size: 28px;
            margin-bottom: 5px;
        }
        
        .header p {
            color: #666;
            font-size: 14px;
        }
        
        .search-panel {
            background: white;
            padding: 25px;
            border-radius: 12px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        
        .search-controls {
            display: grid;
            grid-template-columns: 2fr 1fr 1fr 1fr auto;
            gap: 15px;
            margin-bottom: 15px;
        }
        
        input, select, button {
            padding: 12px;
            border: 2px solid #e2e8f0;
            border-radius: 8px;
            font-size: 14px;
            transition: all 0.3s;
        }
        
        input:focus, select:focus {
            outline: none;
            border-color: #667eea;
        }
        
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            cursor: pointer;
            font-weight: 600;
        }
        
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        
        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 12px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.1);
        }
        
        .stat-value {
            font-size: 32px;
            font-weight: 700;
            margin-bottom: 5px;
        }
        
        .stat-label {
            color: #666;
            font-size: 14px;
        }
        
        .results-panel {
            background: white;
            padding: 25px;
            border-radius: 12px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.1);
        }
        
        .log-entry {
            border-left: 4px solid #667eea;
            padding: 15px;
            margin-bottom: 15px;
            background: #f8fafc;
            border-radius: 8px;
            transition: transform 0.2s;
        }
        
        .log-entry:hover {
            transform: translateX(5px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }
        
        .log-header {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            align-items: center;
        }
        
        .log-level {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .log-level-ERROR {
            background: #fee;
            color: #c33;
        }
        
        .log-level-WARN {
            background: #fffbeb;
            color: #d97706;
        }
        
        .log-level-INFO {
            background: #eff6ff;
            color: #2563eb;
        }
        
        .log-timestamp {
            color: #666;
            font-size: 12px;
        }
        
        .log-message {
            color: #333;
            line-height: 1.6;
            margin-top: 10px;
        }
        
        .log-meta {
            display: flex;
            gap: 20px;
            margin-top: 10px;
            font-size: 12px;
            color: #666;
        }
        
        .loading {
            text-align: center;
            padding: 40px;
            color: #667eea;
        }
        
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: #666;
        }
        
        .chart-container {
            background: white;
            padding: 25px;
            border-radius: 12px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Elasticsearch Log Search</h1>
            <p>Real-time log search and analytics powered by Elasticsearch</p>
        </div>
        
        <div class="search-panel">
            <div class="search-controls">
                <input type="text" id="searchQuery" placeholder="Search logs..." />
                <select id="levelFilter">
                    <option value="">All Levels</option>
                    <option value="ERROR">ERROR</option>
                    <option value="WARN">WARN</option>
                    <option value="INFO">INFO</option>
                    <option value="DEBUG">DEBUG</option>
                </select>
                <select id="serviceFilter">
                    <option value="">All Services</option>
                    <option value="api">API</option>
                    <option value="database">Database</option>
                    <option value="auth">Auth</option>
                </select>
                <select id="timeRange">
                    <option value="15">Last 15 min</option>
                    <option value="60" selected>Last 1 hour</option>
                    <option value="180">Last 3 hours</option>
                    <option value="1440">Last 24 hours</option>
                </select>
                <button onclick="performSearch()">Search</button>
            </div>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value" id="totalLogs">0</div>
                <div class="stat-label">Total Results</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" style="color: #ef4444;" id="errorCount">0</div>
                <div class="stat-label">Errors</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" style="color: #f59e0b;" id="warnCount">0</div>
                <div class="stat-label">Warnings</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" style="color: #10b981;" id="indexedCount">0</div>
                <div class="stat-label">Indexed</div>
            </div>
        </div>
        
        <div class="results-panel">
            <h2 style="margin-bottom: 20px; color: #333;">Search Results</h2>
            <div id="resultsContainer">
                <div class="empty-state">
                    <p>Enter a search query or click Search to see results</p>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        const API_BASE = window.location.origin;
        
        async function performSearch() {
            const query = document.getElementById('searchQuery').value;
            const level = document.getElementById('levelFilter').value;
            const service = document.getElementById('serviceFilter').value;
            const timeRange = document.getElementById('timeRange').value;
            
            const container = document.getElementById('resultsContainer');
            container.innerHTML = '<div class="loading">Searching...</div>';
            
            try {
                const params = new URLSearchParams({
                    time_range: timeRange,
                    size: 50
                });
                
                if (query) params.append('q', query);
                if (level) params.append('level', level);
                if (service) params.append('service', service);
                
                const response = await fetch(`${API_BASE}/api/search?${params}`);
                const data = await response.json();
                
                displayResults(data);
                await updateStats();
                
            } catch (error) {
                container.innerHTML = `<div class="empty-state">Error: ${error.message}</div>`;
            }
        }
        
        function displayResults(data) {
            const container = document.getElementById('resultsContainer');
            document.getElementById('totalLogs').textContent = data.total;
            
            if (data.logs.length === 0) {
                container.innerHTML = '<div class="empty-state">No logs found</div>';
                return;
            }
            
            container.innerHTML = data.logs.map(log => `
                <div class="log-entry">
                    <div class="log-header">
                        <span class="log-level log-level-${log.level}">${log.level}</span>
                        <span class="log-timestamp">${new Date(log.timestamp).toLocaleString()}</span>
                    </div>
                    <div class="log-message">${escapeHtml(log.message)}</div>
                    <div class="log-meta">
                        <span>📦 ${log.service}</span>
                        <span>🔖 Score: ${log.score.toFixed(2)}</span>
                    </div>
                </div>
            `).join('');
        }
        
        async function updateStats() {
            try {
                const [levels, indexing] = await Promise.all([
                    fetch(`${API_BASE}/api/aggregations/levels`).then(r => r.json()),
                    fetch(`${API_BASE}/api/stats/indexing`).then(r => r.json())
                ]);
                
                document.getElementById('errorCount').textContent = levels.ERROR || 0;
                document.getElementById('warnCount').textContent = levels.WARN || 0;
                document.getElementById('indexedCount').textContent = indexing.indexed || 0;
            } catch (error) {
                console.error('Stats update failed:', error);
            }
        }
        
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        // Auto-refresh stats
        setInterval(updateStats, 10000);
        updateStats();
        
        // Search on Enter key
        document.getElementById('searchQuery').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') performSearch();
        });
    </script>
</body>
</html>
EOF

# Main application
cat > src/main.py << 'EOF'
import asyncio
import json
import yaml
import sys
from pathlib import Path
from elasticsearch import AsyncElasticsearch
import structlog

# Import components
sys.path.append(str(Path(__file__).parent))
from indexer.log_indexer import LogIndexer
from indexer.index_manager import IndexManager
from indexer.consumer import IndexingConsumer
from search.search_engine import SearchEngine
import api.app as api_app

# Setup logging
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.processors.JSONRenderer()
    ]
)
logger = structlog.get_logger()

class ElasticsearchIntegration:
    """Main application coordinator"""
    
    def __init__(self, config_path: str = 'config/elasticsearch_config.yaml'):
        with open(config_path) as f:
            self.config = yaml.safe_load(f)
        
        self.es = None
        self.indexer = None
        self.index_manager = None
        self.search_engine = None
        self.consumer = None
        
    async def initialize(self):
        """Initialize all components"""
        logger.info("initializing_elasticsearch_integration")
        
        # Connect to Elasticsearch
        self.es = AsyncElasticsearch(
            hosts=self.config['elasticsearch']['hosts']
        )
        
        # Test connection
        if not await self.es.ping():
            raise ConnectionError("Cannot connect to Elasticsearch")
        
        logger.info("elasticsearch_connected")
        
        # Initialize managers
        self.index_manager = IndexManager(self.es, self.config['elasticsearch'])
        await self.index_manager.create_index_template()
        await self.index_manager.ensure_today_index()
        
        # Initialize indexer
        self.indexer = LogIndexer(self.es, self.config['elasticsearch'])
        
        # Initialize search engine
        self.search_engine = SearchEngine(self.es, self.config['elasticsearch'])
        
        # Set API references
        api_app.search_engine = self.search_engine
        api_app.index_manager = self.index_manager
        api_app.log_indexer = self.indexer
        
        logger.info("all_components_initialized")
        
    async def start_indexing(self):
        """Start background indexing"""
        # Start periodic flush
        asyncio.create_task(self.indexer.periodic_flush())
        logger.info("indexing_started")
        
    def start_consumer(self):
        """Start RabbitMQ consumer"""
        self.consumer = IndexingConsumer(
            self.config['rabbitmq'],
            self.indexer
        )
        
        if self.consumer.connect():
            def on_message(ch, method, properties, body):
                try:
                    log_entry = json.loads(body)
                    asyncio.run(self.indexer.add_log(log_entry))
                    ch.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    logger.error("message_processing_failed", error=str(e))
                    ch.basic_nack(delivery_tag=method.delivery_tag)
            
            self.consumer.start_consuming(on_message)
    
    async def close(self):
        """Cleanup resources"""
        if self.indexer:
            await self.indexer.flush_batch()
        if self.consumer:
            self.consumer.close()
        if self.es:
            await self.es.close()
        logger.info("cleanup_complete")

async def main():
    integration = ElasticsearchIntegration()
    
    try:
        await integration.initialize()
        await integration.start_indexing()
        
        logger.info("elasticsearch_integration_ready")
        
        # Start API server
        import uvicorn
        config = uvicorn.Config(
            api_app.app,
            host=integration.config['api']['host'],
            port=integration.config['api']['port'],
            log_level="info"
        )
        server = uvicorn.Server(config)
        await server.serve()
        
    except KeyboardInterrupt:
        logger.info("shutting_down")
    finally:
        await integration.close()

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Test data generator
cat > src/generate_test_logs.py << 'EOF'
import json
import random
import pika
from datetime import datetime, timedelta

class LogGenerator:
    def __init__(self):
        self.connection = pika.BlockingConnection(
            pika.ConnectionParameters('localhost', 5672)
        )
        self.channel = self.connection.channel()
        
        self.channel.exchange_declare(
            exchange='logs_topic',
            exchange_type='topic',
            durable=True
        )
        
        self.services = ['api', 'database', 'auth', 'payment']
        self.levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
        self.messages = [
            'User login successful',
            'Database query executed',
            'Payment processed',
            'Authentication failed',
            'Connection timeout',
            'Invalid request format',
            'Cache miss',
            'Rate limit exceeded'
        ]
    
    def generate_log(self) -> dict:
        service = random.choice(self.services)
        level = random.choice(self.levels)
        
        return {
            'timestamp': (datetime.now() - timedelta(
                minutes=random.randint(0, 60)
            )).isoformat(),
            'level': level,
            'service': service,
            'component': f'{service}_handler',
            'message': random.choice(self.messages),
            'metadata': {
                'response_time': random.randint(10, 500),
                'status_code': random.choice([200, 400, 404, 500]),
                'user_id': f'user_{random.randint(1000, 9999)}'
            },
            'tags': [service, level.lower()]
        }
    
    def send_logs(self, count: int = 100):
        print(f"Generating {count} test logs...")
        
        for i in range(count):
            log = self.generate_log()
            routing_key = f"logs.{log['service']}.{log['level'].lower()}"
            
            self.channel.basic_publish(
                exchange='logs_topic',
                routing_key=routing_key,
                body=json.dumps(log)
            )
            
            if (i + 1) % 10 == 0:
                print(f"Sent {i + 1}/{count} logs")
        
        print(f"✅ Successfully sent {count} logs")
        self.connection.close()

if __name__ == "__main__":
    generator = LogGenerator()
    generator.send_logs(100)
EOF

# Pytest tests
cat > tests/test_indexer.py << 'EOF'
import pytest
from unittest.mock import Mock, AsyncMock, patch
from datetime import datetime
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent.parent / 'src'))

from indexer.log_indexer import LogIndexer

@pytest.mark.asyncio
async def test_log_indexer_initialization():
    """Test indexer initialization"""
    mock_es = AsyncMock()
    config = {'index_prefix': 'test-logs', 'batch_size': 10}
    
    indexer = LogIndexer(mock_es, config)
    
    assert indexer.index_prefix == 'test-logs'
    assert indexer.batch_size == 10
    assert len(indexer.batch) == 0

@pytest.mark.asyncio  
async def test_add_log():
    """Test adding log to batch"""
    mock_es = AsyncMock()
    config = {'index_prefix': 'logs', 'batch_size': 100}
    
    indexer = LogIndexer(mock_es, config)
    
    log = {
        'timestamp': datetime.now().isoformat(),
        'level': 'INFO',
        'message': 'Test log',
        'service': 'test'
    }
    
    result = await indexer.add_log(log)
    
    assert result == True
    assert len(indexer.batch) == 1

@pytest.mark.asyncio
async def test_batch_flush():
    """Test batch flushing"""
    mock_es = AsyncMock()
    config = {'index_prefix': 'logs', 'batch_size': 2}
    
    with patch('elasticsearch.helpers.async_bulk', return_value=(2, [])):
        indexer = LogIndexer(mock_es, config)
        
        await indexer.add_log({'message': 'test1', 'level': 'INFO', 'service': 'test'})
        await indexer.add_log({'message': 'test2', 'level': 'INFO', 'service': 'test'})
        
        assert indexer.stats['indexed'] >= 0

@pytest.mark.asyncio
async def test_document_preparation():
    """Test document preparation"""
    mock_es = AsyncMock()
    config = {'index_prefix': 'logs', 'batch_size': 100}
    
    indexer = LogIndexer(mock_es, config)
    
    log = {
        'timestamp': '2025-06-16T10:00:00',
        'level': 'ERROR',
        'message': 'Test error',
        'service': 'api',
        'component': 'handler',
        'metadata': {'response_time': 250}
    }
    
    doc = indexer._prepare_document(log)
    
    assert '_index' in doc
    assert doc['_index'].startswith('logs-2025')
    assert doc['_source']['level'] == 'ERROR'
    assert doc['_source']['response_time_ms'] == 250
EOF

cat > tests/test_search.py << 'EOF'
import pytest
from unittest.mock import AsyncMock
from datetime import datetime
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent.parent / 'src'))

from search.search_engine import SearchEngine

@pytest.mark.asyncio
async def test_search_engine_initialization():
    """Test search engine initialization"""
    mock_es = AsyncMock()
    config = {'index_prefix': 'logs', 'max_results': 100}
    
    engine = SearchEngine(mock_es, config)
    
    assert engine.index_prefix == 'logs'
    assert engine.max_results == 100

@pytest.mark.asyncio
async def test_search_logs():
    """Test log searching"""
    mock_es = AsyncMock()
    mock_es.search = AsyncMock(return_value={
        'hits': {
            'total': {'value': 1},
            'hits': [{
                '_id': '1',
                '_source': {
                    '@timestamp': '2025-06-16T10:00:00',
                    'level': 'ERROR',
                    'message': 'Test error',
                    'service': 'api'
                },
                '_score': 1.0
            }]
        },
        'took': 15
    })
    
    config = {'index_prefix': 'logs', 'max_results': 100}
    engine = SearchEngine(mock_es, config)
    
    result = await engine.search_logs(query='error', level='ERROR')
    
    assert result['total'] == 1
    assert len(result['logs']) == 1
    assert result['logs'][0]['level'] == 'ERROR'

@pytest.mark.asyncio
async def test_aggregate_by_level():
    """Test level aggregation"""
    mock_es = AsyncMock()
    mock_es.search = AsyncMock(return_value={
        'aggregations': {
            'levels': {
                'buckets': [
                    {'key': 'ERROR', 'doc_count': 10},
                    {'key': 'INFO', 'doc_count': 50}
                ]
            }
        }
    })
    
    config = {'index_prefix': 'logs'}
    engine = SearchEngine(mock_es, config)
    
    result = await engine.aggregate_by_level()
    
    assert result['ERROR'] == 10
    assert result['INFO'] == 50
EOF

# Build script
cat > scripts/build.sh << 'EOF'
#!/bin/bash
set -e

echo "🔨 Building Elasticsearch Integration..."

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt

echo "✅ Build complete!"
EOF

chmod +x scripts/build.sh

# Test script
cat > scripts/test.sh << 'EOF'
#!/bin/bash
set -e

echo "🧪 Running tests..."

source venv/bin/activate

# Run pytest
python -m pytest tests/ -v

echo "✅ All tests passed!"
EOF

chmod +x scripts/test.sh

# Start script
cat > scripts/start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Elasticsearch Integration..."

# Check if Elasticsearch is running
if ! curl -s http://localhost:9200 > /dev/null; then
    echo "❌ Elasticsearch not running. Starting with Docker..."
    docker run -d --name elasticsearch \
        -p 9200:9200 -p 9300:9300 \
        -e "discovery.type=single-node" \
        -e "xpack.security.enabled=false" \
        docker.elastic.co/elasticsearch/elasticsearch:8.13.0
    
    echo "⏳ Waiting for Elasticsearch to be ready..."
    sleep 30
fi

# Check if RabbitMQ is running  
if ! curl -s http://localhost:15672 > /dev/null; then
    echo "❌ RabbitMQ not running. Starting with Docker..."
    docker run -d --name rabbitmq \
        -p 5672:5672 -p 15672:15672 \
        rabbitmq:3.12-management
    
    echo "⏳ Waiting for RabbitMQ to be ready..."
    sleep 15
fi

source venv/bin/activate

# Start API server
echo "🌐 Starting API server..."
python src/main.py &
API_PID=$!

sleep 5

echo "✅ Services started!"
echo "📊 Dashboard: http://localhost:8000/dashboard"
echo "🔍 API: http://localhost:8000/api/search"
echo "💚 Health: http://localhost:8000/health"
echo ""
echo "Press Ctrl+C to stop"

# Wait for interrupt
trap "kill $API_PID; exit" INT
wait $API_PID
EOF

chmod +x scripts/start.sh

# Demo script  
cat > scripts/demo.sh << 'EOF'
#!/bin/bash
set -e

echo "🎬 Running Elasticsearch Integration Demo..."

source venv/bin/activate

# Wait for services
echo "⏳ Waiting for services to be ready..."
sleep 10

# Generate test logs
echo "📝 Generating test logs..."
python src/generate_test_logs.py

echo "⏳ Waiting for logs to be indexed..."
sleep 15

# Test search
echo "🔍 Testing search functionality..."
echo ""
echo "Search for 'error' logs:"
curl -s "http://localhost:8000/api/search?q=error&size=5" | python -m json.tool

echo ""
echo "Get log level aggregations:"
curl -s "http://localhost:8000/api/aggregations/levels" | python -m json.tool

echo ""
echo "Get indexing statistics:"
curl -s "http://localhost:8000/api/stats/indexing" | python -m json.tool

echo ""
echo "✅ Demo complete!"
echo "🌐 Open http://localhost:8000/dashboard for interactive search"
EOF

chmod +x scripts/demo.sh

# Docker Compose
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.13.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
      - "9300:9300"
    volumes:
      - es_data:/usr/share/elasticsearch/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9200"]
      interval: 10s
      timeout: 5s
      retries: 5

  rabbitmq:
    image: rabbitmq:3.12-management-alpine
    ports:
      - "5672:5672"
      - "15672:15672"
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build: .
    depends_on:
      elasticsearch:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
    ports:
      - "8000:8000"
    volumes:
      - ./config:/app/config
      - ./logs:/app/logs
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - RABBITMQ_HOST=rabbitmq

volumes:
  es_data:
EOF

# Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY config/ ./config/

EXPOSE 8000

CMD ["python", "src/main.py"]
EOF

# .dockerignore
cat > .dockerignore << 'EOF'
venv/
__pycache__/
*.pyc
.pytest_cache/
.git/
data/
logs/
*.log
EOF

# Serve dashboard
cat > src/api/dashboard_routes.py << 'EOF'
from fastapi import APIRouter
from fastapi.responses import FileResponse
from pathlib import Path

router = APIRouter()

@router.get("/dashboard")
async def serve_dashboard():
    """Serve the dashboard HTML"""
    dashboard_path = Path(__file__).parent.parent / "dashboard" / "dashboard.html"
    return FileResponse(dashboard_path)
EOF

# Update app.py to include dashboard route
cat >> src/api/app.py << 'EOF'

from .dashboard_routes import router as dashboard_router
app.include_router(dashboard_router)
EOF

# README
cat > README.md << 'EOF'
# Day 142: Elasticsearch Integration for Log Search

Production-ready Elasticsearch integration for distributed log processing.

## Features
- Real-time log indexing with bulk operations
- Full-text search and structured queries
- Time-based indices with automatic management
- Real-time aggregations and analytics
- Modern web dashboard

## Quick Start

```bash
# Build
./scripts/build.sh

# Start services
./scripts/start.sh

# Run demo
./scripts/demo.sh
```

## Docker Deployment

```bash
docker-compose up -d
```

## API Endpoints

- GET /api/search - Search logs
- GET /api/aggregations/levels - Level counts
- GET /api/aggregations/timeline - Log volume over time
- GET /api/stats/indexing - Indexing statistics
- GET /dashboard - Interactive web UI

## Testing

```bash
./scripts/test.sh
```
EOF

echo ""
echo "✅ Project setup complete!"
echo ""
echo "Next steps:"
echo "1. ./scripts/build.sh     - Build the project"
echo "2. ./scripts/start.sh     - Start services"
echo "3. ./scripts/demo.sh      - Run demonstration"
echo ""
echo "Or use Docker:"
echo "docker-compose up -d"
echo ""
echo "Dashboard: http://localhost:8000/dashboard"