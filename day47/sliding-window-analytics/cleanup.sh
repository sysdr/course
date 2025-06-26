#!/bin/bash

# Cleanup script for Sliding Window Analytics
# This script stops all containers and cleans up Docker resources

set -e  # Exit on any error

echo "🧹 Starting Sliding Window Analytics Cleanup"
echo "============================================="

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose is not installed. Please install docker-compose and try again."
    exit 1
fi

# Stop and remove containers
echo "🛑 Stopping and removing containers..."
docker-compose down --remove-orphans 2>/dev/null || true

# Remove volumes (this will delete Redis data)
echo "🗑️  Removing volumes..."
docker-compose down --volumes --remove-orphans 2>/dev/null || true

# Remove images
echo "🖼️  Removing Docker images..."
docker-compose down --rmi all --volumes --remove-orphans 2>/dev/null || true

# Clean up any dangling images, containers, and networks
echo "🧽 Cleaning up dangling Docker resources..."
docker system prune -f 2>/dev/null || true

# Remove any remaining containers with the project name
echo "🔍 Removing any remaining project containers..."
docker ps -a --filter "name=sliding-window-analytics" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true

# Remove any remaining images with the project name
echo "🖼️  Removing any remaining project images..."
docker images --filter "reference=sliding-window-analytics*" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true

# Remove any remaining volumes with the project name
echo "💾 Removing any remaining project volumes..."
docker volume ls --filter "name=sliding-window-analytics" --format "{{.Name}}" | xargs -r docker volume rm 2>/dev/null || true

# Remove any remaining networks with the project name
echo "🌐 Removing any remaining project networks..."
docker network ls --filter "name=sliding-window-analytics" --format "{{.ID}}" | xargs -r docker network rm 2>/dev/null || true

echo ""
echo "✅ Cleanup completed successfully!"
echo "============================================="
echo "🎯 All Sliding Window Analytics containers, images, volumes, and networks have been removed."
echo ""
echo "📝 To start fresh: ./demo.sh" 