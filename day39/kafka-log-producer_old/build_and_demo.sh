#!/bin/bash

echo "🚀 Kafka Producer Build and Demo Script"
echo "======================================="

# Activate virtual environment first
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Set Python path
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p web/static

# Check if Kafka is running
check_kafka() {
    echo "🔍 Checking Kafka connectivity..."
    python -c "
from confluent_kafka import Producer
try:
    producer = Producer({'bootstrap.servers': 'localhost:9092'})
    producer.flush(timeout=5)
    print('✅ Kafka is running')
except Exception as e:
    print('❌ Kafka not available - starting with Docker')
    exit(1)
" 2>/dev/null || return 1
}

# Start Kafka with Docker if not running
if ! check_kafka; then
    echo "🐳 Starting Kafka with Docker Compose..."
    docker-compose build
    docker-compose up -d zookeeper kafka kafka-ui
    
    echo "⏳ Waiting for Zookeeper to be ready..."
    for i in {1..30}; do
        if docker-compose exec -T zookeeper echo "ready" >/dev/null 2>&1; then
            echo "✅ Zookeeper is ready"
            break
        fi
        echo "Waiting for Zookeeper... ($i/30)"
        sleep 2
    done
    
    echo "⏳ Waiting for Kafka to be ready..."
    for i in {1..60}; do
        if check_kafka; then
            echo "✅ Kafka is ready"
            break
        fi
        echo "Waiting for Kafka... ($i/60)"
        sleep 3
    done
    
    if ! check_kafka; then
        echo "❌ Failed to start Kafka"
        docker-compose logs kafka
        exit 1
    fi
fi

echo "🧪 Running tests..."
./run_tests.sh

if [ $? -eq 0 ]; then
    echo ""
    echo "🎬 Starting Producer Demo..."
    python src/main.py demo &
    DEMO_PID=$!
    
    echo ""
    echo "📊 Starting Web Dashboard..."
    # Start web app from project root with proper PYTHONPATH
    python web/app.py &
    WEB_PID=$!
    
    echo ""
    echo "⏳ Waiting for services to start..."
    sleep 15
    
    # Check if web app is running
    echo "🔍 Checking web dashboard..."
    if curl -s http://localhost:8080/api/stats > /dev/null 2>&1; then
        echo "✅ Web Dashboard is running"
    else
        echo "⚠️  Web Dashboard may not be fully started yet"
    fi
    
    # Check if metrics server is running
    echo "🔍 Checking metrics server..."
    if curl -s http://localhost:8000 > /dev/null 2>&1; then
        echo "✅ Metrics server is running"
    else
        echo "⚠️  Metrics server may not be fully started yet"
    fi
    
    echo ""
    echo "🎯 Demo Information:"
    echo "- Producer Demo: Running (PID: $DEMO_PID)"
    echo "- Web Dashboard: http://localhost:8080"
    echo "- Producer Metrics: http://localhost:8000"
    echo "- Kafka UI: http://localhost:8081"
    echo ""
    echo "💡 Try these commands:"
    echo "  - curl http://localhost:8080/api/stats"
    echo "  - curl -X POST http://localhost:8080/api/send-sample"
    echo "  - curl http://localhost:8000 (metrics)"
    echo ""
    echo "Press Ctrl+C to stop all services"
    
    # Wait for user interrupt
    trap "echo 'Stopping services...'; kill $DEMO_PID $WEB_PID 2>/dev/null; docker-compose down; exit" INT
    wait
else
    echo "❌ Tests failed - demo cancelled"
    exit 1
fi
