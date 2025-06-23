import asyncio
import threading
import time
from typing import Dict, Any
from confluent_kafka.admin import AdminClient, ConfigResource, ResourceType
from src.config.kafka_config import KafkaConfig
from src.config.app_config import AppConfig
import structlog

logger = structlog.get_logger(__name__)


class CompactionMonitor:
    """Monitor compaction effectiveness and cluster health"""
    
    def __init__(self, kafka_config: KafkaConfig, app_config: AppConfig):
        self.kafka_config = kafka_config
        self.app_config = app_config
        self.admin_client = kafka_config.create_admin_client()
        self.running = False
        self._monitor_thread = None
        self.metrics = {
            'total_messages': 0,
            'unique_keys': 0,
            'compaction_ratio': 0.0,
            'storage_saved_percent': 0.0,
            'last_compaction_time': None,
            'partition_stats': {},
            'topic_config': {}
        }
    
    def start_monitoring(self):
        """Start monitoring in background thread"""
        if self.running:
            logger.warning("Monitor already running")
            return
            
        self.running = True
        self._monitor_thread = threading.Thread(
            target=self._monitor_loop,
            name="CompactionMonitor-Thread"
        )
        self._monitor_thread.start()
        
        logger.info(
            "Compaction monitor started",
            topic=self.kafka_config.topic_name,
            interval_ms=self.app_config.monitoring_interval_ms
        )
    
    def _monitor_loop(self):
        """Main monitoring loop"""
        interval_seconds = self.app_config.monitoring_interval_ms / 1000.0
        
        while self.running:
            try:
                self._collect_metrics()
                time.sleep(interval_seconds)
            except Exception as e:
                logger.error(
                    "Error in monitoring loop",
                    error=str(e)
                )
                time.sleep(interval_seconds)
    
    def _collect_metrics(self):
        """Collect compaction and topic metrics"""
        try:
            # Get topic metadata
            topic_metadata = self.admin_client.list_topics(timeout=10)
            
            if self.kafka_config.topic_name not in topic_metadata.topics:
                logger.warning(
                    "Topic not found",
                    topic=self.kafka_config.topic_name
                )
                return
            
            topic_info = topic_metadata.topics[self.kafka_config.topic_name]
            
            # Update partition stats
            self.metrics['partition_stats'] = {
                'partition_count': len(topic_info.partitions),
                'partitions': [
                    {
                        'id': getattr(p, 'id', i),
                        'leader': getattr(p, 'leader', -1),
                        'replicas': len(getattr(p, 'replicas', [])),
                        'in_sync_replicas': len(getattr(p, 'isrs', []))
                    }
                    for i, p in enumerate(topic_info.partitions)
]
            }
            
            # Get topic configuration
            self._collect_topic_config()
            
            # Calculate derived metrics
            self._calculate_compaction_metrics()
            
            logger.debug(
                "Metrics collected",
                topic=self.kafka_config.topic_name,
                partitions=len(topic_info.partitions),
                compaction_ratio=self.metrics['compaction_ratio']
            )
            
        except Exception as e:
            logger.error(
                "Error collecting metrics",
                error=str(e)
            )
    
    def _collect_topic_config(self):
        """Collect topic configuration"""
        try:
            resource = ConfigResource(ResourceType.TOPIC, self.kafka_config.topic_name)
            configs = self.admin_client.describe_configs([resource])
            
            for resource, future in configs.items():
                try:
                    config = future.result()
                    self.metrics['topic_config'] = {
                        'cleanup.policy': config.get('cleanup.policy', {}).value,
                        'segment.bytes': config.get('segment.bytes', {}).value,
                        'min.cleanable.dirty.ratio': config.get('min.cleanable.dirty.ratio', {}).value,
                        'delete.retention.ms': config.get('delete.retention.ms', {}).value
                    }
                except Exception as e:
                    logger.error(
                        "Error getting topic config",
                        error=str(e)
                    )
                    
        except Exception as e:
            logger.error(
                "Error collecting topic config",
                error=str(e)
            )
    
    def _calculate_compaction_metrics(self):
        """Calculate compaction effectiveness metrics"""
        # Note: These are estimated metrics
        # In production, you'd integrate with Kafka JMX metrics
        
        # Simulate compaction effectiveness based on time
        import time
        current_time = time.time()
        
        # Simulate increasing message count
        self.metrics['total_messages'] += 10
        
        # Simulate unique keys (should grow slower than total messages)
        if self.metrics['total_messages'] > 50:
            # After initial messages, unique keys grow slower
            self.metrics['unique_keys'] = min(
                self.metrics['unique_keys'] + 2,
                self.metrics['total_messages'] * 0.3  # Max 30% unique
            )
        else:
            self.metrics['unique_keys'] = self.metrics['total_messages']
        
        # Calculate compaction ratio
        if self.metrics['total_messages'] > 0:
            self.metrics['compaction_ratio'] = (
                self.metrics['unique_keys'] / self.metrics['total_messages']
            )
            self.metrics['storage_saved_percent'] = (
                (1 - self.metrics['compaction_ratio']) * 100
            )
        
        # Update last compaction time
        self.metrics['last_compaction_time'] = current_time
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get current metrics"""
        return self.metrics.copy()
    
    def get_compaction_effectiveness(self) -> Dict[str, float]:
        """Get compaction effectiveness summary"""
        return {
            'compaction_ratio': self.metrics['compaction_ratio'],
            'storage_saved_percent': self.metrics['storage_saved_percent'],
            'total_messages': self.metrics['total_messages'],
            'unique_keys': self.metrics['unique_keys']
        }
    
    def stop(self):
        """Stop monitoring"""
        self.running = False
        
        if self._monitor_thread and self._monitor_thread.is_alive():
            self._monitor_thread.join(timeout=5)
        
        #self.admin_client.close()

        logger.info("Compaction monitor stopped")
        pass

class AsyncCompactionMonitor:
    """Async wrapper for compaction monitor"""
    
    def __init__(self, kafka_config: KafkaConfig, app_config: AppConfig):
        self.monitor = CompactionMonitor(kafka_config, app_config)
    
    async def start_monitoring(self):
        """Start monitoring asynchronously"""
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.monitor.start_monitoring)
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get metrics"""
        return self.monitor.get_metrics()
    
    def get_compaction_effectiveness(self) -> Dict[str, float]:
        """Get compaction effectiveness"""
        return self.monitor.get_compaction_effectiveness()
    
    def stop(self):
        """Stop monitoring"""
        self.monitor.stop()
