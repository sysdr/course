#!/bin/bash

set -e

echo "🔧 Day 93: Build and Test Real-time Log Streaming System"
echo "======================================================="

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating Python 3.11 virtual environment..."
    python3.11 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend
pip install -r requirements.txt
cd ..

echo "🧪 Running backend unit tests..."
cd backend
PYTHONPATH=src python -m pytest tests/ -v --tb=short
cd ..

# Install frontend dependencies  
echo "📦 Installing frontend dependencies..."
cd frontend
npm install --silent
cd ..

echo "🧪 Running frontend tests..."
cd frontend
npm test -- --coverage --watchAll=false
cd ..

echo "🎯 Running system demonstration..."

# Start services for demo
echo "🖥️  Starting backend for demo..."
cd backend  
PYTHONPATH=src python src/main.py &
BACKEND_PID=$!
cd ..

# Wait for backend
sleep 8

# Test API endpoints
echo "🔍 Testing API endpoints..."
curl -f http://localhost:8000/ > /dev/null
curl -f http://localhost:8000/api/streams > /dev/null

echo "🧪 Testing WebSocket connection..."
timeout 10 python3 -c "
import asyncio
import websockets
import json

async def test_websocket():
    uri = 'ws://localhost:8000/ws/logs/application'
    async with websockets.connect(uri) as websocket:
        for i in range(3):
            message = await websocket.recv()
            log_data = json.loads(message)
            print(f'✅ Received log: {log_data[\"id\"]} - {log_data[\"message\"][:50]}...')
            
asyncio.run(test_websocket())
"

# Cleanup
echo "🧹 Cleaning up demo processes..."
kill $BACKEND_PID 2>/dev/null || true
sleep 2

echo ""
echo "🎉 All tests passed successfully!"
echo "📊 Frontend Dashboard: http://localhost:3000 (run ./start.sh)"
echo "🔌 Backend API: http://localhost:8000"
echo ""
echo "✅ Day 93 implementation completed!"
