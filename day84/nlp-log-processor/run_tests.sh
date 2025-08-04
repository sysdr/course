#!/bin/bash

set -e

source venv/bin/activate

echo "🧪 Running NLP Log Processor Tests"
echo "================================="

# Run unit tests
echo "🔬 Running unit tests..."
python -m pytest tests/test_nlp_processor.py -v

# Run integration tests (only if server is not running)
if ! curl -s http://localhost:5000/api/health > /dev/null 2>&1; then
    echo "🔗 Starting server for integration tests..."
    python src/api/server.py &
    SERVER_PID=$!
    sleep 5
    
    echo "🔗 Running integration tests..."
    python -m pytest tests/test_integration.py -v
    
    kill $SERVER_PID
    wait $SERVER_PID 2>/dev/null || true
else
    echo "🔗 Running integration tests (server already running)..."
    python -m pytest tests/test_integration.py -v
fi

echo "✅ All tests completed successfully!"
