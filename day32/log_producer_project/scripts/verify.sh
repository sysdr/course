#!/bin/bash
set -e

echo "🔍 Verifying Log Producer..."

# Wait for service to start
echo "Waiting for service to start..."
sleep 5

# Check health endpoint
echo "Checking health endpoint..."
response=$(curl -s http://localhost:8080/health)
echo "Health response: $response"

# Send test logs
echo "Sending test logs..."
for i in {1..10}; do
    curl -s -X POST http://localhost:8080/logs \
        -H "Content-Type: application/json" \
        -d "{\"level\":\"INFO\",\"message\":\"Test log $i\",\"source\":\"test\"}"
done

# Check metrics
echo "Checking metrics..."
metrics=$(curl -s http://localhost:8080/metrics)
echo "Metrics: $metrics"

# Run load test
echo "Running load test..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
python tests/load_test.py

echo "✅ Verification completed!"
