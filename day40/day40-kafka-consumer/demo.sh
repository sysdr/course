#!/bin/bash

# Kafka Consumer Demonstration Script
set -e

echo "🎬 Kafka Consumer Demonstration"
echo "================================"

# Check if services are running
echo "📋 Checking service status..."
if ! docker-compose ps | grep -q "Up"; then
    echo "⚠️  Services not running. Starting them..."
    ./build_and_test.sh
fi

# Start consumer in background
echo "🚀 Starting Kafka consumer..."
export PYTHONPATH="$(pwd):$PYTHONPATH"
cd src
python3 main.py &
CONSUMER_PID=$!
cd ..
echo "Consumer PID: $CONSUMER_PID"

# Wait for consumer to initialize
echo "⏳ Waiting for consumer initialization..."
sleep 10

# Check if dashboard is accessible
echo "🌐 Checking dashboard accessibility..."
for i in {1..30}; do
    if curl -s http://localhost:8080/api/stats > /dev/null; then
        echo "✅ Dashboard is accessible at http://localhost:8080"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Dashboard not accessible after 30 attempts"
        kill $CONSUMER_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# Display initial stats
echo ""
echo "📊 Initial Consumer Stats:"
curl -s http://localhost:8080/api/stats | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f\"Group ID: {data['group_id']}\")
print(f\"Topics: {', '.join(data['topics'])}\")
print(f\"Processed: {data['processed_count']}\")
print(f\"Running: {data['running']}\")
"

# Start test producer in background
echo ""
echo "📤 Starting test log producer..."
python3 scripts/test_producer.py &
PRODUCER_PID=$!

# Monitor processing for 30 seconds
echo ""
echo "⏱️  Monitoring processing for 30 seconds..."
for i in {1..6}; do
    sleep 5
    echo "📈 Stats at ${i}0 seconds:"
    curl -s http://localhost:8080/api/stats | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f\"  Processed: {data['processed_count']} messages\")
print(f\"  Success Rate: {data['success_rate']:.1f}%\")
print(f\"  Errors: {data['error_count']}\")
"
done

# Show analytics results
echo ""
echo "📊 Analytics Results:"
curl -s http://localhost:8080/api/analytics | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(f\"  Request Rate: {data['requests_per_second']:.1f} req/sec\")
    print(f\"  P95 Response Time: {data['response_time_percentiles']['p95']:.1f}ms\")
    print(f\"  Total Endpoints: {len(data['endpoint_stats'])}\")
    print(f\"  Geographic Distribution: {data['geographic_distribution']}\")
    
    if data['endpoint_stats']:
        print('\\n  Top Endpoints:')
        for endpoint, stats in list(data['endpoint_stats'].items())[:3]:
            print(f\"    {endpoint}: {stats['total_requests']} requests, {stats['avg_response_time']:.1f}ms avg\")
except:
    print('  Analytics data not yet available')
"

# Show metrics
echo ""
echo "⚡ Performance Metrics:"
curl -s http://localhost:8080/api/metrics | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(f\"  Throughput: {data['recent_throughput_msg_per_sec']:.1f} msg/sec\")
    print(f\"  Total Batches: {data['total_batches']}\")
    print(f\"  Error Rate: {data['error_rate_percent']:.2f}%\")
    print(f\"  Avg Processing Time: {data['avg_processing_time_seconds']:.3f}s\")
except:
    print('  Metrics data not yet available')
"

# Stop producer
echo ""
echo "⏹️  Stopping test producer..."
kill $PRODUCER_PID 2>/dev/null || true

# Final stats
echo ""
echo "📈 Final Processing Stats:"
curl -s http://localhost:8080/api/stats | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f\"  Total Messages Processed: {data['processed_count']}\")
print(f\"  Final Success Rate: {data['success_rate']:.1f}%\")
print(f\"  Total Errors: {data['error_count']}\")
print(f\"  Consumer Still Running: {data['running']}\")
"

# Keep consumer running for manual testing
echo ""
echo "🎯 Demonstration Complete!"
echo "=========================="
echo ""
echo "🌐 Dashboard: http://localhost:8080"
echo "📊 Live Stats: http://localhost:8080/api/stats"
echo "📈 Analytics: http://localhost:8080/api/analytics"
echo "⚡ Metrics: http://localhost:8080/api/metrics"
echo ""
echo "Consumer is still running (PID: $CONSUMER_PID)"
echo "Press Ctrl+C to stop consumer, or run: kill $CONSUMER_PID"
echo ""
echo "💡 Try these commands:"
echo "  - Generate more logs: python3 scripts/test_producer.py"
echo "  - View Kafka topics: docker exec kafka kafka-topics --list --bootstrap-server localhost:9092"
echo "  - Check consumer groups: docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list"
echo "  - Stop all services: docker-compose down"

# Wait for user interrupt
trap "echo ''; echo '🛑 Stopping consumer...'; kill $CONSUMER_PID 2>/dev/null || true; echo '✅ Demo stopped'; exit 0" SIGINT

echo "Press Ctrl+C to stop the demo..."
wait $CONSUMER_PID 2>/dev/null || true
