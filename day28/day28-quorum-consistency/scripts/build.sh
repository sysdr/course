#!/bin/bash

echo "🔨 Building Quorum Consistency System..."

# Install dependencies
pip install --only-binary=all -r requirements.txt

echo "✅ Dependencies installed"

# Run tests
python -m pytest tests/ -v

echo "✅ Tests passed"

# Start the web interface
echo "🚀 Starting web interface on http://localhost:8000"
uvicorn src.web_interface:app --reload --host 0.0.0.0 --port 8000
