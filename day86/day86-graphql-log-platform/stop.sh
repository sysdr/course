#!/bin/bash
set -e

echo "🛑 Stopping GraphQL Log Platform..."
echo "=================================="

# Function to kill process by PID file
kill_by_pid_file() {
    local pid_file=$1
    local service_name=$2
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p $pid > /dev/null 2>&1; then
            echo "🔄 Stopping $service_name (PID: $pid)..."
            kill -TERM $pid 2>/dev/null || true
            sleep 2
            if ps -p $pid > /dev/null 2>&1; then
                echo "🔨 Force killing $service_name..."
                kill -KILL $pid 2>/dev/null || true
            fi
        fi
        rm -f "$pid_file"
    fi
}

# Kill processes by PID files
kill_by_pid_file ".backend.pid" "Backend"
kill_by_pid_file ".frontend.pid" "Frontend"

# Kill any remaining processes by name
echo "🔄 Stopping any remaining processes..."

# Backend processes
pkill -f "python -m uvicorn" 2>/dev/null || true
pkill -f "app.main:app" 2>/dev/null || true
pkill -f "uvicorn" 2>/dev/null || true

# Frontend processes
pkill -f "react-scripts" 2>/dev/null || true
pkill -f "npm start" 2>/dev/null || true

# Node.js processes on port 3000
lsof -ti:3000 2>/dev/null | xargs kill -9 2>/dev/null || true

# Python processes on port 8000
lsof -ti:8000 2>/dev/null | xargs kill -9 2>/dev/null || true

# Wait a moment for processes to fully stop
sleep 2

# Clean up temporary files and cache
echo "🧹 Cleaning up temporary files and cache..."

# Remove PID files
rm -f .backend.pid .frontend.pid

# Clean up Python cache
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.pyo" -delete 2>/dev/null || true

# Clean up Node.js cache
rm -rf frontend/node_modules/.cache 2>/dev/null || true
rm -rf frontend/.next 2>/dev/null || true
rm -rf frontend/.nuxt 2>/dev/null || true

# Clean up log files (optional - uncomment if you want to remove logs)
# rm -rf logs/*.log 2>/dev/null || true

# Clean up temporary files
rm -rf .tmp 2>/dev/null || true
rm -rf tmp 2>/dev/null || true

# Clean up any remaining temporary files
find . -name "*.tmp" -delete 2>/dev/null || true
find . -name "*.temp" -delete 2>/dev/null || true

# Verify ports are free
echo "🔍 Verifying ports are free..."
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Port 8000 is still in use"
else
    echo "✅ Port 8000 is free"
fi

if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Port 3000 is still in use"
else
    echo "✅ Port 3000 is free"
fi

echo ""
echo "✅ GraphQL Log Platform stopped successfully!"
echo "🧹 Cleanup completed"
