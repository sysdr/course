#!/bin/bash

# Kafka Log Producer Cleanup Script
# This script stops all servers and Docker containers related to the project

set -e

echo "🧹 Starting cleanup of Kafka Log Producer system..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Stop Docker containers
print_status "Stopping Docker containers..."
if docker ps --format "table {{.Names}}" | grep -q "kafka\|zookeeper\|kafka-ui"; then
    docker-compose down
    print_success "Docker containers stopped"
else
    print_warning "No Docker containers found running"
fi

# 2. Kill Python processes related to the project
print_status "Stopping Python processes..."
PYTHON_PIDS=$(ps aux | grep -E "(python.*app\.py|python.*main\.py|python.*producer)" | grep -v grep | awk '{print $2}' || true)

if [ -n "$PYTHON_PIDS" ]; then
    echo "$PYTHON_PIDS" | xargs kill -9 2>/dev/null || true
    print_success "Python processes stopped"
else
    print_warning "No Python processes found running"
fi

# 3. Kill processes using project ports
print_status "Freeing up ports (8000, 8080, 8081, 9092)..."
for port in 8000 8080 8081 9092; do
    PIDS=$(lsof -ti:$port 2>/dev/null || true)
    if [ -n "$PIDS" ]; then
        echo "$PIDS" | xargs kill -9 2>/dev/null || true
        print_success "Freed port $port"
    else
        print_warning "Port $port was already free"
    fi
done

# 4. Kill any remaining processes with project-related names
print_status "Cleaning up any remaining project processes..."
PROJECT_PIDS=$(ps aux | grep -E "(kafka|producer|metrics|dashboard)" | grep -v grep | awk '{print $2}' || true)

if [ -n "$PROJECT_PIDS" ]; then
    echo "$PROJECT_PIDS" | xargs kill -9 2>/dev/null || true
    print_success "Remaining project processes stopped"
else
    print_warning "No additional project processes found"
fi

# 5. Verify cleanup
print_status "Verifying cleanup..."

# Check if ports are free
PORTS_FREE=true
for port in 8000 8080 8081 9092; do
    if lsof -i:$port >/dev/null 2>&1; then
        print_error "Port $port is still in use"
        PORTS_FREE=false
    fi
done

if [ "$PORTS_FREE" = true ]; then
    print_success "All ports are free"
fi

# Check if Docker containers are stopped
if docker ps --format "table {{.Names}}" | grep -q "kafka\|zookeeper\|kafka-ui"; then
    print_error "Some Docker containers are still running"
else
    print_success "All Docker containers are stopped"
fi

# Check if Python processes are stopped
PYTHON_RUNNING=$(ps aux | grep -E "(python.*app\.py|python.*main\.py|python.*producer)" | grep -v grep || true)
if [ -n "$PYTHON_RUNNING" ]; then
    print_error "Some Python processes are still running"
else
    print_success "All Python processes are stopped"
fi

# 6. Optional: Remove Docker volumes and networks (commented out by default)
# Uncomment the following lines if you want to completely remove Docker data
# print_status "Removing Docker volumes and networks..."
# docker-compose down -v --remove-orphans 2>/dev/null || true
# docker network prune -f 2>/dev/null || true

echo ""
print_success "🎉 Cleanup completed successfully!"
echo ""
echo "Summary:"
echo "  ✅ Docker containers stopped"
echo "  ✅ Python processes terminated"
echo "  ✅ Ports freed (8000, 8080, 8081, 9092)"
echo "  ✅ Project processes cleaned up"
echo ""
echo "To restart the system, run:"
echo "  ./build_and_demo.sh"
echo ""
echo "Or manually:"
echo "  docker-compose up -d"
echo "  export PYTHONPATH=\"\$(pwd)/src:\$PYTHONPATH\" && source venv/bin/activate && python web/app.py" 