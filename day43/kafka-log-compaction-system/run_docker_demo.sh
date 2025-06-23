#!/bin/bash

set -e

echo "🐳 Kafka Log Compaction Docker Demo"
echo "===================================="

# Build Docker containers
echo "🔨 Building Docker containers..."
./scripts/docker_build.sh

# Run Docker deployment
echo "🚀 Starting Docker deployment..."
./scripts/docker_run.sh

echo ""
echo "🎉 Docker demo is running!"
echo "📊 Web Dashboard: http://localhost:8080"
echo "📋 Check logs: docker-compose logs -f"
echo ""
echo "Press Ctrl+C to stop the demo"

# Wait for interrupt
trap "echo '🛑 Stopping Docker demo...'; ./scripts/docker_cleanup.sh; exit 0" INT

# Keep running
while true; do
    sleep 1
done
