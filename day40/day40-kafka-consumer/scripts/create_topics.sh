#!/bin/bash

# Create Kafka Topics Script
echo "📡 Creating Kafka topics..."

# Wait for Kafka to be ready
echo "⏳ Waiting for Kafka to be ready..."
until docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 > /dev/null 2>&1; do
    echo "Waiting for Kafka..."
    sleep 2
done

# Create topics
echo "Creating web-logs topic..."
docker exec kafka kafka-topics --create \
  --topic web-logs --partitions 3 --replication-factor 1 \
  --bootstrap-server localhost:9092 2>/dev/null || echo "Topic web-logs already exists"

echo "Creating app-logs topic..."
docker exec kafka kafka-topics --create \
  --topic app-logs --partitions 3 --replication-factor 1 \
  --bootstrap-server localhost:9092 2>/dev/null || echo "Topic app-logs already exists"

echo "Creating error-logs topic..."
docker exec kafka kafka-topics --create \
  --topic error-logs --partitions 2 --replication-factor 1 \
  --bootstrap-server localhost:9092 2>/dev/null || echo "Topic error-logs already exists"

echo "📋 Listing all topics:"
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

echo "✅ Topic creation complete!"
