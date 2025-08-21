#!/bin/bash

echo "🛑 Stopping Dashboard System..."

# Kill any running Python processes for our app
pkill -f "app.main"
pkill -f "http.server"

# Kill processes on specific ports
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
lsof -ti:3000 | xargs kill -9 2>/dev/null || true

echo "✅ All services stopped"
