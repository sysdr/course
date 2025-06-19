from prometheus_client import Counter, Histogram, Gauge, start_http_server, REGISTRY
from typing import Dict, Any, Optional
import time
import threading
import structlog

logger = structlog.get_logger()

class ProducerMetrics:
    """Comprehensive producer metrics collection"""
    
    _instance: Optional['ProducerMetrics'] = None
    _lock = threading.Lock()
    _metrics_created = False
    
    def __new__(cls, port: int = 8000):
        """Singleton pattern to prevent duplicate metric registrations"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self, port: int = 8000):
        # Only initialize once
        if hasattr(self, '_initialized'):
            return
            
        self.port = port
        self._initialized = True
        
        # Create metrics only once
        if not ProducerMetrics._metrics_created:
            self._create_metrics()
            ProducerMetrics._metrics_created = True
        
        # Start metrics server only once
        if not hasattr(self, '_server_started'):
            self._start_server()
            self._server_started = True
    
    def _create_metrics(self):
        """Create all Prometheus metrics"""
        # Counters
        self.messages_sent = Counter(
            'kafka_producer_messages_sent_total',
            'Total messages sent to Kafka',
            ['topic', 'partition']
        )
        
        self.messages_failed = Counter(
            'kafka_producer_messages_failed_total', 
            'Total failed messages',
            ['topic', 'error_type']
        )
        
        self.bytes_sent = Counter(
            'kafka_producer_bytes_sent_total',
            'Total bytes sent to Kafka',
            ['topic']
        )
        
        # Histograms
        self.send_latency = Histogram(
            'kafka_producer_send_latency_seconds',
            'Message send latency',
            ['topic'],
            buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
        )
        
        self.batch_size = Histogram(
            'kafka_producer_batch_size_messages',
            'Batch size in messages',
            ['topic'],
            buckets=[1, 5, 10, 25, 50, 100, 250, 500, 1000]
        )
        
        # Gauges
        self.buffer_available = Gauge(
            'kafka_producer_buffer_available_bytes',
            'Available buffer memory'
        )
        
        self.pending_messages = Gauge(
            'kafka_producer_pending_messages',
            'Messages waiting to be sent'
        )
        
        self.connections_active = Gauge(
            'kafka_producer_connections_active',
            'Active connections to Kafka'
        )
        
    def _start_server(self):
        """Start Prometheus metrics server"""
        try:
            start_http_server(self.port)
            logger.info(f"Metrics server started on port {self.port}")
        except Exception as e:
            logger.error(f"Failed to start metrics server: {e}")
    
    def record_message_sent(self, topic: str, partition: int, size_bytes: int):
        """Record successful message send"""
        self.messages_sent.labels(topic=topic, partition=partition).inc()
        self.bytes_sent.labels(topic=topic).inc(size_bytes)
        
    def record_message_failed(self, topic: str, error_type: str):
        """Record failed message"""
        self.messages_failed.labels(topic=topic, error_type=error_type).inc()
        
    def record_send_latency(self, topic: str, latency_seconds: float):
        """Record send latency"""
        self.send_latency.labels(topic=topic).observe(latency_seconds)
        
    def record_batch_size(self, topic: str, size: int):
        """Record batch size"""
        self.batch_size.labels(topic=topic).observe(size)
        
    def update_buffer_available(self, bytes_available: int):
        """Update available buffer memory"""
        self.buffer_available.set(bytes_available)
        
    def update_pending_messages(self, count: int):
        """Update pending message count"""
        self.pending_messages.set(count)
        
    def update_active_connections(self, count: int):
        """Update active connection count"""
        self.connections_active.set(count)
