#!/bin/bash

echo "🛑 Stopping Root Cause Analysis Engine"

# Kill FastAPI server
pkill -f "python src/main.py" 2>/dev/null || true
pkill -f "uvicorn" 2>/dev/null || true

# Kill any demo processes
pkill -f "run_demo.py" 2>/dev/null || true

# Kill metrics collector
pkill -f "collect_system_metrics.py" 2>/dev/null || true

echo "✅ All processes stopped"
