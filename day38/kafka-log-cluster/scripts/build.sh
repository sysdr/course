#!/bin/bash
set -e

echo "🔨 Building Kafka Log Processing System..."

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Make scripts executable
chmod +x scripts/*.py scripts/*.sh
chmod +x src/*.py
chmod +x demo/*.py

echo "✅ Build completed successfully!"
