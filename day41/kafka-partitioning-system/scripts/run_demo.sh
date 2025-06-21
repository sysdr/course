#!/bin/bash

# Demo script for Kafka Partitioning & Consumer Groups

echo "🎬 Starting Kafka Partitioning & Consumer Groups Demo"
echo "=================================================="

# Activate virtual environment
#source venv/bin/activate

# Ensure infrastructure is running
echo "🐳 Ensuring Kafka infrastructure is running..."
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to be ready..."
timeout=60
counter=0
while ! docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list &>/dev/null; do
    if [ $counter -ge $timeout ]; then
        echo "❌ Kafka failed to start within $timeout seconds"
        exit 1
    fi
    echo "Waiting for Kafka... ($counter/$timeout)"
    sleep 1
    ((counter++))
done

echo "✅ Kafka is ready!"

# Start web dashboard in background
echo "🌐 Starting web dashboard..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
cd src
python main.py --web &
WEB_PID=$!
cd ..

sleep 5

echo ""
echo "📊 Dashboard available at: http://localhost:8080"
echo "🔍 Kafka UI available at: http://localhost:8081"
echo ""
echo "🎯 Demo Instructions:"
echo "1. Open http://localhost:8080 in your browser"
echo "2. Click 'Setup Topic' to create the partitioned topic"
echo "3. Click 'Start Demo' to begin producing and consuming messages"
echo "4. Watch the real-time partition assignments and processing stats"
echo "5. Try scaling consumers up/down to see rebalancing"
echo ""
echo "💡 Alternatively, run CLI demo with:"
echo "   cd src && python main.py --consumers 3 --rate 20 --duration 60"
echo ""
echo "Press Ctrl+C to stop the demo..."

# Keep demo running
trap "echo '🛑 Stopping demo...'; kill $WEB_PID 2>/dev/null; docker-compose down; exit 0" INT

wait $WEB_PID
