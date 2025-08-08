#!/bin/bash
echo "🛑 Stopping Day 91 Batch API Operations System..."

if [ -f .pids ]; then
    source .pids
    
    if [ ! -z "$API_PID" ]; then
        kill $API_PID 2>/dev/null || true
    fi
    
    if [ ! -z "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null || true
    fi
    
    rm .pids
fi

# Stop any remaining processes
pkill -f "uvicorn src.api.main" 2>/dev/null || true
pkill -f "python src/monitoring/dashboard.py" 2>/dev/null || true

echo "✅ All services stopped"
