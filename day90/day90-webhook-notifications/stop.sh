#!/bin/bash

echo "🛑 Stopping webhook notifications service..."

# Kill Python processes
pkill -f "python -m src.main"

# Stop Docker if running
docker-compose down 2>/dev/null || true

echo "✅ Service stopped"
