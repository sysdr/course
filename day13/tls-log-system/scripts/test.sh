#!/bin/bash

# Test script for TLS Log System
set -e

echo "🧪 Testing TLS Log System..."

# Run local tests
echo "🔬 Running local tests..."
python tests/run_tests.py

# Test Docker containers
echo "🐳 Testing Docker containers..."
docker-compose up -d
sleep 10

# Health checks
echo "🏥 Running health checks..."
curl -f http://localhost:8080/api/health || (echo "❌ Dashboard health check failed" && exit 1)

# Test log transmission
echo "📡 Testing log transmission..."
docker-compose exec -T tls-log-client python src/tls_log_client.py batch

docker-compose down

echo "✅ All tests passed!"
