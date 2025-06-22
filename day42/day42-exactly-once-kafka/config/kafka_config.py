"""Kafka configuration for exactly-once processing"""

import os
from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class KafkaConfig:
    bootstrap_servers: str = "localhost:9092"
    
    # Producer configuration for exactly-once semantics
    producer_config: Dict[str, Any] = None
    
    # Consumer configuration for exactly-once semantics
    consumer_config: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.producer_config is None:
            self.producer_config = {
                'bootstrap.servers': self.bootstrap_servers,
                'enable.idempotence': True,  # Critical for exactly-once
                'acks': 'all',
                'retries': 2147483647,  # Max retries
                'max.in.flight.requests.per.connection': 5,
                'compression.type': 'snappy',
                'batch.size': 16384,
                'linger.ms': 5,
                'transactional.id': f'banking-producer-{os.getpid()}'
            }
        
        if self.consumer_config is None:
            self.consumer_config = {
                'bootstrap.servers': self.bootstrap_servers,
                'group.id': 'exactly-once-processors',
                'auto.offset.reset': 'earliest',
                'enable.auto.commit': False,  # Manual offset management
                'isolation.level': 'read_committed',  # Only read committed messages
                'max.poll.interval.ms': 300000,
                'session.timeout.ms': 10000,
                'heartbeat.interval.ms': 3000
            }

# Database configuration
DATABASE_URL = "postgresql://postgres:password123@localhost:5432/exactly_once_db"

# Topics
TOPICS = {
    'transfers': 'banking-transfers',
    'account_updates': 'account-balance-updates',
    'notifications': 'transaction-notifications'
}
