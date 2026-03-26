#!/bin/bash

# Day 60: Multi-Region Log Replication System - Start Script
# ===========================================================

set -e  # Exit on any error

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local host=$1
    local port=$2
    local service_name=$3
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z $host $port 2>/dev/null; then
            print_success "$service_name is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name failed to start within $((max_attempts * 2)) seconds"
    return 1
}

# Function to create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    mkdir -p logs
    mkdir -p data/regions/us-east-1
    mkdir -p data/regions/us-west-2
    mkdir -p data/regions/eu-west-1
    mkdir -p config/regions
    mkdir -p scripts/utils
    
    print_success "Directories created"
}

# Function to setup virtual environment
setup_venv() {
    print_status "Setting up Python virtual environment..."
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        print_success "Virtual environment created"
    else
        print_status "Virtual environment already exists"
    fi
    
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install dependencies
    print_status "Installing dependencies..."
    pip install -r requirements.txt
    
    print_success "Dependencies installed"
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    
    if [ -d "tests" ] && [ "$(ls -A tests 2>/dev/null)" ]; then
        python -m pytest tests/ -v
        print_success "Tests completed"
    else
        print_warning "No tests found, skipping test execution"
    fi
}

# Function to verify system requirements
verify_system() {
    print_status "Verifying system requirements..."
    
    # Check Python version
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    print_status "Python version: $python_version"
    
    # Check if required commands exist
    local required_commands=("python3" "pip" "redis-server" "docker")
    
    for cmd in "${required_commands[@]}"; do
        if command_exists "$cmd"; then
            print_success "$cmd is available"
        else
            print_warning "$cmd is not available (some features may not work)"
        fi
    done
    
    # Check available ports
    local required_ports=(8000 8001 8002 6379 5432)
    
    for port in "${required_ports[@]}"; do
        if check_port $port; then
            print_warning "Port $port is already in use"
        else
            print_success "Port $port is available"
        fi
    done
}

# Function to start Redis (if available)
start_redis() {
    if command_exists "redis-server"; then
        print_status "Starting Redis server..."
        
        if ! check_port 6379; then
            redis-server --daemonize yes --port 6379
            wait_for_service localhost 6379 "Redis"
        else
            print_status "Redis is already running on port 6379"
        fi
    else
        print_warning "Redis not found, skipping Redis startup"
    fi
}

# Function to start PostgreSQL (if available via Docker)
start_postgresql() {
    if command_exists "docker"; then
        print_status "Starting PostgreSQL via Docker..."
        
        if ! check_port 5432; then
            docker run -d \
                --name day60-postgres \
                -e POSTGRES_PASSWORD=password \
                -e POSTGRES_USER=day60 \
                -e POSTGRES_DB=log_replication \
                -p 5432:5432 \
                postgres:15
            
            wait_for_service localhost 5432 "PostgreSQL"
        else
            print_status "PostgreSQL is already running on port 5432"
        fi
    else
        print_warning "Docker not found, skipping PostgreSQL startup"
    fi
}

# Function to create basic application files if they don't exist
create_basic_app() {
    # The repository now contains real implementations under src/.
    # Keep this function as a no-op for backwards compatibility with the script flow.
    print_status "Application structure already present"
}

# Function to start the application
start_application() {
    print_status "Starting Multi-Region Log Replication System..."
    
    # Start single FastAPI app (simulates 3 regions in-process)
    if ! check_port 8000; then
        print_status "Starting API + dashboard on port 8000..."
        uvicorn src.web.app:app --host 0.0.0.0 --port 8000 >/dev/null 2>&1 &
        MAIN_PID=$!
        echo $MAIN_PID > .main.pid
        wait_for_service localhost 8000 "Application"
    else
        print_status "Application is already running on port 8000"
    fi
}

# Function to show usage instructions
show_instructions() {
    echo
    echo "🎉 Multi-Region Log Replication System is ready!"
    echo "================================================"
    echo
    echo "📋 Available endpoints:"
    echo "  • Dashboard:    http://localhost:8000"
    echo "  • Health Check: http://localhost:8000/api/health"
    echo "  • Write Log:    http://localhost:8000/api/logs"
    echo "  • API Docs:     http://localhost:8000/docs"
    echo
    echo "🚀 Quick Start:"
    echo "  1. View API documentation: open http://localhost:8000/docs"
    echo "  2. Run demo:              python demo.py"
    echo "  3. Check health:          curl http://localhost:8000/api/health"
    echo "  4. Add a log:             curl -X POST http://localhost:8000/api/logs \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"message\":\"Hello World\",\"level\":\"info\",\"service\":\"demo\"}'"
    echo
    echo "📊 Monitoring:"
    echo "  • View logs:              curl http://localhost:8000/api/logs"
    echo "  • WebSocket updates:      ws://localhost:8000/ws"
    echo
    echo "🛑 To stop the system:"
    echo "  ./stop.sh"
    echo
}

# Main execution
main() {
    echo "🌍 Day 60: Multi-Region Log Replication System"
    echo "=============================================="
    echo
    
    # Verify system requirements
    verify_system
    
    # Create directories
    create_directories
    
    # Setup virtual environment
    setup_venv
    
    # Run tests
    run_tests
    
    # Start Redis
    start_redis
    
    # Start PostgreSQL
    start_postgresql
    
    # Create basic application files
    create_basic_app
    
    # Start application
    start_application
    
    # Show instructions
    show_instructions
}

# Run main function
main "$@" 