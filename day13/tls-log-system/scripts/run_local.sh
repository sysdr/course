#!/bin/bash

# Local run script for development
set -e

echo "🚀 Starting TLS Log System locally..."

# Start server in background
echo "🔧 Starting TLS server..."
python src/tls_log_server.py &
SERVER_PID=$!

# Start dashboard in background
echo "🖥️  Starting web dashboard..."
python src/web_dashboard.py &
DASHBOARD_PID=$!

# Wait a moment for services to start
sleep 3

echo "✅ Services started!"
echo "🔐 TLS Server: https://localhost:8443"
echo "🖥️  Dashboard: http://localhost:8080"
echo ""
echo "Press Ctrl+C to stop all services..."

# Function to cleanup on exit
cleanup() {
    echo "🛑 Stopping services..."
    kill $SERVER_PID $DASHBOARD_PID 2>/dev/null || true
    echo "✅ Services stopped"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Wait for interrupt
wait
