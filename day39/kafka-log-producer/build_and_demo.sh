#!/bin/bash

echo "🚀 Kafka Producer Build and Demo Script"
echo "======================================="

# Check if Kafka is running
check_kafka() {
    echo "🔍 Checking Kafka connectivity..."
    python -c "
from kafka import KafkaProducer
try:
    producer = KafkaProducer(bootstrap_servers=['localhost:9092'], request_timeout_ms=5000)
    producer.close()
    print('✅ Kafka is running')
except:
    print('❌ Kafka not available - starting with Docker')
    exit(1)
" 2>/dev/null || return 1
}

# Start Kafka with Docker if not running
if ! check_kafka; then
    echo "🐳 Starting Kafka with Docker Compose..."
    docker-compose up -d kafka
    
    echo "⏳ Waiting for Kafka to be ready..."
    for i in {1..30}; do
        if check_kafka; then
            break
        fi
        echo "Waiting... ($i/30)"
        sleep 2
    done
    
    if ! check_kafka; then
        echo "❌ Failed to start Kafka"
        exit 1
    fi
fi

# Activate virtual environment
source venv/bin/activate

# Set Python path
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

echo "🧪 Running tests..."
./run_tests.sh

if [ $? -eq 0 ]; then
    echo ""
    echo "🎬 Starting Producer Demo..."
    python src/main.py demo &
    DEMO_PID=$!
    
    echo ""
    echo "📊 Starting Web Dashboard..."
    python web/app.py &
    WEB_PID=$!
    
    echo ""
    echo "⏳ Waiting for services to start..."
    sleep 5
    
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
    echo ""
    echo "Press Ctrl+C to stop all services"
    
    # Wait for user interrupt
    trap "echo 'Stopping services...'; kill $DEMO_PID $WEB_PID 2>/dev/null; exit" INT
    wait
else
    echo "❌ Tests failed - demo cancelled"
    exit 1
fi
