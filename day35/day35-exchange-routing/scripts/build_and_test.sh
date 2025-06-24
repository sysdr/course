#!/bin/bash

echo "🔨 Building and Testing Exchange Routing System"
echo "=============================================="

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Tests failed!"
    exit 1
fi

# Start RabbitMQ with Docker if not running
echo "🐰 Starting RabbitMQ..."
docker run -d --name test-rabbitmq \
    -p 5672:5672 -p 15672:15672 \
    -e RABBITMQ_DEFAULT_USER=guest \
    -e RABBITMQ_DEFAULT_PASS=guest \
    rabbitmq:3.12-management

# Wait for RabbitMQ to be ready
echo "⏳ Waiting for RabbitMQ to be ready..."
sleep 10

# Run demonstration
echo "🎬 Running demonstration..."
python scripts/demo.py &
DEMO_PID=$!

# Start web dashboard
echo "🌐 Starting web dashboard..."
cd web && python dashboard.py &
WEB_PID=$!

echo "✅ System is running!"
echo "📊 Web Dashboard: http://localhost:5000"
echo "🐰 RabbitMQ Management: http://localhost:15672 (guest/guest)"
echo ""
echo "Press CTRL+C to stop all services..."

# Wait for interrupt
trap "echo '🛑 Stopping services...'; kill $DEMO_PID $WEB_PID 2>/dev/null; docker stop test-rabbitmq 2>/dev/null; docker rm test-rabbitmq 2>/dev/null; exit" INT

wait
