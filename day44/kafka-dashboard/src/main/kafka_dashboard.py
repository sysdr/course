import json
import time
import threading
import os
from collections import defaultdict, deque
from datetime import datetime, timedelta
from kafka import KafkaConsumer, KafkaProducer
from kafka.errors import KafkaError
import pandas as pd
import numpy as np
from typing import Dict, List, Any
import logging

class StreamProcessor:
    def __init__(self, bootstrap_servers: str = None):
        self.bootstrap_servers = bootstrap_servers or os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
        self.consumer = None
        self.producer = None
        self.metrics = defaultdict(lambda: deque(maxlen=1000))
        self.running = False
        self.window_size = 60  # 60 seconds
        self.logger = self._setup_logger()
        
    def _setup_logger(self):
        logging.basicConfig(level=logging.INFO)
        return logging.getLogger(__name__)
        
    def initialize_kafka(self):
        """Initialize Kafka consumer and producer"""
        try:
            self.consumer = KafkaConsumer(
                'log-events',
                'user-events', 
                'error-events',
                bootstrap_servers=self.bootstrap_servers,
                auto_offset_reset='earliest',
                enable_auto_commit=True,
                group_id='dashboard-consumer',
                value_deserializer=lambda x: json.loads(x.decode('utf-8'))
            )
            
            self.producer = KafkaProducer(
                bootstrap_servers=self.bootstrap_servers,
                value_serializer=lambda x: json.dumps(x).encode('utf-8')
            )
            
            self.logger.info("Kafka initialized successfully")
            return True
            
        except Exception as e:
            self.logger.error(f"Kafka initialization failed: {e}")
            return False
            
    def process_stream(self):
        """Main stream processing loop"""
        self.running = True
        self.logger.info("Starting stream processing...")
        
        while self.running:
            try:
                message_batch = self.consumer.poll(timeout_ms=1000)
                
                if message_batch:
                    self.logger.info(f"Received {len(message_batch)} message batches")
                    
                for topic_partition, messages in message_batch.items():
                    self.logger.info(f"Processing {len(messages)} messages from {topic_partition}")
                    for message in messages:
                        self.process_message(message.value, message.topic)
                        
            except Exception as e:
                self.logger.error(f"Error processing stream: {e}")
                time.sleep(1)
                
    def process_message(self, data: Dict, topic: str):
        """Process individual message and update metrics"""
        timestamp = datetime.now()
        
        self.logger.info(f"Processing message from topic {topic}: {data}")
        
        # Update message count
        self.metrics[f'{topic}_count'].append({
            'timestamp': timestamp,
            'value': 1
        })
        
        # Process different event types
        if topic == 'error-events':
            self.process_error_event(data, timestamp)
        elif topic == 'log-events':
            self.process_log_event(data, timestamp)
        elif topic == 'user-events':
            self.process_user_event(data, timestamp)
            
    def process_error_event(self, data: Dict, timestamp: datetime):
        """Process error events for error rate calculation"""
        error_type = data.get('error_type', 'unknown')
        severity = data.get('severity', 'low')
        
        self.metrics['error_rate'].append({
            'timestamp': timestamp,
            'error_type': error_type,
            'severity': severity
        })
        
    def process_log_event(self, data: Dict, timestamp: datetime):
        """Process general log events"""
        status_code = data.get('status_code', 200)
        response_time = data.get('response_time', 0)
        
        self.metrics['response_time'].append({
            'timestamp': timestamp,
            'value': response_time
        })
        
        if status_code >= 400:
            self.metrics['http_errors'].append({
                'timestamp': timestamp,
                'status_code': status_code
            })
            
    def process_user_event(self, data: Dict, timestamp: datetime):
        """Process user activity events"""
        user_id = data.get('user_id')
        action = data.get('action', 'unknown')
        
        self.metrics['user_activity'].append({
            'timestamp': timestamp,
            'user_id': user_id,
            'action': action
        })
        
    def get_windowed_metrics(self) -> Dict[str, Any]:
        """Calculate metrics for current time window"""
        now = datetime.now()
        window_start = now - timedelta(seconds=self.window_size)
        
        results = {}
        
        # Create a copy of metrics to avoid deque mutation during iteration
        metrics_copy = {}
        for key, events in self.metrics.items():
            metrics_copy[key] = list(events)  # Convert deque to list
        
        # Calculate event rates
        for metric_name, events in metrics_copy.items():
            if '_count' in metric_name:
                recent_events = [e for e in events if e['timestamp'] > window_start]
                results[f'{metric_name}_rate'] = len(recent_events) / self.window_size
                
        # Calculate error rate
        error_events = [e for e in metrics_copy.get('error_rate', []) if e['timestamp'] > window_start]
        total_events = sum(len([e for e in events if e['timestamp'] > window_start]) 
                          for events in metrics_copy.values())
        
        results['error_rate_percentage'] = (len(error_events) / max(total_events, 1)) * 100
        
        # Calculate average response time
        response_times = [e['value'] for e in metrics_copy.get('response_time', [])
                         if e['timestamp'] > window_start]
        results['avg_response_time'] = np.mean(response_times) if response_times else 0
        
        # Top error types
        error_types = [e['error_type'] for e in error_events]
        results['top_errors'] = pd.Series(error_types).value_counts().head(5).to_dict()
        
        return results
        
    def get_historical_data(self, minutes: int = 10) -> Dict[str, List]:
        """Get historical data for charts"""
        now = datetime.now()
        time_buckets = []
        
        # Create time buckets
        for i in range(minutes):
            bucket_time = now - timedelta(minutes=i)
            time_buckets.append(bucket_time)
            
        results = {
            'timestamps': [t.isoformat() for t in reversed(time_buckets)],
            'error_rates': [],
            'response_times': [],
            'event_counts': []
        }
        
        # Create a copy of metrics to avoid deque mutation during iteration
        metrics_copy = {}
        for key, events in self.metrics.items():
            metrics_copy[key] = list(events)  # Convert deque to list
        
        for bucket_time in reversed(time_buckets):
            bucket_start = bucket_time - timedelta(minutes=1)
            bucket_end = bucket_time
            
            # Error rate for this bucket
            bucket_errors = [e for e in metrics_copy.get('error_rate', [])
                           if bucket_start <= e['timestamp'] < bucket_end]
            bucket_total = sum(len([e for e in events 
                                  if bucket_start <= e['timestamp'] < bucket_end])
                             for events in metrics_copy.values())
            
            error_rate = (len(bucket_errors) / max(bucket_total, 1)) * 100
            results['error_rates'].append(error_rate)
            
            # Response time for this bucket
            bucket_response_times = [e['value'] for e in metrics_copy.get('response_time', [])
                                   if bucket_start <= e['timestamp'] < bucket_end]
            avg_response = np.mean(bucket_response_times) if bucket_response_times else 0
            results['response_times'].append(avg_response)
            
            # Event count for this bucket
            results['event_counts'].append(bucket_total)
            
        return results
        
    def stop(self):
        """Stop stream processing"""
        self.running = False
        if self.consumer:
            self.consumer.close()
        if self.producer:
            self.producer.close()
