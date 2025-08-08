import asyncio
import uuid
from datetime import datetime
from typing import List, Optional, Dict, Any
from .models import WebhookSubscription, EventType, LogEvent
import json
import re

class SubscriptionManager:
    def __init__(self):
        self.subscriptions: Dict[str, WebhookSubscription] = {}
        
    async def create_subscription(self, subscription_data: dict) -> WebhookSubscription:
        """Create a new webhook subscription"""
        subscription_id = str(uuid.uuid4())
        subscription = WebhookSubscription(
            id=subscription_id,
            name=subscription_data.get('name'),
            url=subscription_data.get('url'),
            events=subscription_data.get('events', []),
            filters=subscription_data.get('filters', {}),
            secret_key=subscription_data.get('secret_key', str(uuid.uuid4())),
            active=subscription_data.get('active', True),
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        
        self.subscriptions[subscription_id] = subscription
        print(f"✅ Created webhook subscription: {subscription.name} ({subscription_id})")
        return subscription
    
    async def get_subscription(self, subscription_id: str) -> Optional[WebhookSubscription]:
        """Get subscription by ID"""
        return self.subscriptions.get(subscription_id)
    
    async def list_subscriptions(self) -> List[WebhookSubscription]:
        """List all subscriptions"""
        return list(self.subscriptions.values())
    
    async def update_subscription(self, subscription_id: str, updates: dict) -> Optional[WebhookSubscription]:
        """Update existing subscription"""
        if subscription_id not in self.subscriptions:
            return None
            
        subscription = self.subscriptions[subscription_id]
        for key, value in updates.items():
            if hasattr(subscription, key):
                setattr(subscription, key, value)
        
        subscription.updated_at = datetime.utcnow()
        return subscription
    
    async def delete_subscription(self, subscription_id: str) -> bool:
        """Delete subscription"""
        if subscription_id in self.subscriptions:
            del self.subscriptions[subscription_id]
            return True
        return False
    
    async def get_matching_subscriptions(self, event: LogEvent) -> List[WebhookSubscription]:
        """Get subscriptions that match the given event"""
        matching = []
        
        for subscription in self.subscriptions.values():
            if not subscription.active:
                continue
                
            # Check event type match
            if event.event_type not in subscription.events:
                continue
            
            # Check filters
            if self._matches_filters(event, subscription.filters):
                matching.append(subscription)
        
        return matching
    
    def _matches_filters(self, event: LogEvent, filters: Dict[str, Any]) -> bool:
        """Check if event matches subscription filters"""
        if not filters:
            return True
            
        for filter_key, filter_value in filters.items():
            if filter_key == "level":
                if event.level.lower() != filter_value.lower():
                    return False
            elif filter_key == "source":
                if isinstance(filter_value, str):
                    if not re.search(filter_value, event.source):
                        return False
                elif isinstance(filter_value, list):
                    if event.source not in filter_value:
                        return False
            elif filter_key == "message_contains":
                if filter_value.lower() not in event.message.lower():
                    return False
        
        return True
