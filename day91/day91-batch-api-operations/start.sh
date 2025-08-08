#!/bin/bash
echo "🔧 Starting Day 91 Batch API Operations System..."

# Create and activate virtual environment
if [ ! -d "venv" ]; then
    echo "Creating Python 3.11 virtual environment..."
    python3.11 -m venv venv
fi

source venv/bin/activate

# Install dependencies
echo "📦 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Run database setup
echo "🗄️ Setting up database..."
python src/utils/database_setup.py

# Start Redis if not running
echo "🔴 Starting Redis..."
redis-server --daemonize yes --port 6379 || echo "Redis already running"

# Start the API server
echo "🚀 Starting Batch API server..."
uvicorn src.api.main:app --host 0.0.0.0 --port 8000 --reload &
API_PID=$!

echo "API_PID=$API_PID" > .pids

# Start monitoring dashboard
echo "📊 Starting monitoring dashboard..."
python src/monitoring/dashboard.py &
MONITOR_PID=$!

echo "MONITOR_PID=$MONITOR_PID" >> .pids

echo "✅ System started successfully!"
echo "📡 API Server: http://localhost:8000"
echo "📊 Monitoring Dashboard: http://localhost:8001"
echo "📚 API Documentation: http://localhost:8000/docs"

# Wait for services to be ready
sleep 5

# Run demonstration
echo "🎬 Running demonstration..."
python src/utils/demo.py

echo "Press Ctrl+C to stop all services"
wait
