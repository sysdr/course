#!/bin/bash

echo "🐳 Building Docker Image..."

# Build Docker image
docker build -t anti-entropy-system .

# Run with docker-compose
docker-compose up --build

echo "✅ Docker build completed!"
echo "Access dashboard at: http://localhost:5000"
