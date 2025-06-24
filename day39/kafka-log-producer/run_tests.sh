#!/bin/bash

echo "🧪 Running Kafka Producer Test Suite"
echo "=================================="

# Activate virtual environment
source venv/bin/activate

# Set Python path
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

echo "📋 Running unit tests..."
python -m pytest tests/unit/ -v --tb=short

echo "🔗 Running integration tests..."  
python -m pytest tests/integration/ -v --tb=short

echo "⚡ Running performance tests..."
python -m pytest tests/performance/ -v --tb=short -s

echo "✅ All tests completed!"
