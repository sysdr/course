#!/bin/bash

echo "🚀 Day 95: Starting Customizable Dashboard System"
echo "=================================================="

# Check if virtual environment exists, create if not
if [ ! -d "venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3.11 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend && pip install -r requirements.txt && cd ..

# Start backend
echo "🔧 Starting backend server..."
cd backend
python app/main.py &
BACKEND_PID=$!
cd ..

# Wait for backend to start
sleep 3

# Start frontend (simple HTTP server)
echo "🎨 Starting frontend server..."
cd frontend/public
python3 -m http.server 3000 &
FRONTEND_PID=$!
cd ../..

echo "✅ Dashboard system started!"
echo "Frontend: http://localhost:3000"
echo "Backend API: http://localhost:8000"
echo "Press Ctrl+C to stop"

# Wait for user to stop
trap "echo '🛑 Stopping services...'; kill $BACKEND_PID $FRONTEND_PID; exit" INT
wait
