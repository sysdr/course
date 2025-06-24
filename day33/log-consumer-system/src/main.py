import asyncio
import json
import signal
import sys
from typing import Dict, Any
from src.consumers.consumer_manager import ConsumerManager
from src.monitoring.dashboard import app, set_consumer_manager
import uvicorn
import structlog

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

async def main():
    """Main application entry point"""
    config = {
        "redis_url": "redis://localhost:6379",
        "queue_name": "logs",
        "consumer_group": "log-processors",
        "num_consumers": 2,
        "batch_size": 10
    }
    
    # Create consumer manager
    manager = ConsumerManager(config)
    set_consumer_manager(manager)
    
    # Start dashboard server in background
    dashboard_task = asyncio.create_task(
        asyncio.to_thread(
            uvicorn.run, app, host="0.0.0.0", port=8000, log_level="info"
        )
    )
    
    logger.info("Starting log consumer system...")
    logger.info("Dashboard available at: http://localhost:8000")
    
    try:
        # Start consumer manager
        await manager.start()
    except KeyboardInterrupt:
        logger.info("Received interrupt signal")
    except Exception as e:
        logger.error(f"Application error: {e}")
    finally:
        await manager.stop()
        dashboard_task.cancel()
        logger.info("Application stopped")

if __name__ == "__main__":
    asyncio.run(main())
