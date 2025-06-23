import json
import asyncio
import threading
from typing import Dict, Optional
from datetime import datetime
from confluent_kafka import Consumer, KafkaException
from src.models.user_profile import UserProfile, StateUpdate
from src.config.kafka_config import KafkaConfig
import structlog

logger = structlog.get_logger(__name__)


class StateConsumer:
    """State consumer for rebuilding current state from compacted logs"""
    
    def __init__(self, kafka_config: KafkaConfig):
        self.kafka_config = kafka_config
        self.consumer = kafka_config.create_consumer()
        self.topic_name = kafka_config.topic_name
        self.current_state: Dict[str, UserProfile] = {}
        self.running = False
        self._consumer_thread = None
        
    def start_consuming(self):
        """Start consuming messages in background thread"""
        if self.running:
            logger.warning("Consumer already running")
            return
            
        self.running = True
        self.consumer.subscribe([self.topic_name])
        
        self._consumer_thread = threading.Thread(
            target=self._consume_loop,
            name="StateConsumer-Thread"
        )
        self._consumer_thread.start()
        
        logger.info(
            "State consumer started",
            topic=self.topic_name,
            group_id=self.kafka_config.consumer_config['group_id']
        )
    
    def _consume_loop(self):
        """Main consumer loop"""
        logger.info("Starting consumption loop")
        
        while self.running:
            try:
                msg = self.consumer.poll(timeout=1.0)
                
                if msg is None:
                    continue
                    
                if msg.error():
                    logger.error(
                        "Consumer error",
                        error=str(msg.error())
                    )
                    continue
                
                self._process_message(msg)
                
                # Commit offset after processing
                self.consumer.commit(asynchronous=False)
                
            except KafkaException as e:
                logger.error(
                    "Kafka exception in consumer loop",
                    error=str(e)
                )
            except Exception as e:
                logger.error(
                    "Unexpected error in consumer loop",
                    error=str(e)
                )
    
    def _process_message(self, msg):
        """Process individual message"""
        try:
            key = msg.key().decode('utf-8') if msg.key() else None
            value = msg.value().decode('utf-8') if msg.value() else None
            
            logger.debug(
                "Processing message",
                key=key,
                partition=msg.partition(),
                offset=msg.offset()
            )
            
            if value is None:
                # Tombstone record - remove from state
                user_id = key.replace("profile:", "") if key else None
                if user_id and user_id in self.current_state:
                    del self.current_state[user_id]
                    logger.info(
                        "Removed user from state (tombstone)",
                        user_id=user_id
                    )
                return
            
            # Parse state update
            update_data = json.loads(value)
            update = StateUpdate(**update_data)
            
            if not update.profile:
                logger.warning(
                    "State update missing profile data",
                    event_id=update.event_id
                )
                return
            
            profile = UserProfile(**update.profile.dict())
            
            if profile.deleted:
                # Logical deletion
                if profile.user_id in self.current_state:
                    del self.current_state[profile.user_id]
                    logger.info(
                        "Removed user from state (deleted)",
                        user_id=profile.user_id
                    )
            else:
                # Update or create
                existing = self.current_state.get(profile.user_id)
                if existing is None or profile.version > existing.version:
                    self.current_state[profile.user_id] = profile
                    logger.info(
                        "Updated state for user",
                        user_id=profile.user_id,
                        version=profile.version,
                        action="created" if existing is None else "updated"
                    )
                else:
                    logger.debug(
                        "Skipped older version",
                        user_id=profile.user_id,
                        current_version=existing.version,
                        received_version=profile.version
                    )
                    
        except Exception as e:
            logger.error(
                "Error processing message",
                error=str(e),
                key=key,
                partition=msg.partition(),
                offset=msg.offset()
            )
    
    def get_current_state(self) -> Dict[str, UserProfile]:
        """Get copy of current state"""
        return self.current_state.copy()
    
    def get_user_profile(self, user_id: str) -> Optional[UserProfile]:
        """Get specific user profile"""
        return self.current_state.get(user_id)
    
    def get_state_size(self) -> int:
        """Get number of profiles in current state"""
        return len(self.current_state)
    
    def get_state_stats(self) -> Dict[str, int]:
        """Get state statistics"""
        return {
            "total_profiles": len(self.current_state),
            "active_profiles": len([p for p in self.current_state.values() if not p.deleted]),
            "deleted_profiles": len([p for p in self.current_state.values() if p.deleted])
        }
    
    def stop(self):
        """Stop consumer"""
        self.running = False
        
        if self._consumer_thread and self._consumer_thread.is_alive():
            self._consumer_thread.join(timeout=5)
        
        self.consumer.close()
        logger.info("State consumer stopped")


class AsyncStateConsumer:
    """Async wrapper for state consumer"""
    
    def __init__(self, kafka_config: KafkaConfig):
        self.consumer = StateConsumer(kafka_config)
    
    async def start_consuming(self):
        """Start consuming asynchronously"""
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self.consumer.start_consuming)
    
    def get_current_state(self) -> Dict[str, UserProfile]:
        """Get current state"""
        return self.consumer.get_current_state()
    
    def get_user_profile(self, user_id: str) -> Optional[UserProfile]:
        """Get user profile"""
        return self.consumer.get_user_profile(user_id)
    
    def get_state_size(self) -> int:
        """Get state size"""
        return self.consumer.get_state_size()
    
    def get_state_stats(self) -> Dict[str, int]:
        """Get state statistics"""
        return self.consumer.get_state_stats()
    
    def stop(self):
        """Stop consumer"""
        self.consumer.stop()
