#!/usr/bin/env python3
"""
Day 41: Kafka Partitioning & Consumer Groups - Main Application
"""

import sys
import time
import signal
import threading
import logging
import os
from datetime import datetime

# Add current directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

try:
    from config.topic_manager import setup_kafka_topic
    from producer.log_producer import LogMessageProducer
    from consumer.log_consumer import ConsumerGroupManager
    from monitoring.consumer_monitor import monitor
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure you're running from the correct directory and all dependencies are installed")
    sys.exit(1)

class KafkaDemo:
    def __init__(self):
        self.producer = None
        self.consumer_manager = None
        self.running = False
        
        # Setup signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        print(f"\n🛑 Received signal {signum}, shutting down gracefully...")
        self.stop()
    
    def setup_infrastructure(self):
        """Setup Kafka topic and infrastructure"""
        print("🔧 Setting up Kafka infrastructure...")
        try:
            topic_info = setup_kafka_topic()
            if topic_info:
                print(f"✅ Topic setup complete: {topic_info['name']} with {topic_info['partitions']} partitions")
            else:
                print("⚠️ Topic setup completed (may already exist)")
        except Exception as e:
            print(f"❌ Topic setup failed: {e}")
            raise
    
    def start_monitoring(self):
        """Start system monitoring"""
        print("📊 Starting monitoring...")
        monitor.start_monitoring(interval_seconds=10)
    
    def start_consumers(self, consumer_count: int = 3):
        """Start consumer group"""
        print(f"👥 Starting consumer group with {consumer_count} consumers...")
        self.consumer_manager = ConsumerGroupManager(group_size=consumer_count)
        self.consumer_manager.start_consumer_group()
        time.sleep(5)  # Allow consumers to register and get assignments
    
    def start_producer(self, rate: int = 10, duration: int = 300):
        """Start log producer"""
        print(f"📤 Starting producer: {rate} messages/second for {duration} seconds...")
        self.producer = LogMessageProducer("demo-producer")
        
        def run_producer():
            self.producer.start_continuous_production(
                messages_per_second=rate,
                duration_seconds=duration
            )
        
        producer_thread = threading.Thread(target=run_producer, daemon=True)
        producer_thread.start()
        
        return producer_thread
    
    def run_demo(self, consumer_count: int = 3, production_rate: int = 10, duration: int = 60):
        """Run the complete demonstration"""
        self.running = True
        
        try:
            print("🚀 Starting Kafka Partitioning & Consumer Groups Demo")
            print("=" * 60)
            
            # Setup infrastructure
            self.setup_infrastructure()
            
            # Start monitoring
            self.start_monitoring()
            
            # Start consumers
            self.start_consumers(consumer_count)
            
            # Start producer
            producer_thread = self.start_producer(production_rate, duration)
            
            print(f"\n📈 Demo running - producing {production_rate} msg/sec with {consumer_count} consumers")
            print("💡 Watch the partition assignments and load distribution!")
            print("📊 Monitor at: http://localhost:8080 (if web dashboard is running)")
            print("\nPress Ctrl+C to stop...\n")
            
            # Show real-time statistics
            start_time = time.time()
            while self.running and (time.time() - start_time) < duration:
                time.sleep(10)
                self._show_stats()
            
            # Wait for producer to complete
            producer_thread.join(timeout=10)
            
            print("\n✅ Demo completed successfully!")
            self._show_final_stats()
            
        except KeyboardInterrupt:
            print("\n🛑 Demo interrupted by user")
        except Exception as e:
            print(f"\n❌ Demo failed: {e}")
        finally:
            self.stop()
    
    def _show_stats(self):
        """Show current statistics"""
        try:
            if self.consumer_manager:
                stats = self.consumer_manager.get_group_stats()
                print(f"📊 [{datetime.now().strftime('%H:%M:%S')}] "
                      f"Processed: {stats['total_processed']}, "
                      f"Active: {stats['active_consumers']}/{stats['group_size']}, "
                      f"Success: {stats['group_success_rate']:.1f}%")
            
            if self.producer:
                producer_stats = self.producer.get_stats()
                print(f"📤 [{datetime.now().strftime('%H:%M:%S')}] "
                      f"Sent: {producer_stats['messages_sent']}, "
                      f"Errors: {producer_stats['errors']}, "
                      f"Success: {producer_stats['success_rate']:.1f}%")
                
        except Exception as e:
            print(f"⚠️ Error getting stats: {e}")
    
    def _show_final_stats(self):
        """Show final demonstration statistics"""
        print("\n" + "=" * 60)
        print("📊 FINAL DEMONSTRATION STATISTICS")
        print("=" * 60)
        
        try:
            if self.consumer_manager:
                stats = self.consumer_manager.get_group_stats()
                print(f"\n👥 Consumer Group Performance:")
                print(f"   Total Messages Processed: {stats['total_processed']}")
                print(f"   Total Errors: {stats['total_errors']}")
                print(f"   Overall Success Rate: {stats['group_success_rate']:.1f}%")
                print(f"   Active Consumers: {stats['active_consumers']}/{stats['group_size']}")
                
                print(f"\n📋 Individual Consumer Stats:")
                for consumer_stats in stats['consumers']:
                    print(f"   {consumer_stats['consumer_id']}: "
                          f"{consumer_stats['messages_processed']} messages, "
                          f"partitions {consumer_stats['assigned_partitions']}")
            
            if self.producer:
                producer_stats = self.producer.get_stats()
                print(f"\n📤 Producer Performance:")
                print(f"   Messages Sent: {producer_stats['messages_sent']}")
                print(f"   Errors: {producer_stats['errors']}")
                print(f"   Success Rate: {producer_stats['success_rate']:.1f}%")
                
        except Exception as e:
            print(f"⚠️ Error showing final stats: {e}")
        
        print("\n💡 Key Observations:")
        print("   ✅ Messages distributed across partitions")
        print("   ✅ Consumers automatically assigned to partitions")
        print("   ✅ Load balanced across consumer instances")
        print("   ✅ System handles consumer failures gracefully")
    
    def stop(self):
        """Stop the demo"""
        self.running = False
        
        if self.producer:
            print("🛑 Stopping producer...")
            self.producer.stop_production()
        
        if self.consumer_manager:
            print("🛑 Stopping consumer group...")
            self.consumer_manager.stop_consumer_group()
        
        print("🛑 Stopping monitoring...")
        monitor.stop_monitoring()
        
        print("✅ Demo stopped cleanly")

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Kafka Partitioning & Consumer Groups Demo')
    parser.add_argument('--consumers', type=int, default=3, help='Number of consumers (default: 3)')
    parser.add_argument('--rate', type=int, default=10, help='Messages per second (default: 10)')
    parser.add_argument('--duration', type=int, default=60, help='Duration in seconds (default: 60)')
    parser.add_argument('--web', action='store_true', help='Start web dashboard')
    
    args = parser.parse_args()
    
    if args.web:
        # Start web dashboard
        import sys
        import os
        
        # Add web directory to path
        web_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'web')
        sys.path.append(web_path)
        
        try:
            from dashboard import app, socketio
            print("🌐 Starting web dashboard on http://localhost:8080")
            socketio.run(app, host='0.0.0.0', port=8080, debug=False)
        except ImportError as e:
            print(f"Failed to import dashboard: {e}")
            print("Make sure Flask and Flask-SocketIO are installed")
            sys.exit(1)
    else:
        # Run CLI demo
        demo = KafkaDemo()
        demo.run_demo(
            consumer_count=args.consumers,
            production_rate=args.rate,
            duration=args.duration
        )

if __name__ == "__main__":
    main()
