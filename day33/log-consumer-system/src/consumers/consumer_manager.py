import asyncio
import signal
from typing import List, Dict, Any
from src.consumers.log_consumer import LogConsumer, ConsumerConfig
from src.processors.log_processor import LogProcessor
import structlog

logger = structlog.get_logger()

class ConsumerManager:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.consumers: List[LogConsumer] = []
        self.processor = LogProcessor()
        self.running = False
    
    async def start(self):
        """Start multiple consumer instances"""
        self.running = True
        
        # Create consumers based on configuration
        num_consumers = self.config.get("num_consumers", 2)
        
        for i in range(num_consumers):
            consumer_config = ConsumerConfig(
                redis_url=self.config.get("redis_url", "redis://localhost:6379"),
                queue_name=self.config.get("queue_name", "logs"),
                consumer_group=self.config.get("consumer_group", "log-processors"),
                consumer_id=f"consumer-{i+1}",
                batch_size=self.config.get("batch_size", 10)
            )
            
            consumer = LogConsumer(consumer_config, self.processor.process)
            await consumer.connect()
            self.consumers.append(consumer)
        
        # Start all consumers
        tasks = [consumer.consume() for consumer in self.consumers]
        
        # Setup signal handlers
        self._setup_signal_handlers()
        
        logger.info(f"Started {len(self.consumers)} consumers")
        
        try:
            await asyncio.gather(*tasks)
        except asyncio.CancelledError:
            logger.info("Consumer tasks cancelled")
    
    async def stop(self):
        """Stop all consumers gracefully"""
        logger.info("Stopping consumer manager...")
        self.running = False
        
        # Stop all consumers
        for consumer in self.consumers:
            await consumer.stop()
        
        logger.info("All consumers stopped")
    
    def _setup_signal_handlers(self):
        """Setup graceful shutdown handlers"""
        def signal_handler(sig, frame):
            logger.info(f"Received signal {sig}, shutting down...")
            asyncio.create_task(self.stop())
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get aggregated statistics from all consumers"""
        stats = {
            "total_processed": 0,
            "total_errors": 0,
            "consumers": []
        }
        
        for i, consumer in enumerate(self.consumers):
            consumer_stats = consumer.get_stats()
            stats["consumers"].append({
                "id": f"consumer-{i+1}",
                **consumer_stats
            })
            stats["total_processed"] += consumer_stats["processed_count"]
            stats["total_errors"] += consumer_stats["error_count"]
        
        # Add processor metrics
        stats["processor_metrics"] = self.processor.get_metrics()
        
        return stats
