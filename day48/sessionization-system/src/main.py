import asyncio
import sys
import structlog
from pathlib import Path

# Add src to path for imports
sys.path.append(str(Path(__file__).parent))

from web.app import app
from engine.sessionizer import DistributedSessionizer
from analytics.analyzer import SessionAnalyzer
from config.settings import config

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

async def main():
    """Main application entry point"""
    logger = structlog.get_logger()
    
    try:
        logger.info("Starting Sessionization System")
        
        # Initialize components
        sessionizer = DistributedSessionizer(config)
        await sessionizer.initialize()
        
        analyzer = SessionAnalyzer()
        
        logger.info("System initialized successfully")
        
        # Run web server using uvicorn
        import uvicorn
        uvicorn.run(
            "src.web.app:app",
            host=config.web_host,
            port=config.web_port,
            reload=False,
            log_level="info"
        )
        
    except KeyboardInterrupt:
        logger.info("Shutting down...")
    except Exception as e:
        logger.error("System error", error=str(e))
        raise

if __name__ == "__main__":
    asyncio.run(main())
