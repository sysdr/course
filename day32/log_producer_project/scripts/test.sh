#!/bin/bash
set -e

echo "🧪 Running tests..."

# Set PYTHONPATH for imports
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Unit tests
echo "Running unit tests..."
python -m pytest tests/test_producer.py -v

echo "✅ All tests passed!"
