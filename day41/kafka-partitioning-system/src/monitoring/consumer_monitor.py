import json
import time
import threading
from datetime import datetime
from typing import Dict, List
from confluent_kafka.admin import AdminClient
from confluent_kafka import Consumer
import redis
import structlog
import sys
import os

# Add config path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.kafka_config import config

logger = structlog.get_logger(__name__)

class ConsumerGroupMonitor:
    def __init__(self):
        self.admin_client = AdminClient({'bootstrap.servers': config.bootstrap_servers})
        try:
            self.redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
            # Test Redis connection
            self.redis_client.ping()
        except Exception as e:
            logger.warning(f"Redis not available: {e}. Using in-memory storage.")
            self.redis_client = None
        
        self.monitoring = False
        self.stats_history = []
        
    def get_consumer_group_info(self) -> Dict:
        """Get detailed consumer group information"""
        try:
            # Get basic group info - simplified for demo
            group_info = {
                'group_id': config.consumer_group_id,
                'state': 'Stable',
                'protocol': 'range',
                'protocol_type': 'consumer'
            }
            
            # Get member information
            members = self._get_group_members()
            group_info['members'] = members
            
            # Get partition assignment
            partition_assignment = self._get_partition_assignment()
            group_info['partition_assignment'] = partition_assignment
            
            # Get consumer lag
            lag_info = self._get_consumer_lag()
            group_info['lag_info'] = lag_info
            
            return group_info
            
        except Exception as e:
            logger.error(f"❌ Error getting consumer group info: {e}")
            return {'error': str(e)}
    
    def _get_group_members(self) -> List[Dict]:
        """Get consumer group member information"""
        try:
            # For demo purposes, simulate member info based on expected consumers
            return [
                {
                    'member_id': f'consumer-{i+1}',
                    'client_id': f'consumer-{i+1}',
                    'host': 'localhost',
                    'assignment': f'partitions {i*2}-{i*2+1}' if i*2+1 < config.partitions else f'partition {i*2}'
                }
                for i in range(3)  # Assuming 3 consumers
            ]
        except Exception as e:
            logger.error(f"❌ Error getting group members: {e}")
            return []
    
    def _get_partition_assignment(self) -> Dict:
        """Get current partition assignment for the group"""
        try:
            assignment = {}
            partitions_per_consumer = config.partitions // 3  # Assuming 3 consumers
            remainder = config.partitions % 3
            
            partition_idx = 0
            for i in range(3):
                consumer_id = f'consumer-{i+1}'
                consumer_partitions = []
                
                # Assign base partitions
                for j in range(partitions_per_consumer):
                    consumer_partitions.append(partition_idx)
                    partition_idx += 1
                
                # Assign remainder partitions
                if i < remainder:
                    consumer_partitions.append(partition_idx)
                    partition_idx += 1
                
                assignment[consumer_id] = consumer_partitions
            
            return assignment
        except Exception as e:
            logger.error(f"❌ Error getting partition assignment: {e}")
            return {}
    
    def _get_consumer_lag(self) -> Dict:
        """Get consumer lag information"""
        try:
            # Simulate lag information for demo
            lag_info = {}
            for i in range(config.partitions):
                # Simulate realistic lag values
                high_water_mark = 1000 + i * 100 + int(time.time()) % 100
                current_offset = high_water_mark - (5 + i % 10)  # Small lag
                
                lag_info[f'partition-{i}'] = {
                    'current_offset': current_offset,
                    'high_water_mark': high_water_mark,
                    'lag': max(0, high_water_mark - current_offset)
                }
            
            return lag_info
        except Exception as e:
            logger.error(f"❌ Error getting consumer lag: {e}")
            return {}
    
    def collect_metrics(self) -> Dict:
        """Collect comprehensive monitoring metrics"""
        timestamp = datetime.now().isoformat()
        
        # Get consumer group info
        group_info = self.get_consumer_group_info()
        
        # Get topic information
        topic_info = self._get_topic_info()
        
        # Get system metrics
        system_metrics = self._get_system_metrics()
        
        metrics = {
            'timestamp': timestamp,
            'consumer_group': group_info,
            'topic_info': topic_info,
            'system_metrics': system_metrics
        }
        
        # Store in Redis for dashboard (if available)
        if self.redis_client:
            try:
                self.redis_client.setex(
                    'kafka_metrics:latest',
                    300,  # 5 minute expiry
                    json.dumps(metrics)
                )
            except Exception as e:
                logger.warning(f"Failed to store metrics in Redis: {e}")
        
        # Keep history for trending
        self.stats_history.append(metrics)
        if len(self.stats_history) > 100:  # Keep last 100 entries
            self.stats_history.pop(0)
        
        return metrics
    
    def _get_topic_info(self) -> Dict:
        """Get topic information"""
        try:
            metadata = self.admin_client.list_topics(timeout=10)
            if config.topic_name in metadata.topics:
                topic = metadata.topics[config.topic_name]
                return {
                    'name': config.topic_name,
                    'partitions': len(topic.partitions),
                    'partition_details': [
                        {
                            'id': partition_id,
                            'leader': partition_metadata.leader,
                            'replicas': len(partition_metadata.replicas),
                            'isr': len(partition_metadata.replicas)  # Use replicas count as ISR count
                        }
                        for partition_id, partition_metadata in topic.partitions.items()
                    ]
                }
            else:
                return {'error': 'Topic not found'}
        except Exception as e:
            logger.error(f"❌ Error getting topic info: {e}")
            return {'error': str(e)}
    
    def _get_system_metrics(self) -> Dict:
        """Get system-level metrics"""
        try:
            import psutil
            
            return {
                'cpu_usage': psutil.cpu_percent(interval=1),
                'memory_usage': psutil.virtual_memory().percent,
                'disk_usage': psutil.disk_usage('/').percent,
                'network_io': {
                    'bytes_sent': psutil.net_io_counters().bytes_sent,
                    'bytes_recv': psutil.net_io_counters().bytes_recv
                }
            }
        except ImportError:
            logger.warning("psutil not available, using dummy system metrics")
            return {
                'cpu_usage': 45.0,
                'memory_usage': 65.0,
                'disk_usage': 35.0,
                'network_io': {
                    'bytes_sent': 1024000,
                    'bytes_recv': 2048000
                }
            }
        except Exception as e:
            logger.error(f"❌ Error getting system metrics: {e}")
            return {}
    
    def start_monitoring(self, interval_seconds: int = 10):
        """Start continuous monitoring"""
        self.monitoring = True
        logger.info(f"📊 Starting consumer group monitoring (interval: {interval_seconds}s)")
        
        def monitor_loop():
            while self.monitoring:
                try:
                    metrics = self.collect_metrics()
                    logger.info(f"📈 Collected metrics at {metrics['timestamp']}")
                    time.sleep(interval_seconds)
                except Exception as e:
                    logger.error(f"❌ Monitoring error: {e}")
                    time.sleep(interval_seconds)
        
        self.monitor_thread = threading.Thread(target=monitor_loop, daemon=True)
        self.monitor_thread.start()
    
    def stop_monitoring(self):
        """Stop monitoring"""
        self.monitoring = False
        logger.info("🛑 Stopped consumer group monitoring")
    
    def get_latest_metrics(self) -> Dict:
        """Get the latest collected metrics"""
        try:
            if self.redis_client:
                metrics_json = self.redis_client.get('kafka_metrics:latest')
                if metrics_json:
                    return json.loads(metrics_json)
            
            # Fallback to in-memory history
            if self.stats_history:
                return self.stats_history[-1]
            else:
                return self.collect_metrics()
                
        except Exception as e:
            logger.error(f"❌ Error getting latest metrics: {e}")
            return self.collect_metrics()  # Fallback to fresh collection

# Global monitor instance
monitor = ConsumerGroupMonitor()
