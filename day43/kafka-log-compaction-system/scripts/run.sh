#!/bin/bash

echo "🚀 Starting Kafka Log Compaction Demo..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose not found. Please install docker-compose first."
    exit 1
fi

# Start Kafka infrastructure
echo "📦 Starting Kafka infrastructure..."
docker-compose up -d zookeeper kafka

# Wait for Kafka to be ready
echo "⏳ Waiting for Kafka to be ready..."
until nc -z localhost 9092 2>/dev/null; do
    echo "   Waiting for Kafka on port 9092..."
    sleep 2
done

echo "✅ Kafka is ready!"

# Start the web dashboard
echo "🌐 Starting web dashboard..."
PYTHONPATH=. python3 -m uvicorn src.web.dashboard_app:create_app --host 0.0.0.0 --port 8080 &
DASHBOARD_PID=$!

# Wait for dashboard to start
echo "⏳ Waiting for dashboard to start..."
sleep 5

# Start the main demo application
echo "🐍 Starting main demo application..."
PYTHONPATH=. python3 src/main.py &
DEMO_PID=$!

echo "✅ All services started!"
echo "📊 Web Dashboard: http://localhost:8080"
echo "📊 API Endpoint: http://localhost:8080/api/metrics"
echo ""
echo "Press Ctrl+C to stop all services"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down services..."
    kill $DASHBOARD_PID 2>/dev/null
    kill $DEMO_PID 2>/dev/null
    docker-compose down
    echo "✅ Cleanup completed"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Keep the script running
wait

