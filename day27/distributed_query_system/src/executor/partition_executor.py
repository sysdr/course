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
