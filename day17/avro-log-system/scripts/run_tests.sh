#!/bin/bash

# Run comprehensive test suite
set -e

echo "🧪 Running Avro Schema Evolution Test Suite"
echo "============================================"

# Run with coverage
python -m pytest src/tests/ -v --cov=src --cov-report=html --cov-report=term

echo ""
echo "📊 Test Results Summary:"
echo "- Unit tests: Schema evolution functionality"  
echo "- Integration tests: Web API endpoints"
echo "- Coverage report: htmlcov/index.html"
echo ""
echo "✅ All tests completed!"
