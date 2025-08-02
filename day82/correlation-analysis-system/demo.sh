#!/bin/bash

echo "🎬 Correlation Analysis System Demo"
echo "=================================="

# Check if system is running
if ! curl -s http://localhost:8000/health > /dev/null; then
    echo "❌ Backend not running. Please run ./scripts/start.sh first"
    exit 1
fi

echo "📊 Fetching correlation statistics..."
curl -s http://localhost:8000/api/v1/correlations/stats | jq '.'

echo ""
echo "🔗 Fetching recent correlations..."
curl -s http://localhost:8000/api/v1/correlations?limit=5 | jq '.correlations[] | {type: .correlation_type, strength: .strength, timestamp: .timestamp}'

echo ""
echo "📝 Fetching recent logs..."
curl -s http://localhost:8000/api/v1/logs/recent?count=5 | jq '.events[] | {source: .source, level: .level, message: .message, timestamp: .timestamp}'

echo ""
echo "✅ Demo completed!"
echo "🌐 Open http://localhost:3000 to see the live dashboard"
echo "📊 Open http://localhost:8000/api/v1/dashboard for the simple dashboard"
