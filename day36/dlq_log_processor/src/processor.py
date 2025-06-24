import asyncio
import json
import random
import traceback
from datetime import datetime, timedelta
from typing import Optional

import redis.asyncio as redis
from src.models import LogMessage, FailedMessage, FailureType, LogLevel
from config.settings import settings
import structlog

logger = structlog.get_logger()

class LogProcessor:
    def __init__(self):
        self.redis = redis.from_url(settings.redis_url)
        self.processed_count = 0
        self.failed_count = 0
        self.running = False
    
    async def process_message(self, message_data: str) -> bool:
        """Process a single log message, return True if successful"""
        try:
            # Parse message
            message_dict = json.loads(message_data)
            message = LogMessage(
                id=message_dict["id"],
                timestamp=datetime.fromisoformat(message_dict["timestamp"]),
                level=LogLevel(message_dict["level"]),
                source=message_dict["source"],
                message=message_dict["message"],
                metadata=message_dict.get("metadata", {})
            )
            
            # Simulate various types of failures
            failure_chance = random.random()
            
            if failure_chance < 0.02:  # 2% parsing errors
                if "malformed" in message.message or "{" in message.message:
                    raise ValueError("Malformed JSON in log message")
            
            elif failure_chance < 0.04:  # 2% network errors
                raise ConnectionError("Failed to connect to downstream service")
            
            elif failure_chance < 0.06:  # 2% resource errors
                if message.level == LogLevel.ERROR:
                    raise MemoryError("Insufficient memory to process error log")
            
            # Simulate processing time
            await asyncio.sleep(random.uniform(0.001, 0.01))
            
            # Success case
            self.processed_count += 1
            
            # Store processed message (simulate downstream storage)
            await self.redis.hset(
                "processed_logs",
                message.id,
                json.dumps({
                    **message.to_dict(),
                    "processed_at": datetime.now().isoformat()
                })
            )
            
            return True
            
        except ValueError as e:
            await self._handle_failure(message_data, FailureType.PARSING_ERROR, str(e))
            return False
        except ConnectionError as e:
            await self._handle_failure(message_data, FailureType.NETWORK_ERROR, str(e))
            return False
        except MemoryError as e:
            await self._handle_failure(message_data, FailureType.RESOURCE_ERROR, str(e))
            return False
        except Exception as e:
            await self._handle_failure(message_data, FailureType.UNKNOWN_ERROR, str(e))
            return False
    
    async def _handle_failure(self, message_data: str, failure_type: FailureType, error_details: str):
        """Handle message processing failure"""
        try:
            # Try to parse the original message
            message_dict = json.loads(message_data)
            original_message = LogMessage(
                id=message_dict["id"],
                timestamp=datetime.fromisoformat(message_dict["timestamp"]),
                level=LogLevel(message_dict["level"]),
                source=message_dict["source"],
                message=message_dict["message"],
                metadata=message_dict.get("metadata", {})
            )
        except:
            # If we can't parse it, create a placeholder
            original_message = LogMessage(
                id="unknown",
                timestamp=datetime.now(),
                level=LogLevel.ERROR,
                source="unknown",
                message="Unparseable message",
                metadata={}
            )
        
        # Check if this message has failed before
        retry_key = f"retry:{original_message.id}"
        retry_data = await self.redis.get(retry_key)
        
        if retry_data:
            retry_dict = json.loads(retry_data)
            failed_msg = FailedMessage.from_dict(retry_dict)
            failed_msg.retry_count += 1
            failed_msg.last_failure = datetime.now()
        else:
            failed_msg = FailedMessage(
                original_message=original_message,
                failure_type=failure_type,
                error_details=error_details,
                retry_count=1
            )
        
        # Decide whether to retry or send to DLQ
        if failed_msg.retry_count <= settings.max_retries:
            # Schedule for retry with exponential backoff
            delay = settings.retry_delays[min(failed_msg.retry_count - 1, len(settings.retry_delays) - 1)]
            retry_time = datetime.now() + timedelta(seconds=delay)
            
            await self.redis.setex(
                retry_key,
                delay,
                json.dumps(failed_msg.to_dict(), default=str)
            )
            
            # Schedule message for retry
            await self.redis.zadd(
                settings.retry_queue,
                {message_data: retry_time.timestamp()}
            )
            
            logger.warning(f"Scheduled message {original_message.id} for retry {failed_msg.retry_count}/{settings.max_retries}")
        else:
            # Send to dead letter queue
            await self.redis.lpush(
                settings.dlq_queue,
                json.dumps(failed_msg.to_dict(), default=str)
            )
            
            # Remove from retry tracking
            await self.redis.delete(retry_key)
            
            logger.error(f"Message {original_message.id} sent to DLQ after {failed_msg.retry_count} attempts")
        
        self.failed_count += 1
    
    async def process_retry_queue(self):
        """Process messages scheduled for retry"""
        now = datetime.now().timestamp()
        
        # Get messages ready for retry
        ready_messages = await self.redis.zrangebyscore(
            settings.retry_queue,
            0,
            now,
            withscores=True
        )
        
        for message_data, score in ready_messages:
            # Remove from retry queue
            await self.redis.zrem(settings.retry_queue, message_data)
            
            # Add back to primary queue
            await self.redis.lpush(settings.primary_queue, message_data)
            
            logger.info(f"Moved message back to primary queue for retry")
    
    async def run(self):
        """Main processing loop"""
        self.running = True
        logger.info("Starting log processor")
        
        while self.running:
            try:
                # Process retry queue first
                await self.process_retry_queue()
                
                # Process primary queue
                message_data = await self.redis.brpop(settings.primary_queue, timeout=1)
                
                if message_data:
                    _, message = message_data
                    success = await self.process_message(message.decode())
                    
                    if self.processed_count % 100 == 0:
                        logger.info(f"Processed: {self.processed_count}, Failed: {self.failed_count}")
                
            except Exception as e:
                logger.error(f"Error in processing loop: {e}")
                await asyncio.sleep(1)
    
    def stop(self):
        self.running = False
    
    async def close(self):
        await self.redis.close()

if __name__ == "__main__":
    processor = LogProcessor()
    try:
        asyncio.run(processor.run())
    finally:
        asyncio.run(processor.close())
