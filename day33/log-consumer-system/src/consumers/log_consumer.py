import asyncio
import json
import logging
import time
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional, Callable, Any
import redis.asyncio as redis
from pydantic import BaseModel, Field
import structlog

logger = structlog.get_logger()

@dataclass
class LogMessage:
    id: str
    timestamp: float
    level: str
    message: str
    source: str
    metadata: Dict[str, Any] = None

class ConsumerConfig(BaseModel):
    redis_url: str = "redis://localhost:6379"
    queue_name: str = "logs"
    consumer_group: str = "log-processors"
    consumer_id: str = "consumer-1"
    batch_size: int = 10
    poll_timeout: int = 1000
    max_retries: int = 3

class LogConsumer:
    def __init__(self, config: ConsumerConfig, processor: Callable[[LogMessage], bool]):
        self.config = config
        self.processor = processor
        self.redis_client = None
        self.running = False
        self.processed_count = 0
        self.error_count = 0
        
    async def connect(self):
        """Initialize Redis connection and consumer group"""
        self.redis_client = redis.from_url(self.config.redis_url)
        
        # Create consumer group if it doesn't exist
        try:
            await self.redis_client.xgroup_create(
                self.config.queue_name, 
                self.config.consumer_group, 
                id='0', 
                mkstream=True
            )
            logger.info(f"Created consumer group: {self.config.consumer_group}")
        except redis.ResponseError as e:
            if "BUSYGROUP" not in str(e):
                raise
            logger.info(f"Consumer group already exists: {self.config.consumer_group}")
    
    async def consume(self):
        """Main consumption loop"""
        self.running = True
        logger.info(f"Starting consumer: {self.config.consumer_id}")
        
        while self.running:
            try:
                # Read messages from stream
                messages = await self.redis_client.xreadgroup(
                    self.config.consumer_group,
                    self.config.consumer_id,
                    {self.config.queue_name: '>'},
                    count=self.config.batch_size,
                    block=self.config.poll_timeout
                )
                
                if messages:
                    await self._process_messages(messages)
                
            except Exception as e:
                logger.error(f"Error in consumption loop: {e}")
                self.error_count += 1
                await asyncio.sleep(1)
    
    async def _process_messages(self, messages):
        """Process batch of messages"""
        for stream, msgs in messages:
            for msg_id, fields in msgs:
                try:
                    # Parse message
                    log_data = json.loads(fields[b'data'].decode())
                    log_message = LogMessage(**log_data)
                    
                    # Process message
                    success = await self._process_single_message(log_message)
                    
                    if success:
                        # Acknowledge message
                        await self.redis_client.xack(
                            self.config.queue_name,
                            self.config.consumer_group,
                            msg_id
                        )
                        self.processed_count += 1
                        logger.info(f"Processed message: {msg_id}")
                    else:
                        logger.error(f"Failed to process message: {msg_id}")
                        self.error_count += 1
                        
                except Exception as e:
                    logger.error(f"Error processing message {msg_id}: {e}")
                    self.error_count += 1
    
    async def _process_single_message(self, log_message: LogMessage) -> bool:
        """Process individual log message"""
        try:
            return self.processor(log_message)
        except Exception as e:
            logger.error(f"Processor error: {e}")
            return False
    
    async def stop(self):
        """Gracefully stop consumer"""
        self.running = False
        if self.redis_client:
            await self.redis_client.close()
        logger.info(f"Consumer stopped. Processed: {self.processed_count}, Errors: {self.error_count}")
    
    def get_stats(self) -> Dict[str, int]:
        """Get consumer statistics"""
        return {
            "processed_count": self.processed_count,
            "error_count": self.error_count,
            "success_rate": self.processed_count / max(1, self.processed_count + self.error_count)
        }
