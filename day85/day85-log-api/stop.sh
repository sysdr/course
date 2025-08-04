#!/bin/bash

echo "🛑 Stopping Day 85 Log Platform API..."

if [ -f api.pid ]; then
    PID=$(cat api.pid)
    if ps -p $PID > /dev/null; then
        kill $PID
        echo "✅ API server stopped (PID: $PID)"
    else
        echo "⚠️ API server was not running"
    fi
    rm api.pid
else
    echo "⚠️ No PID file found"
fi

# Stop any remaining processes
pkill -f "uvicorn src.api.main:app"

echo "🧹 Cleanup completed"
