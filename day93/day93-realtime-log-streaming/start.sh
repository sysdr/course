#!/bin/bash

set -e

echo "🚀 Day 93: Starting Real-time Log Streaming System"
echo "================================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Please run setup.sh first."
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend
pip install -r requirements.txt
cd ..

# Install frontend dependencies
echo "📦 Installing frontend dependencies..."
cd frontend
npm install
cd ..

# Start backend in background
echo "🖥️  Starting backend server..."
cd backend
PYTHONPATH=src python src/main.py &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo "⏳ Waiting for backend to initialize..."
sleep 10

# Start frontend in background  
echo "🌐 Starting frontend development server..."
cd frontend
npm start &
FRONTEND_PID=$!
cd ..

# Store PIDs for shutdown script
echo $BACKEND_PID > .backend.pid
echo $FRONTEND_PID > .frontend.pid

echo ""
echo "✅ System started successfully!"
echo "📊 Frontend Dashboard: http://localhost:3000"
echo "🔌 Backend API: http://localhost:8000"
echo "📖 API Docs: http://localhost:8000/docs"
echo ""
echo "To stop the system, run: ./stop.sh"

# Wait for user input
echo "Press Ctrl+C to stop all services..."
trap 'echo "Stopping services..."; ./stop.sh; exit' INT
wait
