#!/bin/bash

# Docker build and run script
set -e

echo "🐳 Building Docker container..."

# Build the image
docker build -f docker/Dockerfile -t avro-log-system .

echo "✅ Docker image built successfully!"
echo ""
echo "To run the container:"
echo "  docker run -p 5000:5000 avro-log-system"
echo ""
echo "Or use docker-compose:"
echo "  docker-compose up"
