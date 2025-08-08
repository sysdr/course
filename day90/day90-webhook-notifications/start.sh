#!/bin/bash

echo "🚀 Starting Day 90: Webhook Notifications System"
echo "================================================"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3.11 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install/update dependencies
echo "📦 Installing dependencies..."
pip install --quiet -r requirements.txt

# Build frontend
echo "🎨 Building frontend..."
cd frontend
if [ ! -d "node_modules" ]; then
    echo "📦 Installing npm dependencies..."
    npm install --silent
fi

echo "🏗️ Building React application..."
npm run build --silent
cd ..

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v

# Check if tests passed
if [ $? -eq 0 ]; then
    echo "✅ Tests passed"
else
    echo "❌ Tests failed. Please fix the issues before starting the service."
    exit 1
fi

# Start the service
echo "🚀 Starting webhook notifications service..."
echo ""
echo "Dashboard: http://localhost:8000"
echo "API Docs: http://localhost:8000/docs"
echo ""

# Check if port 8000 is already in use
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Port 8000 is already in use. Stopping existing service..."
    ./stop.sh
    sleep 2
fi

python -m src.main
