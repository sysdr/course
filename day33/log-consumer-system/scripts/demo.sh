#!/bin/bash

set -e

echo "🎮 Running Consumer Demo"
echo "======================="

# Check if Redis is running
if ! redis-cli ping &> /dev/null; then
    echo "❌ Redis is not running. Please start Redis first:"
    echo "   docker run -d -p 6379:6379 redis:7.0-alpine"
    exit 1
fi

# Generate demo data
echo "📊 Generating demo logs..."
python scripts/generate_demo_logs.py &

# Wait a moment for data generation
sleep 2

# Start consumer system
echo "🚀 Starting consumer system..."
echo "Dashboard will be available at: http://localhost:8000"
python -m src.main
