#!/bin/bash

echo "🧪 Running Correlation Analysis Tests"
echo "===================================="

# Activate virtual environment
source venv/bin/activate

# Run backend tests
echo "🔧 Running backend tests..."
cd backend
export PYTHONPATH=$(pwd)/src:$PYTHONPATH
python -m pytest tests/ -v --tb=short
cd ..

echo "✅ Tests completed"
