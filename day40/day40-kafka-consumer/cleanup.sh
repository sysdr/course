#!/bin/bash

# Kafka Consumer Cleanup Script
# Stops all processes and Docker containers, cleans up resources

echo "🧹 Starting Kafka Consumer Cleanup..."
echo "====================================="

# Function to print colored output
print_status() {
    echo "✅ $1"
}

print_warning() {
    echo "⚠️  $1"
}

print_info() {
    echo "📋 $1"
}

# Stop any running local Python consumer processes
print_info "Stopping local Python consumer processes..."
if pkill -f "python.*main.py" 2>/dev/null; then
    print_status "Local consumer processes stopped"
else
    print_info "No local consumer processes found"
fi

# Stop any running test producer processes
print_info "Stopping test producer processes..."
if pkill -f "test_producer.py" 2>/dev/null; then
    print_status "Test producer processes stopped"
else
    print_info "No test producer processes found"
fi

# Stop Docker containers and services
print_info "Stopping Docker containers and services..."
if docker-compose down --volumes --remove-orphans 2>/dev/null; then
    print_status "Docker containers stopped and removed"
else
    print_warning "No Docker containers to stop or docker-compose not available"
fi

# Force stop any remaining containers by name
print_info "Checking for any remaining containers..."
CONTAINERS=$(docker ps -a --filter "name=kafka" --filter "name=redis" --filter "name=zookeeper" -q 2>/dev/null)
if [ ! -z "$CONTAINERS" ]; then
    print_info "Force stopping remaining containers..."
    docker stop $CONTAINERS 2>/dev/null
    docker rm $CONTAINERS 2>/dev/null
    print_status "Remaining containers cleaned up"
else
    print_info "No remaining containers found"
fi

# Clean up Docker networks
print_info "Cleaning up Docker networks..."
NETWORKS=$(docker network ls --filter "name=day40-kafka-consumer" -q 2>/dev/null)
if [ ! -z "$NETWORKS" ]; then
    docker network rm $NETWORKS 2>/dev/null
    print_status "Docker networks cleaned up"
fi

# Optional: Clean up Docker system (images, cache, etc.)
if [ "$1" = "--full" ] || [ "$1" = "-f" ]; then
    print_info "Performing full Docker cleanup..."
    RECLAIMED=$(docker system prune -f 2>/dev/null | grep "Total reclaimed space" | cut -d: -f2)
    if [ ! -z "$RECLAIMED" ]; then
        print_status "Docker system cleaned up -$RECLAIMED"
    else
        print_status "Docker system cleaned up"
    fi
fi

# Verify cleanup
print_info "Verifying cleanup..."

# Check for running containers
RUNNING_CONTAINERS=$(docker ps -q 2>/dev/null | wc -l)
if [ "$RUNNING_CONTAINERS" -eq 0 ]; then
    print_status "No Docker containers running"
else
    print_warning "$RUNNING_CONTAINERS Docker containers still running"
fi

# Check for Python processes
PYTHON_PROCESSES=$(ps aux | grep -E "(python.*main|test_producer)" | grep -v grep | wc -l)
if [ "$PYTHON_PROCESSES" -eq 0 ]; then
    print_status "No Python consumer/producer processes running"
else
    print_warning "$PYTHON_PROCESSES Python processes still running"
fi

# Check if ports are free
print_info "Checking if ports are available..."
for port in 8080 9092 6379 2181; do
    if ! lsof -i:$port >/dev/null 2>&1; then
        print_status "Port $port is available"
    else
        print_warning "Port $port is still in use"
    fi
done

echo ""
echo "🎯 Cleanup Complete!"
echo "===================="
echo ""
echo "📊 Cleanup Summary:"
echo "  ✅ Docker containers stopped and removed"
echo "  ✅ Python processes terminated"
echo "  ✅ Network resources cleaned up"
if [ "$1" = "--full" ] || [ "$1" = "-f" ]; then
    echo "  ✅ Docker system cache cleaned"
fi
echo ""
echo "💡 Usage:"
echo "  ./cleanup.sh           # Basic cleanup"
echo "  ./cleanup.sh --full    # Full cleanup including Docker cache"
echo "  ./cleanup.sh -f        # Full cleanup (short form)"
echo ""
echo "🚀 To restart the demo: ./demo.sh" 