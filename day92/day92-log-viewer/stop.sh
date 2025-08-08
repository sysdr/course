#!/bin/bash

echo "🛑 Stopping Day 92: Log Viewer Web UI"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check if running with Docker
if docker-compose ps | grep -q "Up"; then
    echo "Stopping Docker services..."
    docker-compose down
    echo -e "${GREEN}[SUCCESS]${NC} Docker services stopped"
else
    echo "Stopping local services..."
    
    # Kill processes from PID files
    if [ -f "backend/backend.pid" ]; then
        kill $(cat backend/backend.pid) 2>/dev/null || true
        rm backend/backend.pid
    fi
    
    if [ -f "frontend/frontend.pid" ]; then
        kill $(cat frontend/frontend.pid) 2>/dev/null || true
        rm frontend/frontend.pid
    fi
    
    # Kill any remaining processes on our ports
    lsof -ti:5000 | xargs kill -9 2>/dev/null || true
    lsof -ti:3000 | xargs kill -9 2>/dev/null || true
    
    echo -e "${GREEN}[SUCCESS]${NC} Local services stopped"
fi

echo "All services stopped."
