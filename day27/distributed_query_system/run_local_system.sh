#!/bin/bash

echo "🚀 Starting Distributed Query System Locally"
echo "============================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "📦 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Start services in background
echo "🚀 Starting services..."

# Start partition servers
echo "Starting partition server 1..."
python run_partition_server.py partition_1 8081 > logs/partition1.log 2>&1 &
PARTITION1_PID=$!

echo "Starting partition server 2..."  
python run_partition_server.py partition_2 8082 > logs/partition2.log 2>&1 &
PARTITION2_PID=$!

# Wait for partition servers to start
sleep 5

echo "Starting query coordinator..."
python run_coordinator.py > logs/coordinator.log 2>&1 &
COORDINATOR_PID=$!

# Wait for coordinator to start
sleep 5

echo "✅ All services started!"
echo ""
echo "🌐 Access Points:"
echo "• Web Interface: http://localhost:8080"
echo "• System Stats: http://localhost:8080/stats"
echo "• Partition 1 Health: http://localhost:8081/health"
echo "• Partition 2 Health: http://localhost:8082/health"
echo ""
echo "📋 Process IDs:"
echo "• Coordinator PID: $COORDINATOR_PID"
echo "• Partition 1 PID: $PARTITION1_PID"  
echo "• Partition 2 PID: $PARTITION2_PID"
echo ""
echo "🛑 To stop all services: kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID"
echo ""
echo "📊 Checking service health..."

# Health checks
sleep 2
curl -s http://localhost:8080/health && echo " ✅ Coordinator healthy" || echo " ❌ Coordinator not responding"
curl -s http://localhost:8081/health && echo " ✅ Partition 1 healthy" || echo " ❌ Partition 1 not responding"  
curl -s http://localhost:8082/health && echo " ✅ Partition 2 healthy" || echo " ❌ Partition 2 not responding"

echo ""
echo "Press Ctrl+C to stop all services"

# Keep script running and handle cleanup
cleanup() {
    echo ""
    echo "🧹 Stopping all services..."
    kill $COORDINATOR_PID $PARTITION1_PID $PARTITION2_PID 2>/dev/null
    echo "✅ All services stopped"
}

trap cleanup EXIT
wait
