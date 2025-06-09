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
