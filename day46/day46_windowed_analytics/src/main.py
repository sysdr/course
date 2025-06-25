import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../../src')))

import asyncio
import json
import random
import time
from datetime import datetime, timedelta
import yaml
import redis.asyncio as redis
import uvicorn
import structlog

# Use conditional imports to work both as script and module
try:
    from src.windowing.manager.window_manager import WindowManager
    from src.windowing.extractor.time_extractor import TimeExtractor
    from src.windowing.aggregator.aggregation_coordinator import (
        AggregationCoordinator, 
        calculate_throughput_metrics,
        calculate_sla_metrics
    )
    from src.web.dashboard import WindowingDashboard
except ImportError:
    # Fallback for when running as script
    from windowing.manager.window_manager import WindowManager
    from windowing.extractor.time_extractor import TimeExtractor
    from windowing.aggregator.aggregation_coordinator import (
        AggregationCoordinator, 
        calculate_throughput_metrics,
        calculate_sla_metrics
    )
    from web.dashboard import WindowingDashboard

# Configure structured logging
structlog.configure(
    processors=[
        structlog.dev.ConsoleRenderer()
    ],
    wrapper_class=structlog.make_filtering_bound_logger(20),
    logger_factory=structlog.PrintLoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

class WindowedAnalyticsSystem:
    def __init__(self, config_path="config/windowing_config.yaml"):
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
            
        self.redis_client = None
        self.window_manager = None
        self.time_extractor = None
        self.aggregation_coordinator = None
        self.dashboard = None
        
    async def start(self):
        """Start the windowed analytics system"""
        logger.info("Starting Windowed Analytics System")
        
        # Initialize Redis connection
        redis_config = self.config['redis']
        self.redis_client = redis.Redis(
            host=redis_config['host'],
            port=redis_config['port'],
            db=redis_config['db'],
            decode_responses=True
        )
        
        # Initialize components
        self.window_manager = WindowManager(self.redis_client, self.config)
        self.time_extractor = TimeExtractor(self.config['windowing']['timezone'])
        self.aggregation_coordinator = AggregationCoordinator(
            self.window_manager, self.redis_client
        )
        
        # Register custom aggregations
        self.aggregation_coordinator.register_aggregation(
            "throughput", calculate_throughput_metrics
        )
        self.aggregation_coordinator.register_aggregation(
            "sla", calculate_sla_metrics
        )
        
        # Start components
        await self.window_manager.start()
        await self.aggregation_coordinator.start()
        
        # Setup web dashboard
        self.dashboard = WindowingDashboard(
            self.window_manager, self.aggregation_coordinator
        )
        
        # Connect dashboard to aggregation coordinator for real-time updates
        self.aggregation_coordinator.set_dashboard(self.dashboard)
        
        logger.info("System started successfully")
        
    async def process_log_stream(self):
        """Simulate processing a log stream"""
        logger.info("Starting log stream simulation")
        
        services = ['api-gateway', 'user-service', 'payment-service', 'inventory']
        levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
        
        while True:
            try:
                # Generate synthetic log entries
                for _ in range(random.randint(5, 20)):
                    log_entry = {
                        'timestamp': int(time.time()),
                        'service': random.choice(services),
                        'level': random.choice(levels),
                        'message': f"Service operation completed",
                        'response_time': random.uniform(10, 500),
                        'user_id': f"user_{random.randint(1000, 9999)}"
                    }
                    
                    # Add some errors
                    if random.random() < 0.1:  # 10% error rate
                        log_entry['level'] = 'ERROR'
                        log_entry['response_time'] = random.uniform(1000, 5000)
                        
                    # Normalize log entry
                    normalized = self.time_extractor.normalize_log_entry(
                        json.dumps(log_entry)
                    )
                    
                    # Process through windowing system
                    await self.aggregation_coordinator.process_log_event(normalized)
                    
                await asyncio.sleep(0.1)  # Process ~100-200 events per second
                
            except Exception as e:
                logger.error("Error in log stream processing", error=str(e))
                await asyncio.sleep(1)

async def main():
    system = WindowedAnalyticsSystem()
    await system.start()
    
    # Start log stream processing in background
    asyncio.create_task(system.process_log_stream())
    
    # Start web server
    web_config = system.config['web']
    config = uvicorn.Config(
        system.dashboard.app,
        host=web_config['host'],
        port=web_config['port'],
        log_level="info"
    )
    
    server = uvicorn.Server(config)
    await server.serve()

if __name__ == "__main__":
    asyncio.run(main())
