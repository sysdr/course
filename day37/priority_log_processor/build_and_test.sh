#!/bin/bash

echo "🏗️ Building Priority Queue System"
echo "================================"

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Install package in development mode
echo "📦 Installing package..."
pip install -e .

# Run unit tests
echo "🧪 Running unit tests..."
python -m pytest tests/test_priority_queue.py -v

# Run integration tests
echo "🔗 Running integration tests..."
python -m pytest tests/test_integration.py -v

# Build Docker image
echo "🐳 Building Docker image..."
cd docker
docker-compose build

echo "✅ Build and test completed successfully!"
echo ""
echo "🚀 To start the system:"
echo "   Local: python demo/web_dashboard.py"
echo "   Docker: cd docker && docker-compose up"
echo ""
echo "📊 Dashboard will be available at: http://localhost:8080"
