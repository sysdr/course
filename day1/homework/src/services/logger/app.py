"""
Main application entry point for the logger service.
"""
import os
import time
import threading
from datetime import datetime
import random

import config
from logger import Logger
from web_server import LoggerWebServer

def generate_sample_logs(logger):
    """Generate some sample log messages of different levels."""
    log_messages = [
        ("debug", "Initializing system components"),
        ("info", "System started successfully"),
        ("info", "Processing incoming data batch"),
        ("debug", "Connection pool initialized with 5 connections"),
        ("warning", "High memory usage detected (85%)"),
        ("info", "Data processing completed in 1.2 seconds"),
        ("error", "Failed to connect to secondary database"),
        ("info", "Retrying connection in 5 seconds"),
        ("debug", "Cache hit ratio: 78.5%"),
        ("warning", "Slow query detected (2.5s execution time)"),
        ("info", "Successfully processed 1542 records"),
        ("critical", "Disk space critical: 98% full"),
        ("info", "Starting automated cleanup routine"),
        ("debug", "Cleanup freed 1.2GB of disk space"),
        ("info", "System operating within normal parameters")
    ]
    
    # Log initial messages
    for level, message in log_messages[:5]:
        logger.log(level, message)
    
    # Set up sample log generation
    def generate_logs():
        while True:
            # Random selection of messages
            level, message = random.choice(log_messages)
            logger.log(level, message)
            
            # Random sleep between 5-20 seconds
            sleep_time = random.uniform(5, 20)
            time.sleep(sleep_time)
    
    # Start sample log generation in a separate thread
    log_thread = threading.Thread(target=generate_logs, daemon=True)
    log_thread.start()

def main():
    """Main entry point for the logger service."""
    print("Starting distributed logger service...")
    
    # Initialize logger
    logger = Logger()
    logger.info("Logger service initialized")
    
    # Log configuration
    cfg = config.get_config()
    logger.info(f"Log level set to: {cfg['log_level']}")
    logger.info(f"Log frequency: {cfg['log_frequency']} seconds")
    
    if cfg["log_to_file"]:
        logger.info(f"Logging to file: {cfg['log_file_path']}")
        logger.info(f"Log rotation size: {cfg['log_max_size_mb']} MB")
    
    # Generate some sample logs
    generate_sample_logs(logger)
    
    # Start web server in a separate thread
    web_thread = threading.Thread(
        target=lambda: LoggerWebServer(logger).start(),
        daemon=True
    )
    web_thread.start()
    
    try:
        # Main loop - just keep the service running
        while True:
            # Service is alive message (at configured frequency)
            logger.info("Logger service is running as part of our distributed system")
            time.sleep(cfg["log_frequency"])
    except KeyboardInterrupt:
        logger.info("Logger service shutting down")

if __name__ == "__main__":
    main()