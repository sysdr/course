#!/bin/bash

echo "🧪 Running RabbitMQ Tests"

# Wait for RabbitMQ to be ready
echo "⏳ Waiting for RabbitMQ to be ready..."
timeout=60
elapsed=0

while ! curl -s -u guest:guest http://localhost:15672/api/overview > /dev/null 2>&1; do
    if [ $elapsed -ge $timeout ]; then
        echo "❌ RabbitMQ did not become ready within $timeout seconds"
        exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo -n "."
done

echo " ✅ RabbitMQ is ready!"

# Run setup
echo "🔧 Running RabbitMQ setup..."
python -m message_queue.rabbitmq_setup

# Run health check
echo "🏥 Running health check..."
python -m message_queue.health_checker

# Run queue manager demo
echo "📊 Running queue manager demo..."
python -m message_queue.queue_manager

# Run pytest
echo "🧪 Running integration tests..."
python -m pytest tests/ -v

echo "✅ All tests completed!"
