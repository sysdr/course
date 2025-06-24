import time
from typing import Dict, List, Any
from partition_router import PartitionRouter
from partition_manager import PartitionManager

class QueryOptimizer:
    def __init__(self, router: PartitionRouter, manager: PartitionManager):
        self.router = router
        self.manager = manager
        self.query_stats = []
    
    def execute_query(self, filter_criteria: Dict[str, Any]) -> Dict[str, Any]:
        """Execute optimized query across relevant partitions"""
        start_time = time.time()
        
        # Determine which partitions to query
        target_partitions = self.router.get_query_partitions(filter_criteria)
        
        # Query each relevant partition
        all_results = []
        for partition in target_partitions:
            partition_results = self.manager.query_partition(partition, filter_criteria)
            all_results.extend(partition_results)
        
        execution_time = time.time() - start_time
        
        # Record query statistics
        query_stat = {
            "filter": filter_criteria,
            "partitions_queried": target_partitions,
            "total_partitions": len(self.router.nodes),
            "results_count": len(all_results),
            "execution_time": execution_time,
            "partition_efficiency": len(target_partitions) / len(self.router.nodes)
        }
        self.query_stats.append(query_stat)
        
        return {
            "results": all_results,
            "stats": query_stat
        }
    
    def get_performance_comparison(self) -> Dict[str, Any]:
        """Generate performance comparison between optimized and brute-force"""
        if not self.query_stats:
            return {"message": "No queries executed yet"}
        
        latest_query = self.query_stats[-1]
        optimized_time = latest_query["execution_time"]
        
        # Simulate brute-force time (would query all partitions)
        brute_force_multiplier = len(self.router.nodes) / len(latest_query["partitions_queried"])
        estimated_brute_force_time = optimized_time * brute_force_multiplier
        
        improvement_factor = estimated_brute_force_time / optimized_time if optimized_time > 0 else 1
        
        return {
            "optimized_time": optimized_time,
            "estimated_brute_force_time": estimated_brute_force_time,
            "improvement_factor": improvement_factor,
            "partitions_pruned": len(self.router.nodes) - len(latest_query["partitions_queried"]),
            "efficiency_percentage": latest_query["partition_efficiency"] * 100
        }
