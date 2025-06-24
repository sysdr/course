#!/bin/bash
set -e

echo "🚀 Starting Log Producer locally..."

# Set PYTHONPATH
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Check if RabbitMQ is running
if ! nc -z localhost 5672; then
    echo "❌ RabbitMQ is not running on localhost:5672"
    echo "Please start RabbitMQ first:"
    echo "  docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3.12-management"
    exit 1
fi

echo "✅ RabbitMQ is running"

# Start the producer
echo "Starting producer service..."
cd src && python -m producer.producer
