#!/bin/bash

echo "🧹 Cleaning up Docker deployment..."

# Stop all containers
docker-compose down --remove-orphans

# Remove any dangling containers
docker ps -a --filter "name=kafka-log-compaction" -q | xargs docker rm -f 2>/dev/null || true

# Remove images (optional)
if [ "$1" = "--all" ]; then
    echo "Removing Docker images..."
    docker-compose down --rmi all -v
    docker system prune -f
fi

echo "✅ Docker cleanup completed!"
