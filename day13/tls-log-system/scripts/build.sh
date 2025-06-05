#!/bin/bash

# Build script for TLS Log System
set -e

echo "🏗️  Building TLS Log System..."

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Build Docker images
echo "🐳 Building Docker images..."
docker-compose build --no-cache

echo "✅ Build completed successfully!"
