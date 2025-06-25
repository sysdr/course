#!/bin/bash

set -e

echo "🧹 Cleaning up Windowed Analytics System environment..."

# Stop and remove docker-compose containers and networks
echo "🛑 Stopping and removing Docker Compose containers..."
docker-compose down || true

echo "🗑️ Removing all stopped Docker containers..."
docker container prune -f || true

echo "🗑️ Removing all unused Docker images..."
docker image prune -af || true

echo "🗑️ Removing all unused Docker networks..."
docker network prune -f || true

# Kill any running python3 src/main.py or uvicorn processes
echo "🔪 Killing any running python3 src/main.py or uvicorn processes..."
pkill -f "python3 src/main.py" || true
pkill -f "uvicorn" || true

# Remove Python cache directories
echo "🗑️ Removing Python cache directories..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true

# Optional: Remove Redis data if using a data directory
# echo "🗑️ Removing Redis data..."
# rm -rf data/redis/* 2>/dev/null || true

echo "✅ Cleanup complete!" 