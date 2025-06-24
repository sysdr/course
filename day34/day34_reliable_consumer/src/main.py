#!/usr/bin/env python3
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import threading
import time
from src.reliable_consumer import ReliableConsumer
from src.log_processor import LogProcessor
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

def main():
    """Main application entry point"""
    logger.info("Starting Reliable Consumer Demo")
    
    # Create log processor with some failure rate for testing
    log_processor = LogProcessor(failure_rate=0.2, timeout_rate=0.1)
    
    # Create reliable consumer
    consumer = ReliableConsumer(processing_callback=log_processor.process_log_entry)
    
    try:
        # Connect to RabbitMQ
        consumer.connect()
        
        # Start stats reporting in background
        stats_thread = threading.Thread(target=report_stats, args=(consumer, log_processor), daemon=True)
        stats_thread.start()
        
        # Start consuming messages
        logger.info("Starting message consumption...")
        consumer.start_consuming()
        
    except KeyboardInterrupt:
        logger.info("Shutting down...")
    except Exception as e:
        logger.error("Application error", error=str(e))
    finally:
        consumer.close()
        logger.info("Application stopped")

def report_stats(consumer: ReliableConsumer, processor: LogProcessor):
    """Report statistics periodically"""
    while True:
        try:
            time.sleep(10)  # Report every 10 seconds
            consumer_stats = consumer.get_stats()
            processor_stats = processor.get_stats()
            
            logger.info("Consumer Statistics", **consumer_stats)
            logger.info("Processor Statistics", **processor_stats)
            
        except Exception as e:
            logger.error("Error reporting stats", error=str(e))

if __name__ == "__main__":
    main()
