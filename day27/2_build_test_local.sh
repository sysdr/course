#!/bin/bash

# Day 27: Distributed Log Query System - Local Build & Test Script
# Builds and tests the system locally without Docker

set -e

echo "🔨 Building & Testing Distributed Log Query System Locally"
echo "========================================================="

cd distributed_query_system

# Install Python dependencies
echo "📦 Installing Python dependencies..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "✅ Dependencies installed"

# Run unit tests
echo "🧪 Running unit tests..."
python -m pytest tests/ -v --tb=short

echo "✅ Unit tests passed"

# Create data directories
echo "📁 Creating data directories..."
mkdir -p data/partition_1
mkdir -p data/partition_2

# Start partition servers in background
echo "🚀 Starting partition servers..."

# Start partition 1
echo "Starting partition server 1 on port 8081..."
python -m src.partition_server partition_1 8081 &
PARTITION1_PID=$!

# Start partition 2
echo "Starting partition server 2 on port 8082..."
python -m src.partition_server partition_2 8082 &
PARTITION2_PID=$!

# Wait for partition servers to start
echo "⏳ Waiting for partition servers to initialize..."
sleep 10

# Check if partition servers are running
echo "🔍 Checking partition server health..."
check_partition_health() {
    local port=$1
    local partition_name=$2
    
    echo "Checking $partition_name health on port $port..."
    
    for i in {1..5}; do
        if curl -s -f "http://localhost:$port/health" > /dev/null; then
            echo "✅ $partition_name is healthy"
            return 0
        fi
        echo "⏳ Waiting for $partition_name... (attempt $i/5)"
        sleep 2
    done
    
    echo "❌ $partition_name failed to start"
    return 1
}

# Check both partitions
check_partition_health 8081 "Partition 1" || {
    echo "❌ Partition 1 failed to start"
    kill $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    exit 1
}

check_partition_health 8082 "Partition 2" || {
    echo "❌ Partition 2 failed to start"
    kill $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    exit 1
}

# Start main coordinator
echo "🚀 Starting query coordinator..."
python -m src.main &
COORDINATOR_PID=$!

# Wait for coordinator to start
echo "⏳ Waiting for coordinator to initialize..."
sleep 10

# Check coordinator health
echo "🔍 Checking coordinator health..."
check_coordinator_health() {
    for i in {1..5}; do
        if curl -s -f "http://localhost:8080/health" > /dev/null; then
            echo "✅ Query coordinator is healthy"
            return 0
        fi
        echo "⏳ Waiting for coordinator... (attempt $i/5)"
        sleep 2
    done
    
    echo "❌ Query coordinator failed to start"
    return 1
}

check_coordinator_health || {
    echo "❌ Query coordinator failed to start"
    kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    exit 1
}

# Run integration tests
echo "🧪 Running integration tests..."

# Test 1: Basic health check
echo "Test 1: Health check"
HEALTH_RESPONSE=$(curl -s "http://localhost:8080/health")
echo "Health response: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    exit 1
fi

# Test 2: Get system stats
echo "Test 2: System statistics"
STATS_RESPONSE=$(curl -s "http://localhost:8080/stats")
echo "Stats response: $STATS_RESPONSE"

if echo "$STATS_RESPONSE" | grep -q "partitions"; then
    echo "✅ Stats retrieval passed"
else
    echo "❌ Stats retrieval failed"
    kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    exit 1
fi

# Test 3: Get partition information
echo "Test 3: Partition information"
PARTITIONS_RESPONSE=$(curl -s "http://localhost:8080/partitions")
echo "Partitions response: $PARTITIONS_RESPONSE"

if echo "$PARTITIONS_RESPONSE" | grep -q "partition_1"; then
    echo "✅ Partition information retrieval passed"
else
    echo "❌ Partition information retrieval failed"
    kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    exit 1
fi

# Test 4: Basic query without filters
echo "Test 4: Basic query execution"
BASIC_QUERY='{
    "sort_field": "timestamp",
    "sort_order": "desc",
    "limit": 10
}'

QUERY_RESPONSE=$(curl -s -X POST "http://localhost:8080/query" \
    -H "Content-Type: application/json" \
    -d "$BASIC_QUERY")

echo "Query response: $QUERY_RESPONSE"

if echo "$QUERY_RESPONSE" | grep -q "results"; then
    echo "✅ Basic query execution passed"
else
    echo "❌ Basic query execution failed"
    kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    exit 1
fi

# Test 5: Filtered query
echo "Test 5: Filtered query execution"
FILTERED_QUERY='{
    "sort_field": "timestamp",
    "sort_order": "desc",
    "limit": 5,
    "filters": [
        {
            "field": "level",
            "operator": "eq",
            "value": "ERROR"
        }
    ]
}'

FILTERED_RESPONSE=$(curl -s -X POST "http://localhost:8080/query" \
    -H "Content-Type: application/json" \
    -d "$FILTERED_QUERY")

echo "Filtered query response: $FILTERED_RESPONSE"

if echo "$FILTERED_RESPONSE" | grep -q "results"; then
    echo "✅ Filtered query execution passed"
else
    echo "❌ Filtered query execution failed"
    kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    exit 1
fi

# Test 6: Time range query
echo "Test 6: Time range query execution"
CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S")
PAST_TIME=$(date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%S")

TIME_RANGE_QUERY="{
    \"time_range\": {
        \"start\": \"${PAST_TIME}\",
        \"end\": \"${CURRENT_TIME}\"
    },
    \"sort_field\": \"timestamp\",
    \"sort_order\": \"desc\",
    \"limit\": 10
}"

TIME_RANGE_RESPONSE=$(curl -s -X POST "http://localhost:8080/query" \
    -H "Content-Type: application/json" \
    -d "$TIME_RANGE_QUERY")

echo "Time range query response: $TIME_RANGE_RESPONSE"

if echo "$TIME_RANGE_RESPONSE" | grep -q "results"; then
    echo "✅ Time range query execution passed"
else
    echo "❌ Time range query execution failed"
    kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    exit 1
fi

# Test 7: Performance test
echo "Test 7: Performance test"
echo "Running 10 concurrent queries..."

# Function to run a single query
run_query() {
    local query_num=$1
    curl -s -X POST "http://localhost:8080/query" \
        -H "Content-Type: application/json" \
        -d '{"sort_field": "timestamp", "sort_order": "desc", "limit": 20}' \
        > /dev/null
    echo "Query $query_num completed"
}

# Run queries in parallel
START_TIME=$(date +%s.%N)
for i in {1..10}; do
    run_query $i &
done
wait

END_TIME=$(date +%s.%N)
DURATION=$(echo "$END_TIME - $START_TIME" | bc)

echo "✅ Performance test completed in ${DURATION} seconds"

# Test 8: Web interface accessibility
echo "Test 8: Web interface test"
WEB_RESPONSE=$(curl -s "http://localhost:8080/")

if echo "$WEB_RESPONSE" | grep -q "Distributed Log Query System"; then
    echo "✅ Web interface is accessible"
else
    echo "❌ Web interface test failed"
    kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    exit 1
fi

# Performance metrics
echo ""
echo "📊 Performance Metrics:"
echo "======================="

# Get detailed stats
FINAL_STATS=$(curl -s "http://localhost:8080/stats")
echo "Final system stats: $FINAL_STATS"

# Extract metrics
HEALTHY_PARTITIONS=$(echo "$FINAL_STATS" | grep -o '"healthy":[0-9]*' | cut -d':' -f2)
TOTAL_PARTITIONS=$(echo "$FINAL_STATS" | grep -o '"total":[0-9]*' | cut -d':' -f2)

echo "Healthy partitions: $HEALTHY_PARTITIONS/$TOTAL_PARTITIONS"

# Cleanup function
cleanup() {
    echo ""
    echo "🧹 Cleaning up processes..."
    kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID 2>/dev/null || true
    
    # Wait a moment for graceful shutdown
    sleep 2
    
    # Force kill if still running
    pkill -f "partition_server" 2>/dev/null || true
    pkill -f "src.main" 2>/dev/null || true
    
    echo "✅ Cleanup completed"
}

# Set up cleanup on script exit
trap cleanup EXIT

echo ""
echo "🎉 All local tests passed successfully!"
echo "======================================"
echo ""
echo "📋 Test Summary:"
echo "• Health checks: ✅"
echo "• System stats: ✅" 
echo "• Partition discovery: ✅"
echo "• Basic queries: ✅"
echo "• Filtered queries: ✅"
echo "• Time range queries: ✅"
echo "• Performance test: ✅"
echo "• Web interface: ✅"
echo ""
echo "🌐 Access the web interface at: http://localhost:8080"
echo "📊 View system stats at: http://localhost:8080/stats"
echo "🔍 Check partition health at: http://localhost:8080/partitions"
echo ""
echo "⏹️  Press Ctrl+C to stop all services"

# Keep services running for manual testing
echo "🔄 Services are running. Press Ctrl+C to stop."
while true; do
    sleep 30
    # Check if services are still healthy
    if ! curl -s -f "http://localhost:8080/health" > /dev/null; then
        echo "❌ Coordinator seems to have stopped"
        break
    fi
    
    if ! curl -s -f "http://localhost:8081/health" > /dev/null; then
        echo "❌ Partition 1 seems to have stopped"
        break
    fi
    
    if ! curl -s -f "http://localhost:8082/health" > /dev/null; then
        echo "❌ Partition 2 seems to have stopped"
        break
    fi
    
    echo "✅ All services healthy at $(date)"
done