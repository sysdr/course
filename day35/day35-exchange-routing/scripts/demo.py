#!/usr/bin/env python3
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import time
import threading
from src.exchange_manager import ExchangeManager
from src.log_producer import LogProducer
from src.log_consumer import LogConsumer
from config.config import Config

def setup_infrastructure():
    """Setup exchanges and queues"""
    print("🔧 Setting up infrastructure...")
    manager = ExchangeManager()
    if manager.connect():
        if manager.setup_exchanges_and_queues():
            print("✅ Infrastructure setup complete")
            manager.close()
            return True
    return False

def start_consumers():
    """Start consumer threads for demo"""
    consumers = []
    
    # Database logs consumer
    db_consumer = LogConsumer(Config.QUEUES['database_logs'], 'DATABASE-PROCESSOR')
    db_thread = threading.Thread(target=run_consumer, args=(db_consumer,))
    db_thread.daemon = True
    consumers.append((db_consumer, db_thread))
    
    # Security logs consumer
    sec_consumer = LogConsumer(Config.QUEUES['security_logs'], 'SECURITY-ANALYZER')
    sec_thread = threading.Thread(target=run_consumer, args=(sec_consumer,))
    sec_thread.daemon = True
    consumers.append((sec_consumer, sec_thread))
    
    # Start all consumers
    for consumer, thread in consumers:
        thread.start()
        
    return consumers

def run_consumer(consumer):
    """Run individual consumer"""
    try:
        consumer.connect()
        consumer.start_consuming()
    except Exception as e:
        print(f"Consumer error: {e}")
    finally:
        consumer.close()

def main():
    print("🚀 Starting Exchange Routing Demo")
    print("=" * 50)
    
    # Setup infrastructure
    if not setup_infrastructure():
        print("❌ Failed to setup infrastructure")
        return
        
    # Start consumers
    print("\n🔍 Starting consumers...")
    consumers = start_consumers()
    time.sleep(2)  # Let consumers start
    
    # Start producer
    print("\n📤 Starting log producer...")
    producer = LogProducer()
    producer.connect()
    
    try:
        print("\n🎯 Generating sample logs...")
        producer.generate_sample_logs(20)
        
        print("\n✅ Demo complete! Check the output above to see routing in action.")
        print("💡 Visit http://localhost:5000 for the web dashboard")
        print("\nPress CTRL+C to stop...")
        
        # Keep running
        while True:
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\n🛑 Stopping demo...")
    finally:
        producer.close()
        for consumer, thread in consumers:
            consumer.close()

if __name__ == "__main__":
    main()
