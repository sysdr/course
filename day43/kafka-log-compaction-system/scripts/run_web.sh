#!/bin/bash

echo "🌐 Starting web dashboard..."

# Build first
./scripts/build.sh

# Check if Kafka is running
if ! nc -z localhost 9092 2>/dev/null; then
    echo "❌ Kafka not running. Please start Kafka first:"
    echo "   docker-compose up -d"
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Set Python path
export PYTHONPATH="$(pwd):$PYTHONPATH"

# Run the web dashboard
python src/web_app.py
