#!/bin/bash

set -e

echo "🚀 Day 33: Log Consumer System - One-Click Setup"
echo "================================================"

# Install system dependencies if needed
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y python3-pip redis-server
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &> /dev/null; then
        brew install redis python3
    fi
fi

# Build the project
echo "🏗️  Building project..."
bash scripts/build.sh

# Start Redis if not running
if ! redis-cli ping &> /dev/null 2>&1; then
    echo "🔴 Starting Redis..."
    if command -v redis-server &> /dev/null; then
        redis-server --daemonize yes
        sleep 2
    else
        echo "Starting Redis with Docker..."
        docker run -d -p 6379:6379 --name redis-consumer redis:7.0-alpine
        sleep 5
    fi
fi

# Run tests
echo "🧪 Running tests..."
bash scripts/test.sh

# Run demo
echo "🎮 Starting demo..."
bash scripts/demo.sh
