#!/bin/bash
set -e

echo "🧪 Running Rate Limiting Tests..."

cd backend

# Install test dependencies
pip install pytest pytest-asyncio

# Run tests
python -m pytest tests/ -v

echo "✅ All tests passed!"
