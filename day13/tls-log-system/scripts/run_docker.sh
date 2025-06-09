#!/bin/bash

# Docker run script
set -e

echo "🐳 Starting TLS Log System with Docker..."

# Stop any existing containers
docker-compose down 2>/dev/null || true

# Start services
docker-compose up -d

echo "✅ Services started with Docker!"
echo "🔐 TLS Server: https://localhost:8443"
echo "🖥️  Dashboard: http://localhost:8080"
echo ""
echo "View logs with: docker-compose logs -f"
echo "Stop with: docker-compose down"
