#!/bin/bash
set -e

# Activate virtual environment
source venv/bin/activate

# Run unit tests
echo "Running unit tests..."
python -m unittest tests/test_compression.py

# Run integration tests
echo "Running integration tests..."
python -m unittest tests/integration_test.py

echo "All tests completed!"
