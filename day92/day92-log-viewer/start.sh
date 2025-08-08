#!/bin/bash

echo "🚀 Starting Day 92: Log Viewer Web UI"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check if we should use Docker
if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    echo -e "${BLUE}[INFO]${NC} Starting with Docker..."
    
    # Build and start services
    docker-compose up --build -d
    
    # Wait for services to be healthy
    echo "Waiting for services to start..."
    sleep 10
    
    # Check backend health
    for i in {1..30}; do
        if curl -s http://localhost:5000/api/health > /dev/null; then
            echo -e "${GREEN}[SUCCESS]${NC} Backend is healthy"
            break
        fi
        echo "Waiting for backend... ($i/30)"
        sleep 2
    done
    
    # Check frontend
    if curl -s http://localhost:3000 > /dev/null; then
        echo -e "${GREEN}[SUCCESS]${NC} Frontend is running"
    fi
    
else
    echo -e "${BLUE}[INFO]${NC} Starting without Docker..."
    
    # Start backend
    cd backend
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        python3.11 -m venv venv || python3 -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Install requirements
    pip install -r requirements.txt
    
    # Start backend in background
    python app.py &
    BACKEND_PID=$!
    echo $BACKEND_PID > backend.pid
    
    cd ../frontend
    
    # Install frontend dependencies if needed
    if [ ! -d "node_modules" ]; then
        npm install
    fi
    
    # Start frontend in background
    npm start &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > frontend.pid
    
    cd ..
    
    echo "Backend PID: $BACKEND_PID" > pids.txt
    echo "Frontend PID: $FRONTEND_PID" >> pids.txt
fi

echo ""
echo "🎉 Log Viewer UI is starting up!"
echo ""
echo "📊 Dashboard: http://localhost:3000"
echo "📋 Log Viewer: http://localhost:3000/logs"
echo "🔧 Backend API: http://localhost:5000/api"
echo ""
echo "Use ./stop.sh to stop all services"
