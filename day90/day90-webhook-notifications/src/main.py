import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import uvicorn
from .api.routes import router, subscription_manager, delivery_engine, event_listener
from .webhook.models import EventType

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    print("🚀 Starting Webhook Notifications Service...")
    
    # Start delivery engine
    await delivery_engine.start()
    
    # Start event listener
    await event_listener.start()
    
    # Create demo subscriptions
    await create_demo_subscriptions()
    
    print("✅ Webhook Notifications Service started successfully")
    
    yield
    
    # Shutdown
    print("🛑 Shutting down Webhook Notifications Service...")
    
    await event_listener.stop()
    await delivery_engine.stop()
    
    print("✅ Shutdown complete")

app = FastAPI(
    title="Webhook Notifications Service",
    description="Real-time webhook notifications for log processing system",
    version="1.0.0",
    lifespan=lifespan
)

# Include API routes
app.include_router(router, prefix="/api/v1")

# Serve static files (React build)
app.mount("/", StaticFiles(directory="frontend/build", html=True), name="static")

async def create_demo_subscriptions():
    """Create demo webhook subscriptions for testing"""
    demo_subscriptions = [
        {
            "name": "Critical Error Notifications",
            "url": "https://httpbin.org/post",
            "events": [EventType.LOG_CRITICAL, EventType.LOG_ERROR],
            "filters": {"level": "CRITICAL"},
            "secret_key": "critical-webhook-secret"
        },
        {
            "name": "Payment Service Monitor",
            "url": "https://httpbin.org/post",
            "events": [EventType.LOG_ERROR, EventType.LOG_WARNING],
            "filters": {"source": "payment-service"},
            "secret_key": "payment-webhook-secret"
        },
        {
            "name": "All Events Monitor",
            "url": "https://httpbin.org/post",
            "events": list(EventType),
            "filters": {},
            "secret_key": "all-events-secret"
        }
    ]
    
    for sub_data in demo_subscriptions:
        try:
            subscription = await subscription_manager.create_subscription(sub_data)
            print(f"📋 Created demo subscription: {subscription.name}")
        except Exception as e:
            print(f"❌ Failed to create demo subscription: {e}")

if __name__ == "__main__":
    uvicorn.run(
        "src.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
