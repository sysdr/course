import uvicorn
import structlog
from config.settings import settings

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

if __name__ == "__main__":
    print("🚀 Starting Sliding Window Analytics System...")
    print(f"📊 Window Size: {settings.window_size_seconds} seconds")
    print(f"⏱️  Slide Interval: {settings.slide_interval_seconds} seconds")
    print(f"🌐 Dashboard: http://{settings.api_host}:{settings.api_port}")
    
    uvicorn.run(
        "src.api.main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=True,
        log_level="info"
    )
