import asyncio
import json
from datetime import datetime
from typing import List, Dict, Any

import redis.asyncio as redis
from src.models import FailedMessage, LogMessage, LogLevel, FailureType
from config.settings import settings
import structlog

logger = structlog.get_logger()

class DLQHandler:
    def __init__(self):
        self.redis = redis.from_url(settings.redis_url)
    
    async def get_dlq_stats(self) -> Dict[str, Any]:
        """Get dead letter queue statistics"""
        dlq_length = await self.redis.llen(settings.dlq_queue)
        retry_length = await self.redis.zcard(settings.retry_queue)
        primary_length = await self.redis.llen(settings.primary_queue)
        processed_count = await self.redis.hlen("processed_logs")
        
        return {
            "dlq_count": dlq_length,
            "retry_count": retry_length,
            "primary_count": primary_length,
            "processed_count": processed_count,
            "timestamp": datetime.now().isoformat()
        }
    
    async def get_dlq_messages(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Retrieve messages from dead letter queue"""
        messages = await self.redis.lrange(settings.dlq_queue, 0, limit - 1)
        
        dlq_messages = []
        for msg_data in messages:
            try:
                msg_dict = json.loads(msg_data.decode())
                dlq_messages.append(msg_dict)
            except Exception as e:
                logger.error(f"Error parsing DLQ message: {e}")
        
        return dlq_messages
    
    async def get_failure_analysis(self) -> Dict[str, Any]:
        """Analyze failure patterns in DLQ"""
        messages = await self.get_dlq_messages(1000)  # Analyze up to 1000 messages
        
        failure_types = {}
        sources = {}
        hourly_failures = {}
        
        for msg in messages:
            # Count failure types
            failure_type = msg.get("failure_type", "unknown")
            failure_types[failure_type] = failure_types.get(failure_type, 0) + 1
            
            # Count by source
            original_msg = msg.get("original_message", {})
            source = original_msg.get("source", "unknown")
            sources[source] = sources.get(source, 0) + 1
            
            # Count by hour
            first_failure = msg.get("first_failure", "")
            if first_failure:
                try:
                    dt = datetime.fromisoformat(first_failure.replace("Z", "+00:00"))
                    hour_key = dt.strftime("%Y-%m-%d %H:00")
                    hourly_failures[hour_key] = hourly_failures.get(hour_key, 0) + 1
                except:
                    pass
        
        return {
            "failure_types": failure_types,
            "failure_sources": sources,
            "hourly_failures": hourly_failures,
            "total_analyzed": len(messages)
        }
    
    async def reprocess_message(self, message_index: int) -> bool:
        """Reprocess a specific message from DLQ"""
        try:
            # Get the message at the specified index
            message_data = await self.redis.lindex(settings.dlq_queue, message_index)
            
            if not message_data:
                return False
            
            msg_dict = json.loads(message_data.decode())
            original_message = msg_dict["original_message"]
            
            # Add back to primary queue
            await self.redis.lpush(
                settings.primary_queue,
                json.dumps(original_message)
            )
            
            # Remove from DLQ
            await self.redis.lrem(settings.dlq_queue, 1, message_data)
            
            logger.info(f"Reprocessed message {original_message.get('id', 'unknown')}")
            return True
            
        except Exception as e:
            logger.error(f"Error reprocessing message: {e}")
            return False
    
    async def reprocess_by_failure_type(self, failure_type: str, limit: int = 10) -> int:
        """Reprocess messages by failure type"""
        messages = await self.get_dlq_messages(1000)
        reprocessed = 0
        
        for i, msg in enumerate(messages):
            if reprocessed >= limit:
                break
                
            if msg.get("failure_type") == failure_type:
                if await self.reprocess_message(i - reprocessed):  # Adjust index as we remove items
                    reprocessed += 1
        
        return reprocessed
    
    async def clear_dlq(self) -> int:
        """Clear all messages from DLQ"""
        length = await self.redis.llen(settings.dlq_queue)
        await self.redis.delete(settings.dlq_queue)
        return length
    
    async def close(self):
        await self.redis.close()
