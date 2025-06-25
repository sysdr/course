#!/bin/bash

echo "🔧 Building Windowed Analytics System..."

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt
pip install aiohttp websockets

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v

# Run WebSocket and system tests
echo "🧪 Running WebSocket test..."
python3 test_websocket.py || { echo "❌ WebSocket test failed"; exit 1; }

echo "🧪 Running comprehensive system test..."
python3 test_system.py || { echo "❌ System test failed"; exit 1; }

# Start Redis
echo "🚀 Starting Redis server..."
if command -v redis-server &> /dev/null; then
    redis-server --daemonize yes
    sleep 2
else
    echo "⚠️  Redis not found, using Docker..."
    docker run -d --name redis-windowing -p 6379:6379 redis:7.2-alpine
    sleep 5
fi

# Test Redis connection
python -c "
import redis
r = redis.Redis(host='localhost', port=6379)
r.ping()
print('✅ Redis connection successful')
"

echo "✅ Build and test completed successfully!"
echo "🌐 To start the system:"
echo "   python3 src/main.py"
echo "   Then visit: http://localhost:8000 (main dashboard)"
echo "   Or visit:  http://localhost:8000/test (test dashboard)"
