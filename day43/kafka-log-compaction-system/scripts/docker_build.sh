#!/bin/bash

echo "🐳 Building Docker containers..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose not found. Please install docker-compose first."
    exit 1
fi

# Build the application container
echo "Building application container..."
docker-compose build --no-cache compaction-app

echo "✅ Docker containers built successfully!"
