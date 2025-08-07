#!/bin/bash

echo "🛑 Stopping LogPlatform CLI Environment"
echo "======================================="

# Stop mock API server
if [ -f .mock_api_pid ]; then
    MOCK_API_PID=$(cat .mock_api_pid)
    if ps -p $MOCK_API_PID > /dev/null 2>&1; then
        echo "🎭 Stopping mock API server (PID: $MOCK_API_PID)..."
        kill $MOCK_API_PID
    fi
    rm -f .mock_api_pid
fi

# Stop any running logplatform processes
pkill -f "logplatform" 2>/dev/null || true

# Deactivate virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
    echo "📦 Deactivating virtual environment..."
    deactivate 2>/dev/null || true
fi

echo "✅ Environment stopped successfully"
