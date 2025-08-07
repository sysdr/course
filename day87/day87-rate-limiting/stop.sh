#!/bin/bash

echo "🛑 Stopping Day 87 services..."

# Stop Docker services
docker-compose down

# Stop local processes
pkill -f "uvicorn.*main:app" || true
pkill -f "npm start" || true
pkill -f "redis-server" || true

# Deactivate virtual environment
deactivate || true

echo "✅ All services stopped"
