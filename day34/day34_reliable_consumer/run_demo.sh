#!/bin/bash

echo "🎬 Running Reliable Consumer Demo"
echo "==============================="

# Start services
echo "🐳 Starting services with Docker Compose..."
docker-compose up -d

echo "⏳ Waiting for services to be ready..."
sleep 15

# Check service health
echo "🏥 Checking service health..."
docker-compose ps

# Send test messages
echo "📬 Sending test messages..."
python src/message_producer.py &
PRODUCER_PID=$!

# Start consumer
echo "🛡️ Starting reliable consumer..."
python src/main.py &
CONSUMER_PID=$!

# Start web dashboard
echo "🌐 Starting web dashboard..."
python web/app.py &
WEB_PID=$!

echo ""
echo "🎉 Demo is running!"
echo ""
echo "📊 Access the dashboard: http://localhost:8000"
echo "🐰 RabbitMQ management: http://localhost:15672 (guest/guest)"
echo ""
echo "⏹️  Press Ctrl+C to stop the demo"

# Wait for interrupt
trap 'echo "🛑 Stopping demo..."; kill $PRODUCER_PID $CONSUMER_PID $WEB_PID 2>/dev/null; docker-compose down; exit 0' INT

# Keep running
wait
