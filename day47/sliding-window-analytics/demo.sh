#!/bin/bash

# Demo script for Sliding Window Analytics
# This script installs dependencies, builds and runs the application

set -e  # Exit on any error

echo "🚀 Starting Sliding Window Analytics Demo"
echo "=========================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose is not installed. Please install docker-compose and try again."
    exit 1
fi

echo "✅ Docker and docker-compose are available"

# Stop any existing containers
echo "🛑 Stopping any existing containers..."
docker-compose down --remove-orphans 2>/dev/null || true

# Clean up any existing images (optional - uncomment if you want to force rebuild)
# echo "🧹 Cleaning up existing images..."
# docker-compose down --rmi all --volumes --remove-orphans 2>/dev/null || true

# Build and start the containers
echo "🔨 Building and starting containers..."
docker-compose up --build -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if services are running
echo "🔍 Checking service status..."
if docker-compose ps | grep -q "Up"; then
    echo "✅ Services are running successfully!"
    echo ""
    echo "📊 Application is now running at:"
    echo "   - API: http://localhost:8000"
    echo "   - API Docs: http://localhost:8000/docs"
    echo "   - Redis: localhost:6379"
    echo ""
    echo "📝 To view logs: docker-compose logs -f"
    echo "🛑 To stop: ./cleanup.sh"
    echo ""
    echo "🎉 Demo is ready! The application is generating sample events and processing them."
else
    echo "❌ Services failed to start properly"
    echo "📋 Checking logs..."
    docker-compose logs
    exit 1
fi

echo "=========================================="
echo "🎯 Demo setup complete!" 