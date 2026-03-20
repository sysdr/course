#!/bin/bash

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "🧹 Cleaning up Docker deployment..."

if command -v docker-compose &> /dev/null; then
    DC=(docker-compose)
elif docker compose version &> /dev/null 2>&1; then
    DC=(docker compose)
else
    echo "❌ docker-compose or 'docker compose' not found."
    exit 1
fi

if [ "${1:-}" = "--all" ]; then
    echo "Removing containers, images, and volumes for this compose project..."
    "${DC[@]}" down --rmi all -v --remove-orphans
    docker system prune -f
else
    "${DC[@]}" down --remove-orphans
fi

docker ps -a --filter "name=kafka-log-compaction" -q 2>/dev/null | xargs docker rm -f 2>/dev/null || true

echo "✅ Docker cleanup completed!"
