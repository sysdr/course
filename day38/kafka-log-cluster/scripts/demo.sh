#!/bin/bash
set -e

echo "🎬 Starting Kafka Cluster Demo..."

# Start Docker containers
echo "🐳 Starting Docker containers..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Setup cluster and topics
echo "⚙️ Setting up cluster and topics..."
python scripts/setup_cluster.py

# Start dashboard in background
echo "📊 Starting monitoring dashboard..."
python demo/dashboard.py &
DASHBOARD_PID=$!

# Start log generation
echo "📝 Starting log generation..."
python src/log_producer.py &
PRODUCER_PID=$!

# Start error aggregation
echo "🔍 Starting error aggregation..."
python src/error_aggregator.py &
AGGREGATOR_PID=$!

echo ""
echo "🎉 Demo is running!"
echo "📊 Dashboard: http://localhost:8000"
echo "🖥️  Kafka UI: http://localhost:8080"
echo ""
echo "Press Ctrl+C to stop demo"

# Wait for interrupt
trap "echo 'Stopping demo...'; kill $DASHBOARD_PID $PRODUCER_PID $AGGREGATOR_PID 2>/dev/null; docker-compose down; exit 0" INT
wait
