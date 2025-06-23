#!/usr/bin/env python3

import asyncio
import signal
import sys
import time
import random
import uuid
from datetime import datetime
from typing import List

from src.config.kafka_config import KafkaConfig
from src.config.app_config import AppConfig
from src.models.user_profile import UserProfile
from src.producer.state_producer import AsyncStateProducer
from src.consumer.state_consumer import AsyncStateConsumer
from src.monitor.compaction_monitor import AsyncCompactionMonitor
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

logger = structlog.get_logger(__name__)


class LogCompactionDemo:
    """Main demo application for log compaction"""
    
    def __init__(self):
        self.kafka_config = KafkaConfig.from_yaml()
        self.app_config = AppConfig.from_yaml()
        
        self.producer = AsyncStateProducer(self.kafka_config)
        self.consumer = AsyncStateConsumer(self.kafka_config)
        self.monitor = AsyncCompactionMonitor(self.kafka_config, self.app_config)
        
        self.running = False
        
    async def setup_infrastructure(self):
        """Setup Kafka topics and infrastructure"""
        logger.info("Setting up Kafka infrastructure")
        
        # Create compacted topic
        success = self.kafka_config.create_compacted_topic()
        if not success:
            raise Exception("Failed to create compacted topic")
        
        logger.info("✅ Kafka infrastructure ready")
    
    async def start_services(self):
        """Start all services"""
        logger.info("Starting services")
        
        # Start consumer
        await self.consumer.start_consuming()
        
        # Start monitoring
        await self.monitor.start_monitoring()
        
        # Wait for services to initialize
        await asyncio.sleep(3)
        
        logger.info("✅ All services started")
    
    async def run_demo(self):
        """Run the complete demo"""
        logger.info("🚀 Starting Kafka Log Compaction Demo")
        
        await self.setup_infrastructure()
        await self.start_services()
        
        # Demo data
        first_names = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry"]
        last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"]
        domains = ["gmail.com", "yahoo.com", "hotmail.com", "company.com"]
        
        logger.info("📊 Starting profile state management demo")
        
        # Phase 1: Create initial profiles
        logger.info("Phase 1: Creating initial user profiles")
        for i in range(1, 11):
            user_id = f"user_{i:03d}"
            first_name = random.choice(first_names)
            last_name = random.choice(last_names)
            email = f"{first_name.lower()}.{last_name.lower()}@{random.choice(domains)}"
            
            profile = UserProfile(
                user_id=user_id,
                email=email,
                first_name=first_name,
                last_name=last_name,
                age=20 + random.randint(0, 40),
                preferences="theme:dark,notifications:on"
            )
            
            await self.producer.send_profile_update(profile)
            await asyncio.sleep(0.5)  # Stagger messages
        
        logger.info("✅ Created 10 initial user profiles")
        await asyncio.sleep(5)  # Wait for consumption
        
        # Show current state
        state_size = self.consumer.get_state_size()
        logger.info(f"📋 Current state size: {state_size}")
        
        # Phase 2: Simulate profile updates (creates compaction opportunities)
        logger.info("Phase 2: Simulating profile updates")
        for round_num in range(1, 4):
            logger.info(f"Round {round_num} of updates")
            
            for i in range(1, 11):
                user_id = f"user_{i:03d}"
                existing = self.consumer.get_user_profile(user_id)
                
                if existing:
                    # Update profile
                    updated_profile = UserProfile(
                        user_id=existing.user_id,
                        email=f"{existing.first_name.lower()}{round_num}@updated.com",
                        first_name=existing.first_name,
                        last_name=existing.last_name,
                        age=existing.age + 1,
                        preferences=f"theme:light,notifications:{'on' if random.random() > 0.5 else 'off'}",
                        version=existing.version
                    ).increment_version()
                    
                    await self.producer.send_profile_update(updated_profile)
                
                await asyncio.sleep(0.2)
            
            logger.info(f"✅ Completed update round {round_num}")
            await asyncio.sleep(3)
        
        # Phase 3: Delete some profiles
        logger.info("Phase 3: Simulating profile deletions")
        for i in range(8, 11):
            user_id = f"user_{i:03d}"
            await self.producer.send_profile_deletion(user_id)
            await asyncio.sleep(1)
        
        logger.info("✅ Deleted 3 user profiles")
        await asyncio.sleep(5)
        
        # Final state summary
        await self.show_final_summary()
        
    async def show_final_summary(self):
        """Show final state summary"""
        logger.info("📊 Final state summary")
        
        current_state = self.consumer.get_current_state()
        state_stats = self.consumer.get_state_stats()
        compaction_metrics = self.monitor.get_compaction_effectiveness()
        
        logger.info(
            "State Summary",
            active_profiles=state_stats['active_profiles'],
            total_profiles=state_stats['total_profiles'],
            compaction_ratio=f"{compaction_metrics['compaction_ratio']:.2%}",
            storage_saved=f"{compaction_metrics['storage_saved_percent']:.1f}%"
        )
        
        for user_id, profile in current_state.items():
            logger.info(
                "Profile",
                user_id=user_id,
                name=f"{profile.first_name} {profile.last_name}",
                version=profile.version,
                email=profile.email
            )
    
    async def run_continuous(self):
        """Run in continuous mode"""
        self.running = True
        
        await self.run_demo()
        
        logger.info("💡 Demo completed. Running in continuous mode...")
        logger.info("📊 Web Dashboard: http://localhost:8080")
        logger.info("Press Ctrl+C to stop")
        
        # Keep running
        try:
            while self.running:
                await asyncio.sleep(1)
        except KeyboardInterrupt:
            logger.info("Received interrupt signal")
        finally:
            await self.cleanup()
    
    async def cleanup(self):
        """Cleanup resources"""
        logger.info("🛑 Shutting down application")
        
        self.running = False
        
        # Stop services
        self.consumer.stop()
        self.monitor.stop()
        self.producer.close()
        
        logger.info("✅ Cleanup completed")


async def main():
    """Main entry point"""
    demo = LogCompactionDemo()
    
    # Setup signal handlers
    def signal_handler(sig, frame):
        logger.info("Received signal, shutting down...")
        demo.running = False
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        await demo.run_continuous()
    except Exception as e:
        logger.error("Application error", error=str(e))
        await demo.cleanup()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
