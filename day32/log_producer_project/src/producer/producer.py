import asyncio
import json
import logging
import time
from datetime import datetime
from typing import List, Dict, Any
import pika
import aiohttp
from aiohttp import web
import signal
import sys
import os

try:
    from .batch_manager import BatchManager
    from .connection_pool import ConnectionPool
    from .health_monitor import HealthMonitor
    from ..models.log_entry import LogEntry
except ImportError:
    # Fallback for direct execution
    from producer.batch_manager import BatchManager
    from producer.connection_pool import ConnectionPool
    from producer.health_monitor import HealthMonitor
    from models.log_entry import LogEntry

class LogProducer:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.batch_manager = BatchManager(
            max_size=config.get('batch_size', 50),
            max_wait_ms=config.get('batch_timeout_ms', 100)
        )
        self.connection_pool = ConnectionPool(config['rabbitmq'])
        self.health_monitor = HealthMonitor()
        self.running = True
        
    async def start(self):
        """Start the producer service"""
        logging.info("Starting Log Producer service...")
        
        # Initialize connection pool
        await self.connection_pool.initialize()
        
        # Start batch processing
        asyncio.create_task(self._batch_processor())
        
        # Start HTTP server
        app = web.Application()
        app.router.add_post('/logs', self.handle_log_submission)
        app.router.add_get('/health', self.handle_health_check)
        app.router.add_get('/metrics', self.handle_metrics)
        
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', self.config.get('port', 8080))
        await site.start()
        
        logging.info(f"Producer service started on port {self.config.get('port', 8080)}")
        
    async def handle_log_submission(self, request):
        """Handle incoming log submission"""
        try:
            data = await request.json()
            log_entry = LogEntry.from_dict(data)
            
            await self.batch_manager.add_log(log_entry)
            self.health_monitor.record_log_received()
            
            return web.json_response({'status': 'accepted'})
        except Exception as e:
            logging.error(f"Error processing log submission: {e}")
            return web.json_response({'error': str(e)}, status=400)
    
    async def handle_health_check(self, request):
        """Health check endpoint"""
        health_status = await self.health_monitor.get_health_status()
        status_code = 200 if health_status['healthy'] else 503
        return web.json_response(health_status, status=status_code)
    
    async def handle_metrics(self, request):
        """Metrics endpoint"""
        metrics = await self.health_monitor.get_metrics()
        return web.json_response(metrics)
    
    async def _batch_processor(self):
        """Background task to process batches"""
        while self.running:
            try:
                batch = await self.batch_manager.get_batch()
                if batch:
                    await self._publish_batch(batch)
                await asyncio.sleep(0.01)  # Small delay to prevent busy waiting
            except Exception as e:
                logging.error(f"Batch processing error: {e}")
                await asyncio.sleep(1)  # Back off on error
    
    async def _publish_batch(self, batch: List[LogEntry]):
        """Publish a batch of logs to RabbitMQ"""
        try:
            start_time = time.time()
            
            # Serialize batch
            messages = [log.to_json() for log in batch]
            
            # Publish to RabbitMQ
            success = await self.connection_pool.publish_batch(messages)
            
            if success:
                duration = time.time() - start_time
                self.health_monitor.record_batch_published(len(batch), duration)
                logging.debug(f"Published batch of {len(batch)} logs in {duration:.3f}s")
            else:
                self.health_monitor.record_batch_failed(len(batch))
                logging.error(f"Failed to publish batch of {len(batch)} logs")
                
        except Exception as e:
            logging.error(f"Error publishing batch: {e}")
            self.health_monitor.record_batch_failed(len(batch))
    
    async def shutdown(self):
        """Graceful shutdown"""
        logging.info("Shutting down Log Producer...")
        self.running = False
        
        # Flush remaining logs
        await self.batch_manager.flush_all()
        
        # Close connections
        await self.connection_pool.close()
        
        logging.info("Log Producer shutdown complete")

async def main():
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Load configuration
    config = {
    'rabbitmq': {
        'host': os.environ.get('RABBITMQ_HOST', 'localhost'),
        'port': int(os.environ.get('RABBITMQ_PORT', 5672)),
        'exchange': 'logs_exchange',
        'routing_key': 'application.logs'
    },
    'batch_size': 50,
    'batch_timeout_ms': 100,
    'port': 8080
    }
    
    # Create and start producer
    producer = LogProducer(config)
    
    # Handle graceful shutdown
    def signal_handler():
        asyncio.create_task(producer.shutdown())
    
    # Setup signal handlers
    for sig in [signal.SIGTERM, signal.SIGINT]:
        signal.signal(sig, lambda s, f: signal_handler())
    
    try:
        await producer.start()
        # Keep running
        while producer.running:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        await producer.shutdown()

if __name__ == "__main__":
    asyncio.run(main())
