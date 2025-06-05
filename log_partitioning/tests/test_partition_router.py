import unittest
from datetime import datetime
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.partition_router import PartitionRouter

class TestPartitionRouter(unittest.TestCase):
    
    def setUp(self):
        self.source_router = PartitionRouter(strategy="source")
        self.time_router = PartitionRouter(strategy="time")
    
    def test_source_routing_consistency(self):
        """Test that same source always routes to same partition"""
        log1 = {"source": "web_server", "timestamp": "2024-01-01T10:00:00"}
        log2 = {"source": "web_server", "timestamp": "2024-01-02T15:30:00"}
        
        partition1 = self.source_router.route_log(log1)
        partition2 = self.source_router.route_log(log2)
        
        self.assertEqual(partition1, partition2)
    
    def test_different_sources_distribution(self):
        """Test that different sources can map to different partitions"""
        sources = ["web_server", "database", "auth_service", "cache", "api_gateway"]
        partitions = set()
        
        for source in sources:
            log = {"source": source, "timestamp": "2024-01-01T10:00:00"}
            partition = self.source_router.route_log(log)
            partitions.add(partition)
        
        # Should have distribution across partitions
        self.assertGreater(len(partitions), 1)
    
    def test_time_routing_same_bucket(self):
        """Test that logs in same time bucket go to same partition"""
        log1 = {"source": "web_server", "timestamp": "2024-01-01T10:00:00"}
        log2 = {"source": "database", "timestamp": "2024-01-01T10:30:00"}
        
        partition1 = self.time_router.route_log(log1)
        partition2 = self.time_router.route_log(log2)
        
        self.assertEqual(partition1, partition2)
    
    def test_query_partition_pruning_source(self):
        """Test query optimization for source-based partitioning"""
        partitions = self.source_router.get_query_partitions({"source": "web_server"})
        
        # Should return only one partition for specific source
        self.assertEqual(len(partitions), 1)
    
    def test_query_partition_pruning_time(self):
        """Test query optimization for time-based partitioning"""
        time_filter = {
            "time_range": {
                "start": "2024-01-01T10:00:00",
                "end": "2024-01-01T12:00:00"
            }
        }
        partitions = self.time_router.get_query_partitions(time_filter)
        
        # Should return limited partitions for time range
        self.assertLessEqual(len(partitions), 3)

if __name__ == "__main__":
    unittest.main()
