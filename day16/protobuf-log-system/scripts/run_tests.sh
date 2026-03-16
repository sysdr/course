#!/bin/bash
set -e

echo "🧪 Running Protocol Buffers Log System Tests..."

# Run unit tests
echo "Running unit tests..."
python -m pytest tests/ -v

# Run performance tests
echo "Running performance benchmarks..."
cd src && python performance_tester.py

echo "✅ All tests completed successfully!"
