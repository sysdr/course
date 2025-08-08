import asyncio
import aiohttp
import hashlib
import hmac
import json
import time
from datetime import datetime
from typing import List, Optional, Dict
from .models import WebhookSubscription, WebhookDelivery, DeliveryStatus, LogEvent
import structlog

logger = structlog.get_logger()

class DeliveryEngine:
    def __init__(self, max_concurrent: int = 100):
        self.max_concurrent = max_concurrent
        self.deliveries: Dict[str, WebhookDelivery] = {}
        self.delivery_queue = asyncio.Queue(maxsize=10000)
        self.session: Optional[aiohttp.ClientSession] = None
        self.workers_running = False
        
    async def start(self):
        """Start the delivery engine"""
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=30)
        )
        self.workers_running = True
        
        # Start worker tasks
        self.worker_tasks = [
            asyncio.create_task(self._delivery_worker(f"worker-{i}"))
            for i in range(self.max_concurrent)
        ]
        
        print(f"🚀 Started {self.max_concurrent} webhook delivery workers")
    
    async def stop(self):
        """Stop the delivery engine"""
        self.workers_running = False
        
        # Cancel worker tasks
        for task in self.worker_tasks:
            task.cancel()
        
        await asyncio.gather(*self.worker_tasks, return_exceptions=True)
        
        if self.session:
            await self.session.close()
    
    async def queue_delivery(self, subscription: WebhookSubscription, event: LogEvent) -> str:
        """Queue a webhook delivery"""
        delivery_id = f"delivery_{int(time.time() * 1000)}_{id(event)}"
        
        payload = {
            "event": {
                "id": event.id,
                "type": event.event_type.value,
                "timestamp": event.timestamp.isoformat(),
                "data": {
                    "level": event.level,
                    "source": event.source,
                    "message": event.message,
                    "metadata": event.metadata
                }
            },
            "subscription": {
                "id": subscription.id,
                "name": subscription.name
            }
        }
        
        delivery = WebhookDelivery(
            id=delivery_id,
            subscription_id=subscription.id,
            event_id=event.id,
            url=str(subscription.url),
            payload=payload,
            status=DeliveryStatus.PENDING,
            created_at=datetime.utcnow()
        )
        
        self.deliveries[delivery_id] = delivery
        await self.delivery_queue.put((delivery, subscription))
        
        return delivery_id
    
    async def _delivery_worker(self, worker_name: str):
        """Worker that processes delivery queue"""
        while self.workers_running:
            try:
                # Get delivery from queue with timeout
                delivery, subscription = await asyncio.wait_for(
                    self.delivery_queue.get(), timeout=1.0
                )
                
                await self._attempt_delivery(delivery, subscription)
                
            except asyncio.TimeoutError:
                continue
            except Exception as e:
                logger.error(f"Delivery worker {worker_name} error: {e}")
    
    async def _attempt_delivery(self, delivery: WebhookDelivery, subscription: WebhookSubscription):
        """Attempt to deliver webhook"""
        delivery.status = DeliveryStatus.DELIVERING
        delivery.attempt_count += 1
        delivery.last_attempt = datetime.utcnow()
        
        try:
            # Prepare payload
            payload_json = json.dumps(delivery.payload)
            signature = self._generate_signature(payload_json, subscription.secret_key)
            
            headers = {
                "Content-Type": "application/json",
                "X-Webhook-Signature": signature,
                "X-Webhook-Delivery": delivery.id,
                "User-Agent": "LogPlatform-Webhooks/1.0"
            }
            
            # Send webhook
            async with self.session.post(
                delivery.url,
                data=payload_json,
                headers=headers
            ) as response:
                delivery.response_code = response.status
                delivery.response_body = await response.text()
                
                if 200 <= response.status < 300:
                    delivery.status = DeliveryStatus.DELIVERED
                    logger.info(f"✅ Webhook delivered: {delivery.id} -> {delivery.url}")
                else:
                    delivery.status = DeliveryStatus.FAILED
                    delivery.error_message = f"HTTP {response.status}: {delivery.response_body[:500]}"
                    logger.warning(f"❌ Webhook delivery failed: {delivery.id} -> HTTP {response.status}")
                    
                    # Schedule retry if attempts remaining
                    if delivery.attempt_count < 3:
                        await self._schedule_retry(delivery, subscription)
        
        except Exception as e:
            delivery.status = DeliveryStatus.FAILED
            delivery.error_message = str(e)
            logger.error(f"❌ Webhook delivery error: {delivery.id} -> {e}")
            
            # Schedule retry if attempts remaining
            if delivery.attempt_count < 3:
                await self._schedule_retry(delivery, subscription)
    
    async def _schedule_retry(self, delivery: WebhookDelivery, subscription: WebhookSubscription):
        """Schedule retry with exponential backoff"""
        delay = min(300, (2 ** delivery.attempt_count))  # Max 5 minutes
        
        asyncio.create_task(self._retry_after_delay(delivery, subscription, delay))
        logger.info(f"🔄 Scheduled retry for {delivery.id} in {delay} seconds")
    
    async def _retry_after_delay(self, delivery: WebhookDelivery, subscription: WebhookSubscription, delay: float):
        """Retry delivery after delay"""
        await asyncio.sleep(delay)
        delivery.status = DeliveryStatus.PENDING
        await self.delivery_queue.put((delivery, subscription))
    
    def _generate_signature(self, payload: str, secret: str) -> str:
        """Generate HMAC signature for webhook payload"""
        signature = hmac.new(
            secret.encode('utf-8'),
            payload.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        return f"sha256={signature}"
    
    async def get_delivery_stats(self) -> dict:
        """Get delivery statistics"""
        total = len(self.deliveries)
        delivered = sum(1 for d in self.deliveries.values() if d.status == DeliveryStatus.DELIVERED)
        failed = sum(1 for d in self.deliveries.values() if d.status == DeliveryStatus.FAILED)
        pending = sum(1 for d in self.deliveries.values() if d.status == DeliveryStatus.PENDING)
        
        return {
            "total_deliveries": total,
            "delivered": delivered,
            "failed": failed,
            "pending": pending,
            "success_rate": (delivered / total * 100) if total > 0 else 0
        }
