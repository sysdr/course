from fastapi import APIRouter, HTTPException, BackgroundTasks
from typing import List
from ..webhook.models import WebhookSubscription, WebhookStats
from ..webhook.subscription_manager import SubscriptionManager
from ..webhook.delivery_engine import DeliveryEngine
from ..webhook.event_listener import EventListener

router = APIRouter()

# Global instances (in production, use dependency injection)
subscription_manager = SubscriptionManager()
delivery_engine = DeliveryEngine()
event_listener = EventListener(subscription_manager, delivery_engine)

@router.post("/subscriptions", response_model=WebhookSubscription)
async def create_subscription(subscription_data: dict):
    """Create a new webhook subscription"""
    try:
        subscription = await subscription_manager.create_subscription(subscription_data)
        return subscription
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/subscriptions", response_model=List[WebhookSubscription])
async def list_subscriptions():
    """List all webhook subscriptions"""
    return await subscription_manager.list_subscriptions()

@router.get("/subscriptions/{subscription_id}", response_model=WebhookSubscription)
async def get_subscription(subscription_id: str):
    """Get specific webhook subscription"""
    subscription = await subscription_manager.get_subscription(subscription_id)
    if not subscription:
        raise HTTPException(status_code=404, detail="Subscription not found")
    return subscription

@router.put("/subscriptions/{subscription_id}", response_model=WebhookSubscription)
async def update_subscription(subscription_id: str, updates: dict):
    """Update webhook subscription"""
    subscription = await subscription_manager.update_subscription(subscription_id, updates)
    if not subscription:
        raise HTTPException(status_code=404, detail="Subscription not found")
    return subscription

@router.delete("/subscriptions/{subscription_id}")
async def delete_subscription(subscription_id: str):
    """Delete webhook subscription"""
    success = await subscription_manager.delete_subscription(subscription_id)
    if not success:
        raise HTTPException(status_code=404, detail="Subscription not found")
    return {"message": "Subscription deleted successfully"}

@router.post("/events")
async def send_event(event_data: dict, background_tasks: BackgroundTasks):
    """Send a log event to trigger webhooks"""
    background_tasks.add_task(event_listener.process_log_event, event_data)
    return {"message": "Event queued for processing"}

@router.get("/stats")
async def get_webhook_stats():
    """Get webhook delivery statistics"""
    subscriptions = await subscription_manager.list_subscriptions()
    delivery_stats = await delivery_engine.get_delivery_stats()
    
    active_subscriptions = sum(1 for s in subscriptions if s.active)
    
    return {
        "total_subscriptions": len(subscriptions),
        "active_subscriptions": active_subscriptions,
        "delivery_stats": delivery_stats
    }

@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "webhook-notifications",
        "version": "1.0.0",
        "components": {
            "subscription_manager": "ready",
            "delivery_engine": "ready",
            "event_listener": "ready"
        }
    }
