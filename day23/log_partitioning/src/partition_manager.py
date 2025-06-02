import os
import json
import threading
from typing import Dict, List, Any
from collections import defaultdict
import time

class PartitionManager:
    def __init__(self, data_dir="data"):
        self.data_dir = data_dir
        self.partitions = defaultdict(list)
        self.partition_stats = defaultdict(dict)
        self.lock = threading.Lock()
        self._ensure_data_dir()
    
    def _ensure_data_dir(self):
        os.makedirs(self.data_dir, exist_ok=True)
        for node in ["node_1", "node_2", "node_3"]:
            os.makedirs(f"{self.data_dir}/{node}", exist_ok=True)
    
    def store_log(self, partition: str, log_entry: Dict[str, Any]):
        """Store log entry in specified partition"""
        with self.lock:
            # Add to in-memory partition
            self.partitions[partition].append(log_entry)
            
            # Update partition stats
            self._update_partition_stats(partition, log_entry)
            
            # Persist to disk
            self._persist_log(partition, log_entry)
    
    def _persist_log(self, partition: str, log_entry: Dict[str, Any]):
        """Persist log entry to disk"""
        file_path = f"{self.data_dir}/{partition}/logs.jsonl"
        with open(file_path, "a") as f:
            f.write(json.dumps(log_entry) + "\n")
    
    def _update_partition_stats(self, partition: str, log_entry: Dict[str, Any]):
        """Update partition statistics"""
        stats = self.partition_stats[partition]
        stats["log_count"] = stats.get("log_count", 0) + 1
        stats["last_updated"] = time.time()
        
        # Track sources
        source = log_entry.get("source", "unknown")
        sources = stats.get("sources", set())
        sources.add(source)
        stats["sources"] = sources
    
    def query_partition(self, partition: str, filter_criteria: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Query logs from specific partition"""
        results = []
        
        with self.lock:
            for log in self.partitions[partition]:
                if self._matches_filter(log, filter_criteria):
                    results.append(log)
        
        return results
    
    def _matches_filter(self, log: Dict[str, Any], criteria: Dict[str, Any]) -> bool:
        """Check if log matches filter criteria"""
        for key, value in criteria.items():
            if key not in log:
                return False
            if key == "time_range":
                log_time = log.get("timestamp", "")
                if not (value["start"] <= log_time <= value["end"]):
                    return False
            elif log[key] != value:
                return False
        return True
    
    def get_partition_stats(self) -> Dict[str, Dict[str, Any]]:
        """Get statistics for all partitions"""
        stats = {}
        for partition, partition_stats in self.partition_stats.items():
            stats[partition] = {
                "log_count": partition_stats.get("log_count", 0),
                "sources": list(partition_stats.get("sources", set())),
                "last_updated": partition_stats.get("last_updated", 0)
            }
        return stats
