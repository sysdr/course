#!/bin/bash

echo "🚀 Starting Root Cause Analysis Engine"
echo "====================================="

# Activate virtual environment
source venv/bin/activate



# Set Python path
export PYTHONPATH="$(pwd)/backend/src:$PYTHONPATH"

# Start the application
cd backend

pip install -r requirements.txt

echo "📡 Starting FastAPI server..."
cd src
uvicorn main:app --host 0.0.0.0 --port 8000 &
SERVER_PID=$!

# Wait for server to start and verify it's running
echo "Waiting for server to start..."
for i in {1..30}; do
    if curl -s http://localhost:8000/api/health > /dev/null; then
        echo "Server is up!"
        break
    fi
    sleep 1
done

# Start metrics collector
echo "📊 Starting metrics collector..."
cd ../../scripts
python collect_system_metrics.py &
METRICS_PID=$!

# Run demonstration
echo "🎮 Running demonstration..."
python run_demo.py

echo "🌐 Dashboard available at: http://localhost:8000/dashboard"
echo "🔍 API available at: http://localhost:8000"
echo ""
echo "Server PID: $SERVER_PID"
echo "Metrics Collector PID: $METRICS_PID"
echo "To stop all services: ./stop.sh"
