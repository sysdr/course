#!/bin/bash

set -e

echo "🚀 Starting Multi-Language SDK Development Environment"
echo "====================================================="

# Create Python virtual environment
echo "🐍 Setting up Python environment..."
cd python-sdk
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -e .
pip install pytest pytest-asyncio
cd ..

# Install Java dependencies
echo "☕ Setting up Java environment..."
cd java-sdk
if command -v mvn &> /dev/null; then
    mvn clean compile
    echo "✅ Java SDK compiled successfully"
else
    echo "⚠️ Maven not found, skipping Java build"
fi
cd ..

# Install JavaScript dependencies
echo "🟨 Setting up JavaScript environment..."
cd javascript-sdk
if command -v npm &> /dev/null; then
    npm install
    npm run build
    echo "✅ JavaScript SDK built successfully"
else
    echo "⚠️ npm not found, skipping JavaScript build"
fi
cd ..

# Start API server
echo "🌐 Starting API server..."
python3.11 -m venv api-env
source api-env/bin/activate
pip install --upgrade pip
pip install -r api-server/requirements.txt

# Start API server in background
echo "🚀 Starting API server in background..."
python api-server/src/main.py &
API_SERVER_PID=$!

# Wait for API server to start
echo "⏳ Waiting for API server to start..."
sleep 3

# Check if API server is running
if curl -s http://localhost:8000/api/v1/health > /dev/null; then
    echo "✅ API server started successfully"
else
    echo "❌ Failed to start API server"
    exit 1
fi

echo "🎯 Environment setup completed!"
echo ""
echo "🌐 API server is running at: http://localhost:8000"
echo "📊 Dashboard available at: http://localhost:8000"
echo ""
echo "🎬 Starting Multi-Language SDK Demo..."
echo "======================================"

# Run the demo
./run_demo.sh

echo ""
echo "🎉 Demo completed!"
echo ""
echo "📋 Available commands:"
echo "• View dashboard: open http://localhost:8000"
echo "• Stop API server: kill $API_SERVER_PID"
echo "• Run demo again: ./run_demo.sh"
echo "• Stop everything: ./stop.sh"
