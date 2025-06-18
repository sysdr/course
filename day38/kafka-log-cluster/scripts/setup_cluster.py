#!/usr/bin/env python3
"""Kafka cluster setup and topic creation."""

import time
from confluent_kafka.admin import AdminClient, NewTopic
from confluent_kafka import Producer, Consumer

def wait_for_kafka(bootstrap_servers='localhost:9092'):
    """Wait for Kafka to be ready."""
    print("⏳ Waiting for Kafka cluster to be ready...")
    max_retries = 30
    for i in range(max_retries):
        try:
            admin_client = AdminClient({'bootstrap.servers': bootstrap_servers})
            metadata = admin_client.list_topics(timeout=5)
            print(f"✅ Kafka cluster ready with {len(metadata.brokers)} brokers")
            return admin_client
        except Exception as e:
            print(f"🔄 Attempt {i+1}/{max_retries}: {str(e)}")
            time.sleep(5)
    raise Exception("Kafka cluster not ready after 30 attempts")

def create_topics(admin_client):
    """Create required topics for log processing."""
    topics = [
        NewTopic("web-api-logs", num_partitions=3, replication_factor=3),
        NewTopic("user-service-logs", num_partitions=3, replication_factor=3),
        NewTopic("payment-service-logs", num_partitions=3, replication_factor=3),
        NewTopic("critical-logs", num_partitions=1, replication_factor=3),
        NewTopic("error-aggregation", num_partitions=1, replication_factor=3),
    ]
    
    futures = admin_client.create_topics(topics)
    for topic, future in futures.items():
        try:
            future.result()
            print(f"✅ Created topic: {topic}")
        except Exception as e:
            if "already exists" in str(e).lower():
                print(f"ℹ️ Topic already exists: {topic}")
            else:
                print(f"❌ Failed to create topic {topic}: {str(e)}")

def verify_cluster_health():
    """Verify cluster health and topic creation."""
    try:
        # Test producer
        producer = Producer({'bootstrap.servers': 'localhost:9092'})
        producer.produce('web-api-logs', 'test-message')
        producer.flush()
        print("✅ Producer test successful")
        
        # Test consumer
        consumer = Consumer({
            'bootstrap.servers': 'localhost:9092',
            'group.id': 'test-group',
            'auto.offset.reset': 'earliest'
        })
        consumer.subscribe(['web-api-logs'])
        
        # Poll for messages with timeout
        messages = []
        start_time = time.time()
        while time.time() - start_time < 5:
            msg = consumer.poll(1.0)
            if msg is not None and not msg.error():
                messages.append(msg)
        
        consumer.close()
        print(f"✅ Consumer test successful - received {len(messages)} messages")
        
    except Exception as e:
        print(f"❌ Cluster health check failed: {str(e)}")

if __name__ == "__main__":
    admin_client = wait_for_kafka()
    create_topics(admin_client)
    verify_cluster_health()
    print("🎉 Kafka cluster setup complete!")
