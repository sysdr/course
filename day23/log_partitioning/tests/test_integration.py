import unittest
import tempfile
import shutil
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.log_partitioning_system import LogPartitioningSystem

class TestIntegration(unittest.TestCase):
    
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.system = LogPartitioningSystem("source")
        self.system.manager.data_dir = self.temp_dir
        self.system.manager._ensure_data_dir()
    
    def tearDown(self):
        shutil.rmtree(self.temp_dir)
    
    def test_end_to_end_workflow(self):
        """Test complete workflow from ingestion to query"""
        # Generate sample logs
        logs = self.system.generate_sample_logs(100)
        
        # Ingest logs
        for log in logs:
            self.system.ingest_log(log)
        
        # Verify logs were distributed
        stats = self.system.manager.get_partition_stats()
        total_logs = sum(stat['log_count'] for stat in stats.values())
        self.assertEqual(total_logs, 100)
        
        # Test query optimization
        query_result = self.system.optimizer.execute_query({"source": "web_server"})
        
        # Should find some results and show efficiency
        self.assertGreater(len(query_result['results']), 0)
        self.assertLessEqual(len(query_result['stats']['partitions_queried']), 3)
    
    def test_performance_improvement(self):
        """Test that partitioning shows performance improvement"""
        # Generate and ingest logs
        logs = self.system.generate_sample_logs(500)
        for log in logs:
            self.system.ingest_log(log)
        
        # Execute query
        self.system.optimizer.execute_query({"source": "database"})
        
        # Check performance metrics
        perf = self.system.optimizer.get_performance_comparison()
        self.assertGreater(perf['improvement_factor'], 1.0)
        self.assertGreater(perf['efficiency_percentage'], 0)

if __name__ == "__main__":
    unittest.main()
