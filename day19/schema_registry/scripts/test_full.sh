#!/bin/bash

echo "🔍 Running full test suite..."

# Install dependencies
pip install -r requirements.txt

# Start registry server
python -m src.registry &
SERVER_PID=$!

# Wait for server to start
sleep 2

# Run tests
pytest tests/test_registry.py -v

# Stop server
kill $SERVER_PID
