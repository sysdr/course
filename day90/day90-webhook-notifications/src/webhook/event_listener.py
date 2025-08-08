import asyncio
import json
from datetime import datetime
from typing import List
from .models import LogEvent, EventType
from .subscription_manager import SubscriptionManager
from .delivery_engine import DeliveryEngine
import structlog

logger = structlog.get_logger()

class EventListener:
    def __init__(self, subscription_manager: SubscriptionManager, delivery_engine: DeliveryEngine):
        self.subscription_manager = subscription_manager
        self.delivery_engine = delivery_engine
        self.running = False
        
    async def start(self):
        """Start listening for log events"""
        self.running = True
        print("👂 Event listener started")
        
        # Start demo event generator for testing
        asyncio.create_task(self._demo_event_generator())
    
    async def stop(self):
        """Stop listening for log events"""
        self.running = False
        print("🛑 Event listener stopped")
    
    async def process_log_event(self, event_data: dict):
        """Process incoming log event and trigger webhooks"""
        try:
            # Convert event data to LogEvent
            event = LogEvent(
                id=event_data.get('id', f"event_{int(datetime.utcnow().timestamp())}"),
                timestamp=datetime.fromisoformat(event_data.get('timestamp', datetime.utcnow().isoformat())),
                level=event_data.get('level', 'INFO'),
                source=event_data.get('source', 'unknown'),
                message=event_data.get('message', ''),
                metadata=event_data.get('metadata', {}),
                event_type=EventType(event_data.get('event_type', 'log.info'))
            )
            
            # Find matching subscriptions
            matching_subscriptions = await self.subscription_manager.get_matching_subscriptions(event)
            
            # Queue webhooks for delivery
            delivery_ids = []
            for subscription in matching_subscriptions:
                delivery_id = await self.delivery_engine.queue_delivery(subscription, event)
                delivery_ids.append(delivery_id)
            
            logger.info(f"📤 Queued {len(delivery_ids)} webhook deliveries for event {event.id}")
            return delivery_ids
            
        except Exception as e:
            logger.error(f"Error processing log event: {e}")
            return []
    
    async def _demo_event_generator(self):
        """Generate demo events for testing"""
        await asyncio.sleep(5)  # Wait for system to start
        
        demo_events = [
            {
                "level": "ERROR",
                "source": "payment-service",
                "message": "Payment processing failed for transaction TX123",
                "event_type": "log.error",
                "metadata": {"transaction_id": "TX123", "amount": 99.99}
            },
            {
                "level": "CRITICAL",
                "source": "database",
                "message": "Database connection pool exhausted",
                "event_type": "log.critical",
                "metadata": {"pool_size": 50, "active_connections": 50}
            },
            {
                "level": "WARNING",
                "source": "api-gateway",
                "message": "High response time detected",
                "event_type": "log.warning",
                "metadata": {"avg_response_time": 2500, "threshold": 1000}
            },
            {
                "level": "INFO",
                "source": "user-service",
                "message": "New user registration completed",
                "event_type": "log.info",
                "metadata": {"user_id": "user_456", "email": "user@example.com"}
            }
        ]
        
        counter = 0
        while self.running:
            for event_template in demo_events:
                if not self.running:
                    break
                    
                event = event_template.copy()
                event["id"] = f"demo_event_{counter}"
                event["timestamp"] = datetime.utcnow().isoformat()
                
                await self.process_log_event(event)
                counter += 1
                
                await asyncio.sleep(10)  # Generate event every 10 seconds
