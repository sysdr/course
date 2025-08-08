import pytest
from datetime import datetime
from src.webhook.subscription_manager import SubscriptionManager
from src.webhook.models import LogEvent, EventType

@pytest.mark.asyncio
async def test_create_subscription():
    manager = SubscriptionManager()
    
    subscription_data = {
        "name": "Test Webhook",
        "url": "https://example.com/webhook",
        "events": ["log.error"],
        "filters": {"level": "ERROR"}
    }
    
    subscription = await manager.create_subscription(subscription_data)
    
    assert subscription.name == "Test Webhook"
    assert str(subscription.url) == "https://example.com/webhook"
    assert len(subscription.events) == 1
    assert subscription.id is not None

@pytest.mark.asyncio
async def test_subscription_matching():
    manager = SubscriptionManager()
    
    # Create subscription
    subscription_data = {
        "name": "Error Webhook",
        "url": "https://example.com/webhook",
        "events": ["log.error"],
        "filters": {"level": "ERROR", "source": "payment-service"}
    }
    
    await manager.create_subscription(subscription_data)
    
    # Test matching event
    matching_event = LogEvent(
        id="test-1",
        timestamp=datetime.utcnow(),
        level="ERROR",
        source="payment-service",
        message="Test error",
        event_type=EventType.LOG_ERROR,
        metadata={}
    )
    
    matches = await manager.get_matching_subscriptions(matching_event)
    assert len(matches) == 1
    
    # Test non-matching event
    non_matching_event = LogEvent(
        id="test-2",
        timestamp=datetime.utcnow(),
        level="INFO",
        source="payment-service",
        message="Test info",
        event_type=EventType.LOG_INFO,
        metadata={}
    )
    
    matches = await manager.get_matching_subscriptions(non_matching_event)
    assert len(matches) == 0

if __name__ == "__main__":
    pytest.main([__file__])
