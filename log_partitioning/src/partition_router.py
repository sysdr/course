import hashlib
import json
from datetime import datetime, timedelta
from typing import Dict, List, Any
import logging

class PartitionRouter:
    def __init__(self, strategy="source", nodes=None, time_window_hours=24):
        self.strategy = strategy
        self.nodes = nodes or ["node_1", "node_2", "node_3"]
        self.time_window_hours = time_window_hours
        self.partition_map = {}
        
    def route_log(self, log_entry: Dict[str, Any]) -> str:
        """Route log to appropriate partition based on strategy"""
        if self.strategy == "source":
            return self._route_by_source(log_entry)
        elif self.strategy == "time":
            return self._route_by_time(log_entry)
        else:
            raise ValueError(f"Unknown strategy: {self.strategy}")
    
    def _route_by_source(self, log_entry: Dict[str, Any]) -> str:
        source = log_entry.get("source", "unknown")
        hash_val = int(hashlib.md5(source.encode()).hexdigest(), 16)
        node_index = hash_val % len(self.nodes)
        return self.nodes[node_index]
    
    def _route_by_time(self, log_entry: Dict[str, Any]) -> str:
        timestamp = log_entry.get("timestamp", datetime.now().isoformat())
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        
        # Time-based partitioning by hours
        hour_bucket = dt.hour // (24 // len(self.nodes))
        node_index = min(hour_bucket, len(self.nodes) - 1)
        return self.nodes[node_index]
    
    def get_query_partitions(self, query_filter: Dict[str, Any]) -> List[str]:
        """Determine which partitions to query based on filter"""
        if self.strategy == "source" and "source" in query_filter:
            # Only query partition containing this source
            dummy_log = {"source": query_filter["source"]}
            return [self._route_by_source(dummy_log)]
        elif self.strategy == "time" and "time_range" in query_filter:
            # Only query partitions in time range
            return self._get_time_partitions(query_filter["time_range"])
        else:
            # Query all partitions
            return self.nodes
    
    def _get_time_partitions(self, time_range: Dict[str, str]) -> List[str]:
        start = datetime.fromisoformat(time_range["start"])
        end = datetime.fromisoformat(time_range["end"])
        
        partitions = set()
        current = start
        while current <= end:
            dummy_log = {"timestamp": current.isoformat()}
            partitions.add(self._route_by_time(dummy_log))
            current += timedelta(hours=1)
        
        return list(partitions)
