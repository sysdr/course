import os
from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class KafkaConfig:
    bootstrap_servers: str = 'localhost:9092'
    topic_name: str = 'log-processing-topic'
    partitions: int = 6
    replication_factor: int = 1
    
    # Consumer group configuration
    consumer_group_id: str = 'log-processing-group'
    consumer_session_timeout: int = 10000
    consumer_heartbeat_interval: int = 3000
    auto_offset_reset: str = 'earliest'
    
    # Producer configuration
    producer_acks: str = 'all'
    producer_retries: int = 3
    producer_batch_size: int = 16384
    producer_linger_ms: int = 5
    
    # Assignment strategy
    partition_assignment_strategy: str = 'range'

    def get_producer_config(self) -> Dict[str, Any]:
        return {
            'bootstrap.servers': self.bootstrap_servers,
            'acks': self.producer_acks,
            'retries': self.producer_retries,
            'batch.size': self.producer_batch_size,
            'linger.ms': self.producer_linger_ms
        }
    
    def get_consumer_config(self, consumer_id: str) -> Dict[str, Any]:
        return {
            'bootstrap.servers': self.bootstrap_servers,
            'group.id': self.consumer_group_id,
            'client.id': consumer_id,
            'session.timeout.ms': self.consumer_session_timeout,
            'heartbeat.interval.ms': self.consumer_heartbeat_interval,
            'auto.offset.reset': self.auto_offset_reset,
            'enable.auto.commit': True,
            'auto.commit.interval.ms': 1000,
            'partition.assignment.strategy': self.partition_assignment_strategy
        }

# Global configuration instance
config = KafkaConfig()
