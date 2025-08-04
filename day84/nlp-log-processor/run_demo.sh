#!/bin/bash

source venv/bin/activate

echo "🎮 Running NLP Log Processing Demo"
echo "=================================="

# Check if server is running
if ! curl -s http://localhost:5000/api/health > /dev/null 2>&1; then
    echo "🚀 Starting server..."
    python src/api/server.py &
    SERVER_PID=$!
    sleep 5
    echo "✅ Server started"
else
    echo "✅ Server already running"
    SERVER_PID=""
fi

# Run demo
python scripts/demo.py

# Cleanup if we started the server
if [ ! -z "$SERVER_PID" ]; then
    echo "🛑 Stopping server..."
    kill $SERVER_PID
    wait $SERVER_PID 2>/dev/null || true
fi

echo "🎉 Demo completed!"
