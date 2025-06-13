#!/bin/bash

set -e

echo "🧪 Running Tests"
echo "==============="

# Unit tests
echo "Running unit tests..."
python -m pytest tests/unit/ -v --tb=short

# Integration tests (if Redis is available)
if redis-cli ping &> /dev/null; then
    echo "Running integration tests..."
    python -m pytest tests/integration/ -v --tb=short
else
    echo "⚠️  Redis not available, skipping integration tests"
fi

echo "✅ All tests passed!"
