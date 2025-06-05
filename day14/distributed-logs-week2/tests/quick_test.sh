#!/bin/bash
# quick_test.sh - Simple test without benchmark suite

echo "🚀 Quick Test - Start TCP Server First!"

# Test if server is running
if ! nc -z localhost 8888 2>/dev/null; then
    echo "❌ No server detected on port 8888"
    echo "Run in another terminal: python src/tcp_server.py"
    exit 1
fi

echo "✅ Server detected, running load test..."

# Simple load test
python src/load_generator.py 500 10 3

echo "✅ Test completed! Check benchmark_results.json"