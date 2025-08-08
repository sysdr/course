import pytest
import asyncio
from datetime import datetime
from src.webhook.subscription_manager import SubscriptionManager
from src.webhook.delivery_engine import DeliveryEngine
from src.webhook.event_listener import EventListener
from src.webhook.models import LogEvent, EventType

@pytest.mark.asyncio
async def test_end_to_end_webhook_flow():
    # Setup components
    subscription_manager = SubscriptionManager()
    delivery_engine = DeliveryEngine(max_concurrent=5)
    event_listener = EventListener(subscription_manager, delivery_engine)
    
    await delivery_engine.start()
    await event_listener.start()
    
    try:
        # Create test subscription
        subscription_data = {
            "name": "Test Integration",
            "url": "https://httpbin.org/post",
            "events": ["log.error"],
            "filters": {},
            "secret_key": "test-secret"
        }
        
        subscription = await subscription_manager.create_subscription(subscription_data)
        
        # Send test event
        event_data = {
            "level": "ERROR",
            "source": "test-service",
            "message": "Integration test error",
            "event_type": "log.error",
            "metadata": {"test": True}
        }
        
        delivery_ids = await event_listener.process_log_event(event_data)
        assert len(delivery_ids) == 1
        
        # Wait for delivery attempt
        await asyncio.sleep(2)
        
        # Check delivery stats
        stats = await delivery_engine.get_delivery_stats()
        assert stats["total_deliveries"] >= 1
        
    finally:
        await event_listener.stop()
        await delivery_engine.stop()

if __name__ == "__main__":
    pytest.main([__file__])
