#!/bin/bash

echo "🚀 Starting Docker deployment..."

# Start all services
docker-compose up -d

# Wait for Kafka to be ready
echo "⏳ Waiting for Kafka to be ready..."
until docker-compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; do
    echo "   Waiting for Kafka..."
    sleep 5
done

echo "✅ Kafka is ready!"

# Wait for the web dashboard to be ready
echo "⏳ Waiting for web dashboard..."
until curl -s http://localhost:8080/api/metrics > /dev/null 2>&1; do
    echo "   Waiting for web dashboard..."
    sleep 3
done

echo "✅ Web dashboard is ready!"

# Start the main demo application in the background
echo "🐍 Starting main demo application..."
docker exec -d kafka-log-compaction-system-compaction-app-1 python -m src.main

echo "✅ All services started successfully!"
