import asyncio
import uvicorn
import structlog
from dashboard.dashboard_api import app

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

if __name__ == "__main__":
    logger.info("Starting Log Performance Profiler Dashboard")
    uvicorn.run(
        "dashboard.dashboard_api:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )
