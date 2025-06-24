#!/bin/bash

set -e

echo "🎯 Kafka Log Compaction Complete Demo"
echo "===================================="

PROJECT_DIR=$(pwd)

# Check if we're in the right directory
if [ ! -f "config.yaml" ]; then
    echo "❌ Please run this script from the project root directory"
    exit 1
fi

# Build the application first
echo "🔨 Building application..."
./scripts/build.sh

# Start infrastructure
echo "🐳 Starting Kafka infrastructure..."
docker-compose up -d

echo "⏳ Waiting for Kafka to be ready..."
timeout=60
while ! nc -z localhost 9092; do
    sleep 2
    timeout=$((timeout - 2))
    if [ $timeout -le 0 ]; then
        echo "❌ Timeout waiting for Kafka"
        exit 1
    fi
done

echo "✅ Kafka is ready!"

# Run tests to ensure everything works
echo "🧪 Running tests..."
./scripts/test.sh

# Start web dashboard in background
echo "🌐 Starting web dashboard..."
./scripts/run_web.sh &
WEB_PID=$!

# Wait for web dashboard
sleep 5

# Run the main application
echo "🚀 Starting main application..."
./scripts/run_main.sh &
APP_PID=$!

echo ""
echo "🎉 Demo is running!"
echo "📊 Web Dashboard: http://localhost:8080"
echo "📝 Application logs will show profile state changes"
echo ""
echo "Press Ctrl+C to stop the demo"

# Wait for interrupt
trap "echo '🛑 Stopping demo...'; kill $WEB_PID $APP_PID 2>/dev/null; ./scripts/cleanup.sh; exit 0" INT

wait
