#!/bin/bash

echo "🛑 Stopping Multi-Language SDK Environment"
echo "=========================================="

# Kill any running API servers
pkill -f "api-server/src/main.py" || true
pkill -f "uvicorn" || true

# Clean up Docker containers
docker-compose down 2>/dev/null || true

# Deactivate Python environments
deactivate 2>/dev/null || true

echo "✅ Environment stopped successfully"
