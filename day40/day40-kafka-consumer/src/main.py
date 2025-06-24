import asyncio
import threading
import time
import sys
import structlog
from config.kafka_config import KafkaConsumerConfig
from consumer.kafka_consumer import KafkaLogConsumer
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from web.dashboard import ConsumerDashboard

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

def main():
    """Main application entry point"""
    logger.info("Starting Kafka Consumer Application")
    
    # Create consumer configuration
    config = KafkaConsumerConfig()
    
    # Create consumer instance
    consumer = KafkaLogConsumer(config)
    
    # Create and configure dashboard
    dashboard = ConsumerDashboard(consumer)
    
    try:
        if len(sys.argv) > 1 and sys.argv[1] == "dashboard":
            # Start only dashboard for testing
            logger.info("Starting dashboard only")
            dashboard.start_server(host="0.0.0.0", port=8080)
        else:
            # Start consumer in a separate thread
            consumer_thread = threading.Thread(target=consumer.start, daemon=True)
            consumer_thread.start()
            
            # Wait a moment for consumer to initialize
            time.sleep(2)
            
            # Start dashboard server (blocking)
            logger.info("Starting dashboard server on http://0.0.0.0:8080")
            dashboard.start_server(host="0.0.0.0", port=8080)
            
    except KeyboardInterrupt:
        logger.info("Shutting down application")
        consumer.stop()
    except Exception as e:
        logger.error("Application error", error=str(e))
        consumer.stop()
        raise

if __name__ == "__main__":
    main()
