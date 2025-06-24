#!/usr/bin/env python3
"""Comprehensive Kafka cluster tests."""

import pytest
import json
import time
from confluent_kafka import Producer, Consumer
from confluent_kafka.admin import AdminClient

class TestKafkaCluster:
    
    @pytest.fixture
    def producer(self):
        return Producer({'bootstrap.servers': 'localhost:9092'})
    
    @pytest.fixture
    def admin_client(self):
        return AdminClient({'bootstrap.servers': 'localhost:9092'})
    
    def test_cluster_connectivity(self, admin_client):
        """Test basic cluster connectivity."""
        metadata = admin_client.list_topics(timeout=10)
        assert len(metadata.brokers) >= 3, "Should have at least 3 brokers"
    
    def test_topic_creation(self, admin_client):
        """Test that required topics exist."""
        topics = admin_client.list_topics(timeout=10)
        required_topics = ['web-api-logs', 'user-service-logs', 'payment-service-logs', 'critical-logs']
        
        for topic in required_topics:
            assert topic in topics.topics, f"Topic {topic} should exist"
    
    def test_message_production_consumption(self, producer):
        """Test end-to-end message flow."""
        test_message = {'test': 'message', 'timestamp': time.time()}
        
        # Send message
        producer.produce('web-api-logs', json.dumps(test_message))
        producer.flush()
        
        # Consume message
        consumer = Consumer({
            'bootstrap.servers': 'localhost:9092',
            'group.id': 'test-group-' + str(int(time.time())),
            'auto.offset.reset': 'latest'
        })
        consumer.subscribe(['web-api-logs'])
        
        # Send another message to ensure consumer picks it up
        producer.produce('web-api-logs', json.dumps(test_message))
        producer.flush()
        
        messages = []
        start_time = time.time()
        while time.time() - start_time < 5:
            msg = consumer.poll(1.0)
            if msg is not None and not msg.error():
                messages.append(msg)
                break
        
        consumer.close()
        assert len(messages) > 0, "Should receive at least one message"
    
    def test_high_throughput(self, producer):
        """Test high-throughput message processing."""
        start_time = time.time()
        message_count = 1000
        
        for i in range(message_count):
            producer.produce('web-api-logs', json.dumps({'id': i, 'data': f'test-{i}'}))
        
        producer.flush()
        end_time = time.time()
        
        throughput = message_count / (end_time - start_time)
        print(f"Throughput: {throughput:.2f} messages/second")
        assert throughput > 100, "Should handle at least 100 messages/second"
    
    def test_partition_distribution(self, producer):
        """Test message distribution across partitions."""
        for i in range(10):
            producer.produce('web-api-logs', 
                           json.dumps({'partition_test': i}), 
                           key=str(i))
        producer.flush()
        
        assert True  # Placeholder - in real tests you'd check partition assignment

if __name__ == "__main__":
    pytest.main([__file__, "-v"])