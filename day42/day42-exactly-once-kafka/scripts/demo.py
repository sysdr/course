"""Demonstration script for exactly-once processing"""

import subprocess
import time
import signal
import sys
import os
from multiprocessing import Process

def start_infrastructure():
    """Start Kafka and database infrastructure"""
    print("🚀 Starting infrastructure...")
    
    # Start Docker Compose
    subprocess.run(['docker-compose', 'up', '-d'], check=True)
    
    # Wait for services to be ready
    print("⏳ Waiting for services to start...")
    time.sleep(30)
    
    # Create Kafka topics
    topics = [
        'banking-transfers',
        'account-balance-updates',
        'transaction-notifications'
    ]
    
    for topic in topics:
        subprocess.run([
            'docker', 'exec', '-t', 'day42-exactly-once-kafka-kafka-1',
            'kafka-topics', '--bootstrap-server', 'localhost:9092',
            '--create', '--topic', topic,
            '--partitions', '3',
            '--replication-factor', '1'
        ], capture_output=True)
        print(f"✅ Created topic: {topic}")

def run_component(component):
    """Run a specific component"""
    env = os.environ.copy()
    env['PYTHONPATH'] = os.getcwd()
    
    subprocess.run([
        sys.executable, '-m', 'src.main', component
    ], env=env)

def main():
    try:
        # Start infrastructure
        start_infrastructure()
        
        print("\n🎯 Starting exactly-once processing demonstration...")
        print("=" * 60)
        
        # Start consumer in background
        print("🔄 Starting consumer...")
        consumer_process = Process(target=run_component, args=('consumer',))
        consumer_process.start()
        
        time.sleep(5)
        
        # Start web dashboard in background
        print("🌐 Starting web dashboard...")
        web_process = Process(target=run_component, args=('web',))
        web_process.start()
        
        time.sleep(5)
        
        print("\n📊 Dashboard available at: http://localhost:5000")
        print("📈 Monitor exactly-once processing in real-time")
        print("\n🏦 Starting transaction producer...")
        print("💰 Watch transactions flow through the system")
        print("\n⚠️  Try stopping and restarting the consumer to see exactly-once guarantees in action")
        print("\n🛑 Press Ctrl+C to stop the demonstration")
        
        # Start producer (blocking)
        run_component('producer')
        
    except KeyboardInterrupt:
        print("\n🛑 Stopping demonstration...")
        
        if 'consumer_process' in locals():
            consumer_process.terminate()
            consumer_process.join()
        
        if 'web_process' in locals():
            web_process.terminate()
            web_process.join()
        
        print("✅ Demonstration stopped")
    
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
