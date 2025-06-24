#!/bin/bash

echo "🚀 Starting Kafka Dashboard Demo..."

# Check for and activate virtual environment if it exists
VENV_PATH="/Users/sumedhshende/sysd/course/day44/env"
if [ -d "$VENV_PATH" ]; then
    echo "🐍 Activating virtual environment..."
    source "$VENV_PATH/bin/activate"
    echo "✅ Virtual environment activated: $(which python)"
else
    echo "⚠️  No virtual environment found, using system Python"
fi

# Install Python dependencies first
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Navigate to docker directory
cd docker || exit 1

# Copy necessary files for Docker build
echo "📁 Copying files for Docker build..."
cp ../requirements.txt .
cp -r ../src .
cp -r ../web .

# Start Zookeeper and Kafka first
echo "🐳 Starting Zookeeper and Kafka..."
docker-compose up -d zookeeper kafka

# Wait for Zookeeper and Kafka to be ready
echo "⏳ Waiting for Zookeeper and Kafka to initialize..."
sleep 20

# Create Kafka topics (if they don't exist)
echo "📊 Creating Kafka topics..."
docker exec kafka kafka-topics --create --topic log-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists 2>/dev/null || true
docker exec kafka kafka-topics --create --topic error-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists 2>/dev/null || true
docker exec kafka kafka-topics --create --topic user-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists 2>/dev/null || true

# Wait for topics to be created
echo "⏳ Waiting for topics to be created..."
sleep 5

# Start data generator container
echo "📈 Starting data generator container..."
docker-compose up -d data-generator

# Wait for data generator to start
echo "⏳ Waiting for data generator to start..."
sleep 10

# Start dashboard container last
echo "📊 Starting dashboard container..."
docker-compose up -d dashboard

# Wait for dashboard to be ready
echo "⏳ Waiting for dashboard to initialize..."
sleep 10

# Open the dashboard in the default browser
echo "🌐 Opening dashboard in browser..."
if command -v open > /dev/null; then
  open http://localhost:5000
elif command -v xdg-open > /dev/null; then
  xdg-open http://localhost:5000
else
  echo "Please open http://localhost:5000 in your browser."
fi

echo ""
echo "🎉 Demo is running!"
echo "📊 Dashboard: http://localhost:5000"
echo "🐍 Python environment: $(which python)"
echo ""
echo "To stop the demo:"
echo "cd docker && docker-compose down"
echo ""
echo "Press Ctrl+C to stop everything at once"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping demo..."
    cd docker && docker-compose down
    echo "✅ Demo stopped!"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Keep script running
wait 