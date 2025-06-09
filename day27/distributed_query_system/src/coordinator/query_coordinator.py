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
