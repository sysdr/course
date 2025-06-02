import sys
import os
from datetime import datetime, timedelta
import random
import json

# Add src directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from partition_router import PartitionRouter
from partition_manager import PartitionManager
from query_optimizer import QueryOptimizer

class LogPartitioningSystem:
    def __init__(self, strategy="source"):
        self.router = PartitionRouter(strategy=strategy)
        self.manager = PartitionManager()
        self.optimizer = QueryOptimizer(self.router, self.manager)
        self.processed_logs = 0
    
    def ingest_log(self, log_entry):
        """Ingest a single log entry"""
        partition = self.router.route_log(log_entry)
        self.manager.store_log(partition, log_entry)
        self.processed_logs += 1
        return partition
    
    def generate_sample_logs(self, count=1000):
        """Generate sample logs for testing"""
        sources = ["web_server", "database", "auth_service", "api_gateway", "cache"]
        levels = ["INFO", "WARNING", "ERROR", "DEBUG"]
        
        logs = []
        base_time = datetime.now() - timedelta(hours=24)
        
        for i in range(count):
            log = {
                "id": f"log_{i:04d}",
                "source": random.choice(sources),
                "level": random.choice(levels),
                "message": f"Sample log message {i}",
                "timestamp": (base_time + timedelta(minutes=random.randint(0, 1440))).isoformat(),
                "user_id": f"user_{random.randint(1, 100)}"
            }
            logs.append(log)
        
        return logs
    
    def demo_partitioning(self):
        """Demonstrate partitioning system with sample data"""
        print("🚀 Starting Log Partitioning Demo")
        
        # Generate and ingest sample logs
        print("📊 Generating sample logs...")
        sample_logs = self.generate_sample_logs(1000)
        
        print("📥 Ingesting logs...")
        for log in sample_logs:
            self.ingest_log(log)
        
        print(f"✅ Processed {self.processed_logs} logs")
        
        # Show partition distribution
        stats = self.manager.get_partition_stats()
        print("\n📈 Partition Distribution:")
        for partition, stat in stats.items():
            print(f"  {partition}: {stat['log_count']} logs, Sources: {stat['sources']}")
        
        # Demo optimized queries
        print("\n🔍 Testing Query Optimization:")
        
        # Query by source
        if self.router.strategy == "source":
            query_result = self.optimizer.execute_query({"source": "web_server"})
            print(f"  Source query: Found {len(query_result['results'])} web_server logs")
            print(f"  Queried {len(query_result['stats']['partitions_queried'])}/{len(self.router.nodes)} partitions")
        
        # Query by time range
        time_start = (datetime.now() - timedelta(hours=2)).isoformat()
        time_end = datetime.now().isoformat()
        time_query = self.optimizer.execute_query({
            "time_range": {"start": time_start, "end": time_end}
        })
        print(f"  Time query: Found {len(time_query['results'])} logs in last 2 hours")
        
        # Show performance comparison
        perf = self.optimizer.get_performance_comparison()
        print(f"\n⚡ Performance Improvement:")
        print(f"  Improvement Factor: {perf['improvement_factor']:.1f}x faster")
        print(f"  Efficiency: {perf['efficiency_percentage']:.1f}%")
        
        return {
            "logs_processed": self.processed_logs,
            "partition_stats": stats,
            "performance": perf
        }

if __name__ == "__main__":
    # Demo both strategies
    print("=== SOURCE-BASED PARTITIONING ===")
    source_system = LogPartitioningSystem("source")
    source_results = source_system.demo_partitioning()
    
    print("\n=== TIME-BASED PARTITIONING ===")
    time_system = LogPartitioningSystem("time")
    time_results = time_system.demo_partitioning()
