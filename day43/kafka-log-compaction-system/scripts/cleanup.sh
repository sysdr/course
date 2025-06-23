#!/bin/bash

echo "🧹 Cleaning up project..."

# Function to stop processes by name
stop_processes() {
    echo "Stopping running processes..."
    
    # Stop Python processes related to this project
    pkill -f "src.main" 2>/dev/null || true
    pkill -f "uvicorn.*dashboard_app" 2>/dev/null || true
    pkill -f "python.*main.py" 2>/dev/null || true
    
    # Stop any processes on our ports
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
    lsof -ti:8081 | xargs kill -9 2>/dev/null || true
}

# Function to stop Docker containers
stop_docker() {
    echo "Stopping Docker containers..."
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # Remove any dangling containers
    docker ps -a --filter "name=kafka-log-compaction" -q | xargs docker rm -f 2>/dev/null || true
}

# Function to clean Python artifacts
clean_python() {
    echo "Cleaning Python artifacts..."
    
    # Remove Python cache files
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "*.pyo" -delete 2>/dev/null || true
    
    # Remove pytest cache
    rm -rf .pytest_cache 2>/dev/null || true
    
    # Remove coverage reports
    rm -rf htmlcov 2>/dev/null || true
    rm -f .coverage 2>/dev/null || true
}

# Function to remove virtual environment
clean_venv() {
    echo "Removing virtual environment..."
    if [ -d "venv" ]; then
        rm -rf venv
    fi
}

# Function to clean generated files
clean_generated() {
    echo "Cleaning generated files..."
    
    # Clean logs and data (but keep directories)
    rm -rf logs/* 2>/dev/null || true
    rm -rf data/* 2>/dev/null || true
    
    # Remove any temporary files
    find . -name "*.tmp" -delete 2>/dev/null || true
    find . -name "*.log" -delete 2>/dev/null || true
}

# Main cleanup logic
case "${1:-}" in
    --all)
        stop_processes
        stop_docker
        clean_python
        clean_venv
        clean_generated
        ;;
    --docker)
        stop_docker
        ;;
    --python)
        stop_processes
        clean_python
        clean_venv
        ;;
    --logs)
        clean_generated
        ;;
    *)
        echo "Usage: $0 [--all|--docker|--python|--logs]"
        echo "  --all     Clean everything (default)"
        echo "  --docker  Stop Docker containers only"
        echo "  --python  Clean Python artifacts only"
        echo "  --logs    Clean logs and generated files only"
        exit 1
        ;;
esac

echo "✅ Cleanup completed!"
echo "💡 Run './scripts/build.sh' to recreate environment"
