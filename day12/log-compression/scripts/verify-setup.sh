#!/bin/bash
set -e

echo "🔍 Starting verification process..."

# Function to check service health
check_health() {
  local url=$1
  local name=$2
  echo "Checking $name..."
  
  if curl -f -s "$url" > /dev/null; then
    echo "✅ $name is healthy"
    return 0
  else
    echo "❌ $name is not responding"
    return 1
  fi
}

# Function to verify metrics
verify_metrics() {
  echo "Verifying metrics collection..."
  
  local metrics_response=$(curl -s http://localhost:8080/metrics)
  
  if echo "$metrics_response" | grep -q "log_compression_ratio_percent"; then
    echo "✅ Compression ratio metrics found"
  else
    echo "❌ Compression ratio metrics missing"
    return 1
  fi
  
  if echo "$metrics_response" | grep -q "log_bytes_saved_total"; then
    echo "✅ Bytes saved metrics found"
  else
    echo "❌ Bytes saved metrics missing"
    return 1
  fi
}

# Function to test compression effectiveness
test_compression() {
  echo "Testing compression effectiveness..."
  
  # Generate test data
  node scripts/generate-test-data.js 200
  
  # Wait for processing
  sleep 3
  
  # Check stats
  local stats=$(curl -s http://localhost:8080/stats)
  local compression_ratio=$(echo "$stats" | grep -o '"compressionRatio":"[^"]*"' | cut -d'"' -f4)
  local bandwidth_reduction=$(echo "$stats" | grep -o '"bandwidthReduction":"[^"]*"' | cut -d'"' -f4)
  
  echo "Compression ratio: $compression_ratio%"
  echo "Bandwidth reduction: $bandwidth_reduction"
  
  # Verify compression effectiveness (should be >50%)
  if (( $(echo "$compression_ratio > 50" | bc -l) )); then
    echo "✅ Compression ratio exceeds 50% ($compression_ratio%)"
  else
    echo "❌ Compression ratio below target: $compression_ratio%"
    return 1
  fi
}

# Main verification
echo "Starting service verification..."

# Check if service is running
if ! check_health "http://localhost:8080/health" "Log Compression Service"; then
  echo "Service not running, please start it first"
  exit 1
fi

# Verify endpoints
check_health "http://localhost:8080/health/compression" "Compression Health Check"
check_health "http://localhost:8080/metrics" "Metrics Endpoint"

# Verify functionality
verify_metrics
test_compression

echo "🎉 All verifications passed! Service is production ready."
