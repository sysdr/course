#!/bin/bash

echo "🔨 Day 42: Building and Testing Exactly-Once Processing System"
echo "=============================================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "🔍 Checking prerequisites..."
if ! command_exists docker; then
    echo "❌ Docker not found. Please install Docker."
    exit 1
fi

if ! command_exists docker-compose; then
    echo "❌ Docker Compose not found. Please install Docker Compose."
    exit 1
fi

if ! command_exists python3; then
    echo "❌ Python 3 not found. Please install Python 3.9+."
    exit 1
fi

echo "✅ All prerequisites found"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate
pip install -r requirements.txt

echo "✅ Dependencies installed"

# Validate all files exist
echo "📋 Validating project structure..."
required_files=(
    "src/models.py"
    "src/producers/transactional_producer.py"
    "src/consumers/exactly_once_consumer.py"
    "src/monitoring/transaction_monitor.py"
    "src/main.py"
    "web/dashboard.py"
    "web/templates/dashboard.html"
    "config/kafka_config.py"
    "tests/test_exactly_once.py"
    "docker-compose.yml"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing file: $file"
        exit 1
    fi
done

echo "✅ All required files present"

# Test Python syntax
echo "🐍 Validating Python syntax..."
python -m py_compile src/models.py
python -m py_compile src/producers/transactional_producer.py
python -m py_compile src/consumers/exactly_once_consumer.py
python -m py_compile src/monitoring/transaction_monitor.py
python -m py_compile src/main.py
python -m py_compile web/dashboard.py
python -m py_compile config/kafka_config.py

echo "✅ All Python files have valid syntax"

# Run unit tests
echo "🧪 Running unit tests..."
export PYTHONPATH=$(pwd):$PYTHONPATH
python -m pytest tests/test_exactly_once.py -v

if [ $? -eq 0 ]; then
    echo "✅ All tests passed"
else
    echo "❌ Some tests failed"
    exit 1
fi

# Build and start infrastructure
echo "🚀 Starting infrastructure..."
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check service health
echo "🏥 Checking service health..."
if docker-compose ps | grep -q "Up"; then
    echo "✅ Infrastructure services are running"
else
    echo "❌ Some services failed to start"
    docker-compose logs
    exit 1
fi

# Create Kafka topics
echo "📝 Creating Kafka topics..."
topics=("banking-transfers" "account-balance-updates" "transaction-notifications")

for topic in "${topics[@]}"; do
    docker exec day42-exactly-once-kafka-kafka-1 \
        kafka-topics --bootstrap-server localhost:9092 \
        --create --topic "$topic" \
        --partitions 3 --replication-factor 1 \
        --if-not-exists >/dev/null 2>&1
    echo "✅ Topic created: $topic"
done

echo ""
echo "🎉 Build and test completed successfully!"
echo ""
echo "🚀 To run the demonstration:"
echo "   python scripts/demo.py"
echo ""
echo "🌐 Or start components individually:"
echo "   python -m src.main producer    # Start transaction producer"
echo "   python -m src.main consumer    # Start exactly-once consumer"
echo "   python -m src.main web         # Start web dashboard (localhost:5000)"
echo "   python -m src.main monitor     # Start CLI monitor"
echo ""
echo "🛑 To stop infrastructure:"
echo "   docker-compose down"
echo ""
echo "📊 Dashboard will be available at: http://localhost:5000"
echo ""
