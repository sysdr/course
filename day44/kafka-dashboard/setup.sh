#!/bin/bash

echo "Setting up Kafka Dashboard environment..."

# Install Python dependencies
pip install -r requirements.txt

# Create Kafka topics
echo "Creating Kafka topics..."
docker exec kafka kafka-topics --create --topic log-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec kafka kafka-topics --create --topic error-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec kafka kafka-topics --create --topic user-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1

echo "Setup complete!"
