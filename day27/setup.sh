#!/bin/bash

# Day 27: Distributed Log Query System - Project Setup Script
# Creates project structure and files for distributed query system

set -e

echo "🚀 Setting up Distributed Log Query System - Day 27"
echo "=================================================="

# Create project directory structure
mkdir -p distributed_query_system/{src/{coordinator,executor,merger,common},tests,docker,scripts,web}

cd distributed_query_system

# Create requirements.txt
cat > requirements.txt << 'EOF'
aiohttp==3.9.5
aiofiles==23.2.1
uvloop==0.19.0
pytest==8.2.0
pytest-asyncio==0.23.6
pytest-cov==5.0.0
redis==5.0.4
structlog==24.1.0
pydantic==2.7.1
fastapi==0.111.0
uvicorn==0.29.0
websockets==12.0
python-multipart==0.0.9
jinja2==3.1.4
EOF

# Create main query types
cat > src/common/query_types.py << 'EOF'
from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional, Union
from datetime import datetime
import uuid

@dataclass
class TimeRange:
    start: datetime
    end: datetime
    
    def overlaps(self, other: 'TimeRange') -> bool:
        return self.start <= other.end and self.end >= other.start
    
    def duration_seconds(self) -> float:
        return (self.end - self.start).total_seconds()

@dataclass
class QueryFilter:
    field: str
    operator: str  # eq, ne, contains, regex, gt, lt
    value: Any
    
    def matches(self, log_entry: Dict[str, Any]) -> bool:
        if self.field not in log_entry:
            return False
            
        entry_value = log_entry[self.field]
        
        if self.operator == "eq":
            return entry_value == self.value
        elif self.operator == "ne":
            return entry_value != self.value
        elif self.operator == "contains":
            return str(self.value).lower() in str(entry_value).lower()
        elif self.operator == "gt":
            return entry_value > self.value
        elif self.operator == "lt":
            return entry_value < self.value
        
        return False

@dataclass
class Query:
    query_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    time_range: Optional[TimeRange] = None
    filters: List[QueryFilter] = field(default_factory=list)
    sort_field: str = "timestamp"
    sort_order: str = "desc"  # asc or desc
    limit: Optional[int] = None
    include_fields: List[str] = field(default_factory=list)
    exclude_fields: List[str] = field(default_factory=list)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "query_id": self.query_id,
            "time_range": {
                "start": self.time_range.start.isoformat() if self.time_range else None,
                "end": self.time_range.end.isoformat() if self.time_range else None
            },
            "filters": [
                {"field": f.field, "operator": f.operator, "value": f.value}
                for f in self.filters
            ],
            "sort_field": self.sort_field,
            "sort_order": self.sort_order,
            "limit": self.limit
        }

@dataclass
class QueryResult:
    query_id: str
    partition_id: str
    results: List[Dict[str, Any]]
    total_matches: int
    execution_time_ms: float
    errors: List[str] = field(default_factory=list)
    
    def is_successful(self) -> bool:
        return len(self.errors) == 0
        
    def to_dict(self) -> Dict[str, Any]:
        return {
            "query_id": self.query_id,
            "partition_id": self.partition_id,
            "results": self.results,
            "total_matches": self.total_matches,
            "execution_time_ms": self.execution_time_ms,
            "errors": self.errors
        }

@dataclass
class MergedQueryResult:
    query_id: str
    total_results: int
    results: List[Dict[str, Any]]
    partitions_queried: int
    partitions_successful: int
    total_execution_time_ms: float
    errors: List[str] = field(default_factory=list)
    
    def success_rate(self) -> float:
        if self.partitions_queried == 0:
            return 0.0
        return self.partitions_successful / self.partitions_queried
EOF

# Create network utilities
cat > src/common/network.py << 'EOF'
import aiohttp
import asyncio
import json
import structlog
from typing import Dict, Any, Optional, List
from datetime import datetime

logger = structlog.get_logger()

class NetworkClient:
    def __init__(self, timeout: int = 30):
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        self.session: Optional[aiohttp.ClientSession] = None
    
    async def start(self):
        """Initialize the HTTP session"""
        self.session = aiohttp.ClientSession(timeout=self.timeout)
    
    async def stop(self):
        """Close the HTTP session"""
        if self.session:
            await self.session.close()
    
    async def post_json(self, url: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Send POST request with JSON data"""
        if not self.session:
            await self.start()
            
        try:
            async with self.session.post(url, json=data) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    error_text = await response.text()
                    raise Exception(f"HTTP {response.status}: {error_text}")
        except asyncio.TimeoutError:
            raise Exception(f"Timeout connecting to {url}")
        except Exception as e:
            logger.error("Network request failed", url=url, error=str(e))
            raise

    async def get_json(self, url: str) -> Dict[str, Any]:
        """Send GET request and return JSON response"""
        if not self.session:
            await self.start()
            
        try:
            async with self.session.get(url) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    error_text = await response.text()
                    raise Exception(f"HTTP {response.status}: {error_text}")
        except asyncio.TimeoutError:
            raise Exception(f"Timeout connecting to {url}")
        except Exception as e:
            logger.error("Network request failed", url=url, error=str(e))
            raise

class PartitionInfo:
    def __init__(self, partition_id: str, host: str, port: int, 
                 time_ranges: List[Dict[str, Any]], status: str = "healthy"):
        self.partition_id = partition_id
        self.host = host
        self.port = port
        self.time_ranges = time_ranges
        self.status = status
        self.last_health_check = datetime.now()
    
    @property
    def base_url(self) -> str:
        return f"http://{self.host}:{self.port}"
    
    def covers_time_range(self, start: datetime, end: datetime) -> bool:
        """Check if this partition covers the given time range"""
        for time_range in self.time_ranges:
            range_start = datetime.fromisoformat(time_range["start"])
            range_end = datetime.fromisoformat(time_range["end"])
            
            # Check for overlap
            if start <= range_end and end >= range_start:
                return True
        return False
    
    def is_healthy(self) -> bool:
        return self.status == "healthy"
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "partition_id": self.partition_id,
            "host": self.host,
            "port": self.port,
            "time_ranges": self.time_ranges,
            "status": self.status,
            "last_health_check": self.last_health_check.isoformat()
        }
EOF

# Create partition map
cat > src/coordinator/partition_map.py << 'EOF'
import json
import asyncio
from typing import Dict, List, Set
from datetime import datetime, timedelta
import structlog
from ..common.network import NetworkClient, PartitionInfo
from ..common.query_types import TimeRange, Query

logger = structlog.get_logger()

class PartitionMap:
    def __init__(self, config_file: str = "partitions.json"):
        self.partitions: Dict[str, PartitionInfo] = {}
        self.config_file = config_file
        self.network_client = NetworkClient()
        self.health_check_interval = 30  # seconds
        self._health_check_task = None
    
    async def start(self):
        """Initialize partition map and start health checking"""
        await self.network_client.start()
        await self.load_partition_config()
        self._health_check_task = asyncio.create_task(self._health_check_loop())
        logger.info("Partition map started", partition_count=len(self.partitions))
    
    async def stop(self):
        """Stop health checking and cleanup"""
        if self._health_check_task:
            self._health_check_task.cancel()
        await self.network_client.stop()
    
    async def load_partition_config(self):
        """Load partition configuration from file"""
        try:
            with open(self.config_file, 'r') as f:
                config = json.load(f)
            
            for partition_data in config.get("partitions", []):
                partition = PartitionInfo(
                    partition_id=partition_data["partition_id"],
                    host=partition_data["host"],
                    port=partition_data["port"],
                    time_ranges=partition_data.get("time_ranges", [])
                )
                self.partitions[partition.partition_id] = partition
                
        except FileNotFoundError:
            logger.warning("Partition config file not found, starting with empty map")
        except Exception as e:
            logger.error("Failed to load partition config", error=str(e))
    
    def find_relevant_partitions(self, query: Query) -> List[PartitionInfo]:
        """Find partitions that might contain relevant data for the query"""
        relevant = []
        
        for partition in self.partitions.values():
            if not partition.is_healthy():
                continue
                
            # If query has time range, check if partition covers it
            if query.time_range:
                if partition.covers_time_range(
                    query.time_range.start, 
                    query.time_range.end
                ):
                    relevant.append(partition)
            else:
                # No time filter, all healthy partitions are relevant
                relevant.append(partition)
        
        logger.info("Found relevant partitions", 
                   query_id=query.query_id,
                   total_partitions=len(self.partitions),
                   relevant_count=len(relevant))
        
        return relevant
    
    def get_healthy_partitions(self) -> List[PartitionInfo]:
        """Get all currently healthy partitions"""
        return [p for p in self.partitions.values() if p.is_healthy()]
    
    async def _health_check_loop(self):
        """Continuously check partition health"""
        while True:
            try:
                await self._check_all_partitions_health()
                await asyncio.sleep(self.health_check_interval)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error("Health check failed", error=str(e))
                await asyncio.sleep(5)  # Brief delay before retry
    
    async def _check_all_partitions_health(self):
        """Check health of all registered partitions"""
        tasks = []
        for partition in self.partitions.values():
            task = asyncio.create_task(self._check_partition_health(partition))
            tasks.append(task)
        
        await asyncio.gather(*tasks, return_exceptions=True)
    
    async def _check_partition_health(self, partition: PartitionInfo):
        """Check health of a single partition"""
        try:
            health_url = f"{partition.base_url}/health"
            response = await self.network_client.get_json(health_url)
            
            if response.get("status") == "healthy":
                partition.status = "healthy"
            else:
                partition.status = "unhealthy"
                
            partition.last_health_check = datetime.now()
            
        except Exception as e:
            partition.status = "unreachable"
            partition.last_health_check = datetime.now()
            logger.warning("Partition health check failed", 
                         partition_id=partition.partition_id,
                         error=str(e))
    
    def get_partition_stats(self) -> Dict[str, int]:
        """Get statistics about partition health"""
        healthy = sum(1 for p in self.partitions.values() if p.status == "healthy")
        unhealthy = sum(1 for p in self.partitions.values() if p.status == "unhealthy")
        unreachable = sum(1 for p in self.partitions.values() if p.status == "unreachable")
        
        return {
            "total": len(self.partitions),
            "healthy": healthy,
            "unhealthy": unhealthy,
            "unreachable": unreachable
        }
EOF

# Create query coordinator
cat > src/coordinator/query_coordinator.py << 'EOF'
import asyncio
import time
from typing import List, Dict, Any
import structlog
from .partition_map import PartitionMap
from ..merger.result_merger import ResultMerger
from ..common.query_types import Query, QueryResult, MergedQueryResult
from ..common.network import NetworkClient

logger = structlog.get_logger()

class QueryCoordinator:
    def __init__(self, partition_map: PartitionMap):
        self.partition_map = partition_map
        self.result_merger = ResultMerger()
        self.network_client = NetworkClient()
        self.query_cache: Dict[str, MergedQueryResult] = {}
        self.max_cache_size = 1000
        self.query_timeout = 30  # seconds
    
    async def start(self):
        """Initialize the query coordinator"""
        await self.network_client.start()
        logger.info("Query coordinator started")
    
    async def stop(self):
        """Cleanup coordinator resources"""
        await self.network_client.stop()
    
    async def execute_query(self, query: Query) -> MergedQueryResult:
        """Execute a distributed query across relevant partitions"""
        start_time = time.time()
        
        # Check cache first
        cache_key = self._generate_cache_key(query)
        if cache_key in self.query_cache:
            logger.info("Query cache hit", query_id=query.query_id)
            return self.query_cache[cache_key]
        
        try:
            # Find relevant partitions
            relevant_partitions = self.partition_map.find_relevant_partitions(query)
            
            if not relevant_partitions:
                return MergedQueryResult(
                    query_id=query.query_id,
                    total_results=0,
                    results=[],
                    partitions_queried=0,
                    partitions_successful=0,
                    total_execution_time_ms=(time.time() - start_time) * 1000,
                    errors=["No healthy partitions available"]
                )
            
            # Execute queries in parallel with timeout
            partition_results = await self._execute_parallel_queries(
                query, relevant_partitions
            )
            
            # Merge results
            merged_result = await self.result_merger.merge_results(
                query, partition_results
            )
            
            # Update execution time
            merged_result.total_execution_time_ms = (time.time() - start_time) * 1000
            
            # Cache result if successful
            if merged_result.success_rate() >= 0.5:  # Cache if >50% partitions succeeded
                self._cache_result(cache_key, merged_result)
            
            logger.info("Query executed", 
                       query_id=query.query_id,
                       partitions_queried=merged_result.partitions_queried,
                       partitions_successful=merged_result.partitions_successful,
                       total_results=merged_result.total_results,
                       execution_time_ms=merged_result.total_execution_time_ms)
            
            return merged_result
            
        except Exception as e:
            logger.error("Query execution failed", 
                        query_id=query.query_id, 
                        error=str(e))
            
            return MergedQueryResult(
                query_id=query.query_id,
                total_results=0,
                results=[],
                partitions_queried=len(relevant_partitions) if 'relevant_partitions' in locals() else 0,
                partitions_successful=0,
                total_execution_time_ms=(time.time() - start_time) * 1000,
                errors=[f"Query execution failed: {str(e)}"]
            )
    
    async def _execute_parallel_queries(self, query: Query, partitions: List) -> List[QueryResult]:
        """Execute query on multiple partitions in parallel"""
        tasks = []
        
        for partition in partitions:
            task = asyncio.create_task(
                self._query_single_partition(query, partition)
            )
            tasks.append(task)
        
        # Wait for all queries with timeout
        try:
            results = await asyncio.wait_for(
                asyncio.gather(*tasks, return_exceptions=True),
                timeout=self.query_timeout
            )
            
            # Filter out exceptions and return valid results
            valid_results = []
            for result in results:
                if isinstance(result, QueryResult):
                    valid_results.append(result)
                elif isinstance(result, Exception):
                    logger.warning("Partition query failed", error=str(result))
            
            return valid_results
            
        except asyncio.TimeoutError:
            logger.warning("Query timeout exceeded", 
                          query_id=query.query_id,
                          timeout=self.query_timeout)
            
            # Cancel remaining tasks
            for task in tasks:
                if not task.done():
                    task.cancel()
            
            # Return any completed results
            completed_results = []
            for task in tasks:
                if task.done() and not task.cancelled():
                    try:
                        result = task.result()
                        if isinstance(result, QueryResult):
                            completed_results.append(result)
                    except Exception:
                        pass
            
            return completed_results
    
    async def _query_single_partition(self, query: Query, partition) -> QueryResult:
        """Execute query on a single partition"""
        start_time = time.time()
        
        try:
            query_url = f"{partition.base_url}/query"
            response = await self.network_client.post_json(
                query_url, 
                query.to_dict()
            )
            
            execution_time = (time.time() - start_time) * 1000
            
            return QueryResult(
                query_id=query.query_id,
                partition_id=partition.partition_id,
                results=response.get("results", []),
                total_matches=response.get("total_matches", 0),
                execution_time_ms=execution_time,
                errors=response.get("errors", [])
            )
            
        except Exception as e:
            execution_time = (time.time() - start_time) * 1000
            
            return QueryResult(
                query_id=query.query_id,
                partition_id=partition.partition_id,
                results=[],
                total_matches=0,
                execution_time_ms=execution_time,
                errors=[f"Partition query failed: {str(e)}"]
            )
    
    def _generate_cache_key(self, query: Query) -> str:
        """Generate a cache key for the query"""
        # Simple cache key based on query parameters
        # In production, this would be more sophisticated
        key_parts = [
            query.sort_field,
            query.sort_order,
            str(query.limit),
            str(len(query.filters))
        ]
        
        if query.time_range:
            key_parts.extend([
                query.time_range.start.isoformat(),
                query.time_range.end.isoformat()
            ])
        
        for filter_obj in query.filters:
            key_parts.extend([filter_obj.field, filter_obj.operator, str(filter_obj.value)])
        
        return "|".join(key_parts)
    
    def _cache_result(self, cache_key: str, result: MergedQueryResult):
        """Cache a query result"""
        if len(self.query_cache) >= self.max_cache_size:
            # Simple LRU: remove oldest entry
            oldest_key = next(iter(self.query_cache))
            del self.query_cache[oldest_key]
        
        self.query_cache[cache_key] = result
    
    def get_cache_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        return {
            "cache_size": len(self.query_cache),
            "max_cache_size": self.max_cache_size,
            "cache_hit_rate": "Not implemented"  # Would need hit/miss counters
        }
EOF

# Create partition executor
cat > src/executor/partition_executor.py << 'EOF'
import json
import asyncio
import time
from typing import List, Dict, Any, Optional
from datetime import datetime
import structlog
from ..common.query_types import Query, QueryFilter, TimeRange
from .query_engine import QueryEngine

logger = structlog.get_logger()

class PartitionExecutor:
    def __init__(self, partition_id: str, data_dir: str = "data"):
        self.partition_id = partition_id
        self.data_dir = data_dir
        self.query_engine = QueryEngine(data_dir)
        self.is_running = False
    
    async def start(self):
        """Initialize the partition executor"""
        await self.query_engine.initialize()
        self.is_running = True
        logger.info("Partition executor started", partition_id=self.partition_id)
    
    async def stop(self):
        """Stop the partition executor"""
        self.is_running = False
        await self.query_engine.cleanup()
    
    async def execute_query(self, query: Query) -> Dict[str, Any]:
        """Execute a query on this partition's data"""
        if not self.is_running:
            return {
                "results": [],
                "total_matches": 0,
                "errors": ["Partition executor not running"]
            }
        
        start_time = time.time()
        
        try:
            # Use query engine to search local data
            results = await self.query_engine.search(query)
            
            # Apply result limiting
            if query.limit and len(results) > query.limit:
                results = results[:query.limit]
            
            execution_time = (time.time() - start_time) * 1000
            
            logger.info("Query executed on partition",
                       partition_id=self.partition_id,
                       query_id=query.query_id,
                       results_count=len(results),
                       execution_time_ms=execution_time)
            
            return {
                "results": results,
                "total_matches": len(results),
                "execution_time_ms": execution_time,
                "errors": []
            }
            
        except Exception as e:
            execution_time = (time.time() - start_time) * 1000
            error_msg = f"Query execution failed: {str(e)}"
            
            logger.error("Partition query failed",
                        partition_id=self.partition_id,
                        query_id=query.query_id,
                        error=error_msg)
            
            return {
                "results": [],
                "total_matches": 0,
                "execution_time_ms": execution_time,
                "errors": [error_msg]
            }
    
    async def get_health_status(self) -> Dict[str, Any]:
        """Get health status of this partition"""
        try:
            stats = await self.query_engine.get_stats()
            
            return {
                "status": "healthy" if self.is_running else "unhealthy",
                "partition_id": self.partition_id,
                "uptime_seconds": time.time() - getattr(self, '_start_time', time.time()),
                "data_stats": stats
            }
            
        except Exception as e:
            return {
                "status": "unhealthy",
                "partition_id": self.partition_id,
                "error": str(e)
            }
    
    async def get_time_ranges(self) -> List[Dict[str, str]]:
        """Get time ranges covered by this partition"""
        try:
            return await self.query_engine.get_time_ranges()
        except Exception as e:
            logger.error("Failed to get time ranges", 
                        partition_id=self.partition_id,
                        error=str(e))
            return []
EOF

# Create query engine
cat > src/executor/query_engine.py << 'EOF'
import os
import json
import asyncio
import aiofiles
from typing import List, Dict, Any, Optional
from datetime import datetime
import structlog
from ..common.query_types import Query, QueryFilter, TimeRange

logger = structlog.get_logger()

class QueryEngine:
    def __init__(self, data_dir: str):
        self.data_dir = data_dir
        self.indexes: Dict[str, Dict[str, List[int]]] = {}
        self.log_files: List[str] = []
        self.loaded_data: List[Dict[str, Any]] = []
    
    async def initialize(self):
        """Initialize the query engine and load data"""
        os.makedirs(self.data_dir, exist_ok=True)
        await self._load_log_files()
        await self._build_indexes()
        logger.info("Query engine initialized", 
                   files_loaded=len(self.log_files),
                   records_loaded=len(self.loaded_data))
    
    async def cleanup(self):
        """Cleanup resources"""
        self.indexes.clear()
        self.loaded_data.clear()
        self.log_files.clear()
    
    async def _load_log_files(self):
        """Load all log files from data directory"""
        if not os.path.exists(self.data_dir):
            # Create sample data if directory doesn't exist
            await self._create_sample_data()
            return
        
        for filename in os.listdir(self.data_dir):
            if filename.endswith('.jsonl'):
                file_path = os.path.join(self.data_dir, filename)
                await self._load_single_file(file_path)
                self.log_files.append(file_path)
    
    async def _load_single_file(self, file_path: str):
        """Load a single JSONL file"""
        try:
            async with aiofiles.open(file_path, 'r') as f:
                async for line in f:
                    if line.strip():
                        log_entry = json.loads(line.strip())
                        self.loaded_data.append(log_entry)
        except Exception as e:
            logger.error("Failed to load file", file_path=file_path, error=str(e))
    
    async def _create_sample_data(self):
        """Create sample log data for testing"""
        sample_logs = []
        base_time = datetime.now()
        
        for i in range(1000):
            log_entry = {
                "timestamp": (base_time.timestamp() + i),
                "level": "INFO" if i % 3 == 0 else "ERROR" if i % 7 == 0 else "DEBUG",
                "service": f"service-{i % 5}",
                "message": f"Sample log message {i}",
                "user_id": f"user_{i % 100}",
                "request_id": f"req_{i}",
                "duration_ms": (i % 1000) + 10,
                "status_code": 200 if i % 4 == 0 else 500 if i % 13 == 0 else 404
            }
            sample_logs.append(log_entry)
        
        # Save sample data
        sample_file = os.path.join(self.data_dir, "sample_logs.jsonl")
        async with aiofiles.open(sample_file, 'w') as f:
            for log_entry in sample_logs:
                await f.write(json.dumps(log_entry) + '\n')
        
        self.loaded_data.extend(sample_logs)
        self.log_files.append(sample_file)
    
    async def _build_indexes(self):
        """Build indexes for common query fields"""
        index_fields = ["level", "service", "user_id", "status_code"]
        
        for field in index_fields:
            self.indexes[field] = {}
            
            for idx, log_entry in enumerate(self.loaded_data):
                if field in log_entry:
                    value = str(log_entry[field])
                    if value not in self.indexes[field]:
                        self.indexes[field][value] = []
                    self.indexes[field][value].append(idx)
    
    async def search(self, query: Query) -> List[Dict[str, Any]]:
        """Search for log entries matching the query"""
        # Start with all records
        matching_indices = set(range(len(self.loaded_data)))
        
        # Apply filters
        for filter_obj in query.filters:
            filter_indices = await self._apply_filter(filter_obj)
            matching_indices &= filter_indices
        
        # Apply time range filter
        if query.time_range:
            time_indices = await self._apply_time_filter(query.time_range)
            matching_indices &= time_indices
        
        # Get matching records
        results = [self.loaded_data[i] for i in matching_indices]
        
        # Sort results
        results = await self._sort_results(results, query.sort_field, query.sort_order)
        
        # Apply field selection
        if query.include_fields:
            results = self._select_fields(results, query.include_fields)
        elif query.exclude_fields:
            results = self._exclude_fields(results, query.exclude_fields)
        
        return results
    
    async def _apply_filter(self, filter_obj: QueryFilter) -> set:
        """Apply a single filter and return matching indices"""
        # Try to use index if available
        if (filter_obj.field in self.indexes and 
            filter_obj.operator == "eq"):
            
            value = str(filter_obj.value)
            if value in self.indexes[filter_obj.field]:
                return set(self.indexes[filter_obj.field][value])
            else:
                return set()
        
        # Fall back to linear scan
        matching_indices = set()
        for idx, log_entry in enumerate(self.loaded_data):
            if filter_obj.matches(log_entry):
                matching_indices.add(idx)
        
        return matching_indices
    
    async def _apply_time_filter(self, time_range: TimeRange) -> set:
        """Apply time range filter"""
        matching_indices = set()
        
        for idx, log_entry in enumerate(self.loaded_data):
            if "timestamp" in log_entry:
                entry_time = datetime.fromtimestamp(log_entry["timestamp"])
                if time_range.start <= entry_time <= time_range.end:
                    matching_indices.add(idx)
        
        return matching_indices
    
    async def _sort_results(self, results: List[Dict[str, Any]], 
                           sort_field: str, sort_order: str) -> List[Dict[str, Any]]:
        """Sort results by specified field and order"""
        try:
            reverse = (sort_order == "desc")
            
            return sorted(results, 
                         key=lambda x: x.get(sort_field, 0), 
                         reverse=reverse)
        except Exception as e:
            logger.warning("Sort failed, returning unsorted results", error=str(e))
            return results
    
    def _select_fields(self, results: List[Dict[str, Any]], 
                      include_fields: List[str]) -> List[Dict[str, Any]]:
        """Select only specified fields from results"""
        return [
            {field: entry.get(field) for field in include_fields}
            for entry in results
        ]
    
    def _exclude_fields(self, results: List[Dict[str, Any]], 
                       exclude_fields: List[str]) -> List[Dict[str, Any]]:
        """Exclude specified fields from results"""
        return [
            {k: v for k, v in entry.items() if k not in exclude_fields}
            for entry in results
        ]
    
    async def get_stats(self) -> Dict[str, Any]:
        """Get statistics about loaded data"""
        return {
            "total_records": len(self.loaded_data),
            "files_loaded": len(self.log_files),
            "indexes_built": len(self.indexes),
            "index_fields": list(self.indexes.keys())
        }
    
    async def get_time_ranges(self) -> List[Dict[str, str]]:
        """Get time ranges covered by this partition's data"""
        if not self.loaded_data:
            return []
        
        timestamps = [
            entry.get("timestamp", 0) 
            for entry in self.loaded_data 
            if "timestamp" in entry
        ]
        
        if not timestamps:
            return []
        
        min_time = min(timestamps)
        max_time = max(timestamps)
        
        return [{
            "start": datetime.fromtimestamp(min_time).isoformat(),
            "end": datetime.fromtimestamp(max_time).isoformat()
        }]
EOF

# Create result merger
cat > src/merger/result_merger.py << 'EOF'
import asyncio
import heapq
from typing import List, Dict, Any, Iterator
from datetime import datetime
import structlog
from ..common.query_types import Query, QueryResult, MergedQueryResult

logger = structlog.get_logger()

class ResultMerger:
    def __init__(self):
        self.max_merge_size = 100000  # Maximum results to merge
    
    async def merge_results(self, query: Query, 
                           partition_results: List[QueryResult]) -> MergedQueryResult:
        """Merge results from multiple partitions"""
        
        successful_results = [r for r in partition_results if r.is_successful()]
        all_errors = []
        
        # Collect errors from failed partitions
        for result in partition_results:
            all_errors.extend(result.errors)
        
        if not successful_results:
            return MergedQueryResult(
                query_id=query.query_id,
                total_results=0,
                results=[],
                partitions_queried=len(partition_results),
                partitions_successful=0,
                total_execution_time_ms=0,
                errors=all_errors
            )
        
        # Merge results based on sort requirements
        if query.sort_field and successful_results:
            merged_results = await self._merge_sorted_results(
                query, successful_results
            )
        else:
            merged_results = await self._merge_unsorted_results(
                successful_results
            )
        
        # Apply global limit if specified
        if query.limit and len(merged_results) > query.limit:
            merged_results = merged_results[:query.limit]
        
        total_results = sum(r.total_matches for r in successful_results)
        
        return MergedQueryResult(
            query_id=query.query_id,
            total_results=len(merged_results),
            results=merged_results,
            partitions_queried=len(partition_results),
            partitions_successful=len(successful_results),
            total_execution_time_ms=0,  # Will be set by coordinator
            errors=all_errors
        )
    
    async def _merge_sorted_results(self, query: Query, 
                                  results: List[QueryResult]) -> List[Dict[str, Any]]:
        """Merge sorted results using heap-based merge"""
        
        # Create iterators for each partition's results
        iterators = []
        for result in results:
            if result.results:
                iterator = iter(result.results)
                try:
                    first_item = next(iterator)
                    sort_key = self._get_sort_key(first_item, query.sort_field)
                    heapq.heappush(iterators, (sort_key, first_item, iterator, result.partition_id))
                except StopIteration:
                    continue
        
        merged = []
        reverse_order = (query.sort_order == "desc")
        
        while iterators and len(merged) < self.max_merge_size:
            # Get the next item based on sort order
            if reverse_order:
                # For descending order, negate the sort key
                sort_key, item, iterator, partition_id = heapq.heappop(iterators)
                merged.append(item)
                
                # Try to get next item from this iterator
                try:
                    next_item = next(iterator)
                    next_sort_key = self._get_sort_key(next_item, query.sort_field)
                    heapq.heappush(iterators, (next_sort_key, next_item, iterator, partition_id))
                except StopIteration:
                    continue
            else:
                # For ascending order, use normal heap behavior
                sort_key, item, iterator, partition_id = heapq.heappop(iterators)
                merged.append(item)
                
                try:
                    next_item = next(iterator)
                    next_sort_key = self._get_sort_key(next_item, query.sort_field)
                    heapq.heappush(iterators, (next_sort_key, next_item, iterator, partition_id))
                except StopIteration:
                    continue
        
        # If we need descending order, we collected in ascending order
        # so we need to reverse (this is a simplified approach)
        if reverse_order:
            # Actually implement proper descending merge
            return await self._merge_descending_results(query, results)
        
        return merged
    
    async def _merge_descending_results(self, query: Query,
                                      results: List[QueryResult]) -> List[Dict[str, Any]]:
        """Handle descending order merge by collecting and sorting"""
        all_results = []
        
        for result in results:
            all_results.extend(result.results)
        
        # Sort all results
        try:
            reverse = (query.sort_order == "desc")
            sorted_results = sorted(
                all_results,
                key=lambda x: self._get_sort_key(x, query.sort_field),
                reverse=reverse
            )
            return sorted_results
            
        except Exception as e:
            logger.warning("Failed to sort merged results", error=str(e))
            return all_results
    
    async def _merge_unsorted_results(self, results: List[QueryResult]) -> List[Dict[str, Any]]:
        """Simple concatenation for unsorted results"""
        merged = []
        
        for result in results:
            merged.extend(result.results)
            
            if len(merged) > self.max_merge_size:
                merged = merged[:self.max_merge_size]
                break
        
        return merged
    
    def _get_sort_key(self, item: Dict[str, Any], sort_field: str) -> Any:
        """Extract sort key from item"""
        value = item.get(sort_field)
        
        if value is None:
            return 0  # Default value for missing fields
        
        # Handle timestamp fields
        if sort_field == "timestamp" and isinstance(value, (int, float)):
            return value
        
        # Handle string fields
        if isinstance(value, str):
            return value.lower()
        
        return value
    
    async def stream_merge_results(self, query: Query,
                                 results: List[QueryResult]) -> Iterator[Dict[str, Any]]:
        """Stream merged results for large result sets"""
        # This would be implemented for streaming scenarios
        # For now, fall back to regular merge
        merged = await self.merge_results(query, results)
        for item in merged.results:
            yield item
EOF

# Create web interface files
cat > web/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Distributed Log Query System</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 1px solid #eee;
        }
        .query-form {
            display: grid;
            gap: 15px;
            margin-bottom: 30px;
        }
        .form-group {
            display: flex;
            flex-direction: column;
        }
        label {
            font-weight: bold;
            margin-bottom: 5px;
            color: #333;
        }
        input, select, textarea {
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
        }
        button {
            background-color: #007bff;
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background-color: #0056b3;
        }
        .results {
            margin-top: 20px;
        }
        .result-item {
            background: #f8f9fa;
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 4px;
            border-left: 4px solid #007bff;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: #e9ecef;
            padding: 15px;
            border-radius: 4px;
            text-align: center;
        }
        .error {
            color: #dc3545;
            background: #f8d7da;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .loading {
            text-align: center;
            padding: 20px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Distributed Log Query System</h1>
            <p>Query logs across multiple partitions</p>
        </div>

        <div class="stats" id="stats">
            <!-- Stats will be populated by JavaScript -->
        </div>

        <form class="query-form" id="queryForm">
            <div class="form-group">
                <label for="timeStart">Start Time (ISO format):</label>
                <input type="datetime-local" id="timeStart" name="timeStart">
            </div>
            
            <div class="form-group">
                <label for="timeEnd">End Time (ISO format):</label>
                <input type="datetime-local" id="timeEnd" name="timeEnd">
            </div>

            <div class="form-group">
                <label for="filterField">Filter Field:</label>
                <select id="filterField" name="filterField">
                    <option value="">-- No Filter --</option>
                    <option value="level">Log Level</option>
                    <option value="service">Service</option>
                    <option value="user_id">User ID</option>
                    <option value="status_code">Status Code</option>
                </select>
            </div>

            <div class="form-group">
                <label for="filterOperator">Filter Operator:</label>
                <select id="filterOperator" name="filterOperator">
                    <option value="eq">Equals</option>
                    <option value="ne">Not Equals</option>
                    <option value="contains">Contains</option>
                    <option value="gt">Greater Than</option>
                    <option value="lt">Less Than</option>
                </select>
            </div>

            <div class="form-group">
                <label for="filterValue">Filter Value:</label>
                <input type="text" id="filterValue" name="filterValue" placeholder="Enter filter value">
            </div>

            <div class="form-group">
                <label for="sortField">Sort Field:</label>
                <select id="sortField" name="sortField">
                    <option value="timestamp">Timestamp</option>
                    <option value="level">Level</option>
                    <option value="service">Service</option>
                    <option value="duration_ms">Duration</option>
                </select>
            </div>

            <div class="form-group">
                <label for="sortOrder">Sort Order:</label>
                <select id="sortOrder" name="sortOrder">
                    <option value="desc">Descending</option>
                    <option value="asc">Ascending</option>
                </select>
            </div>

            <div class="form-group">
                <label for="limit">Limit Results:</label>
                <input type="number" id="limit" name="limit" value="50" min="1" max="1000">
            </div>

            <button type="submit">Execute Query</button>
        </form>

        <div class="results" id="results">
            <!-- Query results will appear here -->
        </div>
    </div>

    <script>
        const API_BASE = 'http://localhost:8080';

        // Load initial stats
        async function loadStats() {
            try {
                const response = await fetch(`${API_BASE}/stats`);
                const stats = await response.json();
                
                document.getElementById('stats').innerHTML = `
                    <div class="stat-card">
                        <h3>${stats.partitions.total}</h3>
                        <p>Total Partitions</p>
                    </div>
                    <div class="stat-card">
                        <h3>${stats.partitions.healthy}</h3>
                        <p>Healthy Partitions</p>
                    </div>
                    <div class="stat-card">
                        <h3>${stats.cache.cache_size}</h3>
                        <p>Cached Queries</p>
                    </div>
                `;
            } catch (error) {
                console.error('Failed to load stats:', error);
            }
        }

        // Handle form submission
        document.getElementById('queryForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const resultsDiv = document.getElementById('results');
            resultsDiv.innerHTML = '<div class="loading">Executing query...</div>';
            
            try {
                const formData = new FormData(e.target);
                const query = buildQuery(formData);
                
                const response = await fetch(`${API_BASE}/query`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(query)
                });
                
                const result = await response.json();
                displayResults(result);
                
            } catch (error) {
                resultsDiv.innerHTML = `<div class="error">Query failed: ${error.message}</div>`;
            }
        });

        function buildQuery(formData) {
            const query = {
                sort_field: formData.get('sortField'),
                sort_order: formData.get('sortOrder'),
                limit: parseInt(formData.get('limit')),
                filters: []
            };

            // Add time range if specified
            const timeStart = formData.get('timeStart');
            const timeEnd = formData.get('timeEnd');
            
            if (timeStart && timeEnd) {
                query.time_range = {
                    start: new Date(timeStart).toISOString(),
                    end: new Date(timeEnd).toISOString()
                };
            }

            // Add filter if specified
            const filterField = formData.get('filterField');
            const filterValue = formData.get('filterValue');
            
            if (filterField && filterValue) {
                query.filters.push({
                    field: filterField,
                    operator: formData.get('filterOperator'),
                    value: filterValue
                });
            }

            return query;
        }

        function displayResults(result) {
            const resultsDiv = document.getElementById('results');
            
            if (result.errors && result.errors.length > 0) {
                resultsDiv.innerHTML = `<div class="error">Errors: ${result.errors.join(', ')}</div>`;
                return;
            }

            let html = `
                <h3>Query Results</h3>
                <p>Found ${result.total_results} results in ${result.total_execution_time_ms.toFixed(2)}ms</p>
                <p>Queried ${result.partitions_queried} partitions, ${result.partitions_successful} successful</p>
            `;

            if (result.results && result.results.length > 0) {
                result.results.forEach(item => {
                    html += `
                        <div class="result-item">
                            <strong>Timestamp:</strong> ${new Date(item.timestamp * 1000).toISOString()}<br>
                            <strong>Level:</strong> ${item.level}<br>
                            <strong>Service:</strong> ${item.service}<br>
                            <strong>Message:</strong> ${item.message}<br>
                            <strong>Status Code:</strong> ${item.status_code}
                        </div>
                    `;
                });
            } else {
                html += '<p>No results found.</p>';
            }

            resultsDiv.innerHTML = html;
        }

        // Load stats on page load
        loadStats();
        
        // Refresh stats every 30 seconds
        setInterval(loadStats, 30000);
    </script>
</body>
</html>
EOF

# Create main application files
cat > src/main.py << 'EOF'
import asyncio
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import structlog
from datetime import datetime
from typing import Dict, Any, Optional

from coordinator.query_coordinator import QueryCoordinator
from coordinator.partition_map import PartitionMap
from common.query_types import Query, TimeRange, QueryFilter

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

app = FastAPI(title="Distributed Log Query System", version="1.0.0")

# Global components
partition_map: Optional[PartitionMap] = None
query_coordinator: Optional[QueryCoordinator] = None

@app.on_event("startup")
async def startup_event():
    """Initialize the query system on startup"""
    global partition_map, query_coordinator
    
    logger.info("Starting distributed log query system")
    
    # Initialize partition map
    partition_map = PartitionMap()
    await partition_map.start()
    
    # Initialize query coordinator
    query_coordinator = QueryCoordinator(partition_map)
    await query_coordinator.start()
    
    logger.info("System startup complete")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    global partition_map, query_coordinator
    
    logger.info("Shutting down distributed log query system")
    
    if query_coordinator:
        await query_coordinator.stop()
    
    if partition_map:
        await partition_map.stop()
    
    logger.info("System shutdown complete")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "distributed-log-query-coordinator"
    }

@app.post("/query")
async def execute_query(query_data: Dict[str, Any]):
    """Execute a distributed query"""
    if not query_coordinator:
        raise HTTPException(status_code=503, detail="Query coordinator not initialized")
    
    try:
        # Parse query data
        query = parse_query_data(query_data)
        
        # Execute query
        result = await query_coordinator.execute_query(query)
        
        return {
            "query_id": result.query_id,
            "total_results": result.total_results,
            "results": result.results,
            "partitions_queried": result.partitions_queried,
            "partitions_successful": result.partitions_successful,
            "total_execution_time_ms": result.total_execution_time_ms,
            "errors": result.errors
        }
        
    except Exception as e:
        logger.error("Query execution failed", error=str(e))
        raise HTTPException(status_code=500, detail=f"Query failed: {str(e)}")

@app.get("/stats")
async def get_stats():
    """Get system statistics"""
    if not partition_map or not query_coordinator:
        raise HTTPException(status_code=503, detail="System not initialized")
    
    partition_stats = partition_map.get_partition_stats()
    cache_stats = query_coordinator.get_cache_stats()
    
    return {
        "partitions": partition_stats,
        "cache": cache_stats,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/partitions")
async def get_partitions():
    """Get information about all partitions"""
    if not partition_map:
        raise HTTPException(status_code=503, detail="Partition map not initialized")
    
    partitions = partition_map.get_healthy_partitions()
    
    return {
        "partitions": [p.to_dict() for p in partitions],
        "total_count": len(partitions)
    }

def parse_query_data(query_data: Dict[str, Any]) -> Query:
    """Parse query data from request"""
    query = Query()
    
    # Parse time range
    if "time_range" in query_data and query_data["time_range"]:
        time_range_data = query_data["time_range"]
        if time_range_data.get("start") and time_range_data.get("end"):
            query.time_range = TimeRange(
                start=datetime.fromisoformat(time_range_data["start"].replace('Z', '+00:00')),
                end=datetime.fromisoformat(time_range_data["end"].replace('Z', '+00:00'))
            )
    
    # Parse filters
    if "filters" in query_data:
        for filter_data in query_data["filters"]:
            query_filter = QueryFilter(
                field=filter_data["field"],
                operator=filter_data["operator"],
                value=filter_data["value"]
            )
            query.filters.append(query_filter)
    
    # Parse other fields
    if "sort_field" in query_data:
        query.sort_field = query_data["sort_field"]
    
    if "sort_order" in query_data:
        query.sort_order = query_data["sort_order"]
    
    if "limit" in query_data:
        query.limit = query_data["limit"]
    
    return query

# Mount static files for web interface
app.mount("/static", StaticFiles(directory="web"), name="static")

@app.get("/", response_class=HTMLResponse)
async def get_web_interface():
    """Serve the web interface"""
    with open("web/index.html", "r") as f:
        return HTMLResponse(content=f.read())

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info"
    )
EOF

# Create partition server for testing
cat > src/partition_server.py << 'EOF'
import asyncio
import uvicorn
from fastapi import FastAPI, HTTPException
import structlog
from datetime import datetime
from typing import Dict, Any
import sys
import os

from executor.partition_executor import PartitionExecutor
from common.query_types import Query, TimeRange, QueryFilter

logger = structlog.get_logger()

class PartitionServer:
    def __init__(self, partition_id: str, port: int, data_dir: str = None):
        self.partition_id = partition_id
        self.port = port
        self.data_dir = data_dir or f"data/partition_{partition_id}"
        self.app = FastAPI(title=f"Partition Server {partition_id}")
        self.executor: PartitionExecutor = None
        
        self._setup_routes()
    
    def _setup_routes(self):
        @self.app.on_event("startup")
        async def startup():
            os.makedirs(self.data_dir, exist_ok=True)
            self.executor = PartitionExecutor(self.partition_id, self.data_dir)
            await self.executor.start()
            logger.info("Partition server started", 
                       partition_id=self.partition_id,
                       port=self.port)
        
        @self.app.on_event("shutdown")
        async def shutdown():
            if self.executor:
                await self.executor.stop()
        
        @self.app.get("/health")
        async def health():
            if self.executor:
                return await self.executor.get_health_status()
            return {"status": "starting"}
        
        @self.app.post("/query")
        async def query(query_data: Dict[str, Any]):
            if not self.executor:
                raise HTTPException(status_code=503, detail="Executor not ready")
            
            try:
                query = self._parse_query(query_data)
                result = await self.executor.execute_query(query)
                return result
            except Exception as e:
                logger.error("Query failed", partition_id=self.partition_id, error=str(e))
                raise HTTPException(status_code=500, detail=str(e))
        
        @self.app.get("/time-ranges")
        async def time_ranges():
            if not self.executor:
                raise HTTPException(status_code=503, detail="Executor not ready")
            
            return await self.executor.get_time_ranges()
    
    def _parse_query(self, query_data: Dict[str, Any]) -> Query:
        """Parse query data into Query object"""
        query = Query()
        
        if "time_range" in query_data and query_data["time_range"]:
            time_range_data = query_data["time_range"]
            if time_range_data.get("start") and time_range_data.get("end"):
                query.time_range = TimeRange(
                    start=datetime.fromisoformat(time_range_data["start"].replace('Z', '+00:00')),
                    end=datetime.fromisoformat(time_range_data["end"].replace('Z', '+00:00'))
                )
        
        if "filters" in query_data:
            for filter_data in query_data["filters"]:
                query_filter = QueryFilter(
                    field=filter_data["field"],
                    operator=filter_data["operator"],
                    value=filter_data["value"]
                )
                query.filters.append(query_filter)
        
        query.sort_field = query_data.get("sort_field", "timestamp")
        query.sort_order = query_data.get("sort_order", "desc")
        query.limit = query_data.get("limit")
        
        return query
    
    def run(self):
        uvicorn.run(
            self.app,
            host="0.0.0.0",
            port=self.port,
            log_level="info"
        )

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python partition_server.py <partition_id> <port>")
        sys.exit(1)
    
    partition_id = sys.argv[1]
    port = int(sys.argv[2])
    
    server = PartitionServer(partition_id, port)
    server.run()
EOF

# Create configuration files
cat > partitions.json << 'EOF'
{
    "partitions": [
        {
            "partition_id": "partition_1",
            "host": "localhost",
            "port": 8081,
            "time_ranges": [
                {
                    "start": "2024-01-01T00:00:00",
                    "end": "2024-12-31T23:59:59"
                }
            ]
        },
        {
            "partition_id": "partition_2",
            "host": "localhost",
            "port": 8082,
            "time_ranges": [
                {
                    "start": "2024-01-01T00:00:00",
                    "end": "2024-12-31T23:59:59"
                }
            ]
        }
    ]
}
EOF

# Create basic tests
cat > tests/test_query_coordinator.py << 'EOF'
import pytest
import asyncio
from datetime import datetime, timedelta
from src.coordinator.query_coordinator import QueryCoordinator
from src.coordinator.partition_map import PartitionMap
from src.common.query_types import Query, TimeRange, QueryFilter

@pytest.mark.asyncio
async def test_query_coordinator_initialization():
    """Test that query coordinator initializes properly"""
    partition_map = PartitionMap("test_partitions.json")
    coordinator = QueryCoordinator(partition_map)
    
    await coordinator.start()
    assert coordinator.network_client is not None
    
    await coordinator.stop()

@pytest.mark.asyncio 
async def test_empty_query():
    """Test query with no partitions available"""
    partition_map = PartitionMap("nonexistent.json")
    coordinator = QueryCoordinator(partition_map)
    
    await coordinator.start()
    
    query = Query()
    result = await coordinator.execute_query(query)
    
    assert result.total_results == 0
    assert result.partitions_queried == 0
    assert len(result.errors) > 0
    
    await coordinator.stop()

@pytest.mark.asyncio
async def test_cache_functionality():
    """Test query result caching"""
    partition_map = PartitionMap("test_partitions.json")
    coordinator = QueryCoordinator(partition_map)
    
    await coordinator.start()
    
    # Create a simple query
    query = Query(
        sort_field="timestamp",
        sort_order="desc",
        limit=10
    )
    
    # Generate cache key
    cache_key = coordinator._generate_cache_key(query)
    assert isinstance(cache_key, str)
    assert len(cache_key) > 0
    
    await coordinator.stop()

if __name__ == "__main__":
    pytest.main([__file__])
EOF

cat > tests/test_query_engine.py << 'EOF'
import pytest
import asyncio
import tempfile
import os
from src.executor.query_engine import QueryEngine
from src.common.query_types import Query, QueryFilter, TimeRange
from datetime import datetime

@pytest.mark.asyncio
async def test_query_engine_initialization():
    """Test query engine initialization"""
    with tempfile.TemporaryDirectory() as temp_dir:
        engine = QueryEngine(temp_dir)
        await engine.initialize()
        
        stats = await engine.get_stats()
        assert stats["total_records"] > 0
        assert stats["files_loaded"] > 0
        
        await engine.cleanup()

@pytest.mark.asyncio
async def test_basic_search():
    """Test basic search functionality"""
    with tempfile.TemporaryDirectory() as temp_dir:
        engine = QueryEngine(temp_dir)
        await engine.initialize()
        
        # Create a simple query
        query = Query()
        results = await engine.search(query)
        
        assert isinstance(results, list)
        assert len(results) > 0
        
        await engine.cleanup()

@pytest.mark.asyncio
async def test_filtered_search():
    """Test search with filters"""
    with tempfile.TemporaryDirectory() as temp_dir:
        engine = QueryEngine(temp_dir)
        await engine.initialize()
        
        # Create query with filter
        query = Query()
        query.filters.append(QueryFilter(
            field="level",
            operator="eq",
            value="ERROR"
        ))
        
        results = await engine.search(query)
        
        # All results should match the filter
        for result in results:
            assert result.get("level") == "ERROR"
        
        await engine.cleanup()

@pytest.mark.asyncio
async def test_time_range_search():
    """Test search with time range"""
    with tempfile.TemporaryDirectory() as temp_dir:
        engine = QueryEngine(temp_dir)
        await engine.initialize()
        
        # Get time ranges from data
        time_ranges = await engine.get_time_ranges()
        if time_ranges:
            start_time = datetime.fromisoformat(time_ranges[0]["start"])
            end_time = datetime.fromisoformat(time_ranges[0]["end"])
            
            query = Query()
            query.time_range = TimeRange(start=start_time, end=end_time)
            
            results = await engine.search(query)
            assert isinstance(results, list)
        
        await engine.cleanup()

if __name__ == "__main__":
    pytest.main([__file__])
EOF

# Create test configuration
cat > tests/test_partitions.json << 'EOF'
{
    "partitions": [
        {
            "partition_id": "test_partition_1",
            "host": "localhost",
            "port": 9001,
            "time_ranges": [
                {
                    "start": "2024-01-01T00:00:00",
                    "end": "2024-06-30T23:59:59"
                }
            ]
        }
    ]
}
EOF

# Create __init__.py files
touch src/__init__.py
touch src/coordinator/__init__.py
touch src/executor/__init__.py
touch src/merger/__init__.py
touch src/common/__init__.py
touch tests/__init__.py

# Create pytest configuration
cat > pytest.ini << 'EOF'
[tool:pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short
asyncio_mode = auto
EOF

echo "✅ Project structure created successfully!"
echo "📁 Directory structure:"
tree distributed_query_system/ || find distributed_query_system/ -type f | sort

echo ""
echo "🎯 Next steps:"
echo "1. Run: bash 2_build_test_local.sh"
echo "2. Run: bash 3_build_test_docker.sh" 
echo "3. Run: bash 4_verify_system.sh"