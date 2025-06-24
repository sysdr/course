import asyncio
import json
import random
import uuid
from datetime import datetime
from typing import List

import redis.asyncio as redis
from src.models import LogMessage, LogLevel
from config.settings import settings
import structlog

logger = structlog.get_logger()

class LogProducer:
    def __init__(self):
        self.redis = redis.from_url(settings.redis_url)
        self.message_templates = [
            "User {} logged in successfully",
            "Database query executed in {} ms",
            "API request to {} completed",
            "Cache miss for key {}",
            "Error processing request: {}",
            "Payment processed for amount ${}",
            "Invalid JSON in request: {{malformed",  # Intentionally malformed
            "System memory usage: {}%",
        ]
    
    def generate_log_message(self) -> LogMessage:
        """Generate a realistic log message"""
        template = random.choice(self.message_templates)
        level = random.choice(list(LogLevel))
        source = random.choice(["web-server", "api-gateway", "database", "cache", "payment-service"])
        
        # Create realistic message content
        if "{}" in template:
            if "User" in template:
                content = template.format(f"user_{random.randint(1000, 9999)}")
            elif "Database" in template:
                content = template.format(random.randint(10, 500))
            elif "API" in template:
                content = template.format(f"/api/v1/endpoint_{random.randint(1, 10)}")
            elif "Cache" in template:
                content = template.format(f"cache_key_{random.randint(1, 100)}")
            elif "Error" in template:
                content = template.format("Connection timeout")
            elif "Payment" in template:
                content = template.format(f"{random.randint(10, 1000)}.{random.randint(10, 99)}")
            elif "memory" in template:
                content = template.format(random.randint(40, 95))
            else:
                content = template
        else:
            content = template
        
        return LogMessage(
            id=str(uuid.uuid4()),
            timestamp=datetime.now(),
            level=level,
            source=source,
            message=content,
            metadata={
                "request_id": str(uuid.uuid4()),
                "user_id": random.randint(1, 1000) if random.random() > 0.3 else None,
                "session_id": str(uuid.uuid4()) if random.random() > 0.2 else None
            }
        )
    
    async def produce_messages(self, count: int = 100, interval: float = 0.1):
        """Produce log messages to the primary queue"""
        logger.info(f"Starting to produce {count} messages")
        
        for i in range(count):
            message = self.generate_log_message()
            await self.redis.lpush(
                settings.primary_queue,
                json.dumps(message.to_dict())
            )
            
            if i % 50 == 0:
                logger.info(f"Produced {i} messages")
            
            await asyncio.sleep(interval)
        
        logger.info(f"Finished producing {count} messages")
    
    async def close(self):
        await self.redis.close()

if __name__ == "__main__":
    producer = LogProducer()
    try:
        asyncio.run(producer.produce_messages(500, 0.05))
    finally:
        asyncio.run(producer.close())
