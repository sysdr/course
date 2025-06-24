import json
import uuid
import asyncio
from typing import Optional, Dict, Any
from datetime import datetime
from confluent_kafka import Producer
from src.models.user_profile import UserProfile, StateUpdate, UpdateType
from src.config.kafka_config import KafkaConfig
import structlog

logger = structlog.get_logger(__name__)


class StateProducer:
    """State producer with exactly-once semantics for log compaction"""
    
    def __init__(self, kafka_config: KafkaConfig):
        self.kafka_config = kafka_config
        self.producer = kafka_config.create_producer()
        self.topic_name = kafka_config.topic_name
        
    def send_profile_update(self, profile: UserProfile) -> bool:
        """Send profile update with exactly-once semantics"""
        try:
            event_id = str(uuid.uuid4())
            update = StateUpdate(
                event_id=event_id,
                user_id=profile.user_id,
                update_type=UpdateType.UPDATE,
                profile=profile
            )
            
            key = f"profile:{profile.user_id}"
            value = json.dumps(update.to_dict(), default=str)
            
            self.producer.produce(
                topic=self.topic_name,
                key=key,
                value=value,
                callback=self._delivery_callback
            )
            
            # Flush to ensure delivery
            self.producer.flush(timeout=10)
            
            logger.info(
                "Profile update sent",
                user_id=profile.user_id,
                version=profile.version,
                event_id=event_id
            )
            
            return True
            
        except Exception as e:
            logger.error(
                "Failed to send profile update",
                user_id=profile.user_id,
                error=str(e)
            )
            return False
    
    def send_profile_deletion(self, user_id: str) -> bool:
        """Send profile deletion event"""
        try:
            event_id = str(uuid.uuid4())
            deleted_profile = UserProfile(
                user_id=user_id,
                email="",
                first_name="",
                last_name=""
            ).mark_deleted()
            
            update = StateUpdate(
                event_id=event_id,
                user_id=user_id,
                update_type=UpdateType.DELETE,
                profile=deleted_profile
            )
            
            key = f"profile:{user_id}"
            value = json.dumps(update.to_dict(), default=str)
            
            self.producer.produce(
                topic=self.topic_name,
                key=key,
                value=value,
                callback=self._delivery_callback
            )
            
            self.producer.flush(timeout=10)
            
            logger.info(
                "Profile deletion sent",
                user_id=user_id,
                event_id=event_id
            )
            
            return True
            
        except Exception as e:
            logger.error(
                "Failed to send profile deletion",
                user_id=user_id,
                error=str(e)
            )
            return False
    
    def send_tombstone(self, user_id: str) -> bool:
        """Send tombstone record (null value) for final cleanup"""
        try:
            key = f"profile:{user_id}"
            
            self.producer.produce(
                topic=self.topic_name,
                key=key,
                value=None,  # Tombstone record
                callback=self._delivery_callback
            )
            
            self.producer.flush(timeout=10)
            
            logger.info(
                "Tombstone sent",
                user_id=user_id
            )
            
            return True
            
        except Exception as e:
            logger.error(
                "Failed to send tombstone",
                user_id=user_id,
                error=str(e)
            )
            return False
    
    def _delivery_callback(self, err, msg):
        """Callback for message delivery confirmation"""
        if err is not None:
            logger.error(
                "Message delivery failed",
                error=str(err),
                topic=msg.topic(),
                partition=msg.partition() if msg else None
            )
        else:
            logger.debug(
                "Message delivered",
                topic=msg.topic(),
                partition=msg.partition(),
                offset=msg.offset(),
                key=msg.key().decode('utf-8') if msg.key() else None
            )
    
    def close(self):
        """Close producer and cleanup resources"""
        self.producer.flush()
        logger.info("State producer closed")


# Async wrapper for better integration
class AsyncStateProducer:
    """Async wrapper for state producer"""
    
    def __init__(self, kafka_config: KafkaConfig):
        self.producer = StateProducer(kafka_config)
    
    async def send_profile_update(self, profile: UserProfile) -> bool:
        """Async profile update"""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None, self.producer.send_profile_update, profile
        )
    
    async def send_profile_deletion(self, user_id: str) -> bool:
        """Async profile deletion"""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None, self.producer.send_profile_deletion, user_id
        )
    
    async def send_tombstone(self, user_id: str) -> bool:
        """Async tombstone"""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None, self.producer.send_tombstone, user_id
        )
    
    def close(self):
        """Close producer"""
        self.producer.close()
