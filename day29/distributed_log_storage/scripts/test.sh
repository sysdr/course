#!/bin/bash

echo "🧪 Running Anti-Entropy Tests..."

# Activate virtual environment
source venv/bin/activate

# Run unit tests
echo "Running unit tests..."
python -m pytest tests/unit/ -v

# Run integration tests
echo "Running integration tests..."
python -m pytest tests/integration/ -v

echo "✅ All tests completed!"
