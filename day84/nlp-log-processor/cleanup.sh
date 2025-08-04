#!/bin/bash

# NLP Log Processor Cleanup Script
# Usage: ./cleanup.sh [--basic|--full|--docker|--data|--python]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# Function to confirm action
confirm_action() {
    local message="$1"
    echo -e "${YELLOW}$message${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
}

# Function to cleanup data directories
cleanup_data() {
    print_info "Cleaning up data directories..."
    
    if [ -d "data/logs" ]; then
        rm -rf data/logs/*
        print_status "Cleared data/logs/"
    fi
    
    if [ -d "data/models" ]; then
        rm -rf data/models/*
        print_status "Cleared data/models/"
    fi
    
    if [ -d "data/sample_logs" ]; then
        rm -rf data/sample_logs/*
        print_status "Cleared data/sample_logs/"
    fi
    
    if [ -d "data/training" ]; then
        rm -rf data/training/*
        print_status "Cleared data/training/"
    fi
    
    # Keep .gitkeep files
    touch data/logs/.gitkeep 2>/dev/null || true
    touch data/models/.gitkeep 2>/dev/null || true
    touch data/sample_logs/.gitkeep 2>/dev/null || true
    touch data/training/.gitkeep 2>/dev/null || true
}

# Function to cleanup Python files
cleanup_python() {
    print_info "Cleaning up Python files..."
    
    # Remove __pycache__ directories
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    print_status "Removed __pycache__ directories"
    
    # Remove .pyc files
    find . -name "*.pyc" -delete 2>/dev/null || true
    print_status "Removed .pyc files"
    
    # Remove .pyo files
    find . -name "*.pyo" -delete 2>/dev/null || true
    print_status "Removed .pyo files"
    
    # Remove virtual environment
    if [ -d "venv" ]; then
        rm -rf venv/
        print_status "Removed virtual environment"
    fi
    
    # Remove coverage files
    rm -f .coverage coverage.xml htmlcov/ 2>/dev/null || true
    print_status "Removed coverage files"
    
    # Remove pytest cache
    rm -rf .pytest_cache/ 2>/dev/null || true
    print_status "Removed pytest cache"
}

# Function to cleanup Docker
cleanup_docker() {
    print_info "Cleaning up Docker resources..."
    
    # Stop containers if running
    if [ -f "docker-compose.yml" ]; then
        docker-compose down 2>/dev/null || true
        print_status "Stopped Docker containers"
    fi
    
    # Remove unused containers
    docker container prune -f 2>/dev/null || true
    print_status "Removed unused containers"
    
    # Remove unused images
    docker image prune -f 2>/dev/null || true
    print_status "Removed unused images"
    
    # Remove unused networks
    docker network prune -f 2>/dev/null || true
    print_status "Removed unused networks"
    
    # Remove unused volumes
    docker volume prune -f 2>/dev/null || true
    print_status "Removed unused volumes"
}

# Function to cleanup system files
cleanup_system() {
    print_info "Cleaning up system files..."
    
    # Remove temporary directories
    rm -rf tmp/ temp/ 2>/dev/null || true
    print_status "Removed temporary directories"
    
    # Remove log files
    find . -name "*.log" -delete 2>/dev/null || true
    print_status "Removed log files"
    
    # Remove PID files
    find . -name "*.pid" -delete 2>/dev/null || true
    print_status "Removed PID files"
    
    # Remove backup files
    find . -name "*.bak" -delete 2>/dev/null || true
    find . -name "*.backup" -delete 2>/dev/null || true
    print_status "Removed backup files"
    
    # Remove cache directories
    rm -rf .cache/ cache/ 2>/dev/null || true
    print_status "Removed cache directories"
}

# Function to full cleanup
full_cleanup() {
    print_warning "This will perform a FULL cleanup including Docker system prune!"
    confirm_action "This will remove ALL unused Docker resources, data, and cache files."
    
    cleanup_data
    cleanup_python
    cleanup_system
    
    # Full Docker cleanup
    print_info "Performing full Docker cleanup..."
    docker system prune -a -f 2>/dev/null || true
    print_status "Completed full Docker cleanup"
}

# Main script logic
echo "🧹 NLP Log Processor Cleanup Script"
echo "==================================="
echo ""

# Parse command line arguments
case "${1:---basic}" in
    --basic|--data)
        print_info "Performing basic cleanup (data directories only)..."
        cleanup_data
        ;;
    --python)
        print_info "Performing Python cleanup..."
        cleanup_python
        ;;
    --docker)
        print_info "Performing Docker cleanup..."
        cleanup_docker
        ;;
    --system)
        print_info "Performing system cleanup..."
        cleanup_system
        ;;
    --full)
        full_cleanup
        ;;
    --help|-h)
        echo "Usage: ./cleanup.sh [OPTION]"
        echo ""
        echo "Options:"
        echo "  --basic, --data    Clean up data directories only (default)"
        echo "  --python          Clean up Python cache and virtual environment"
        echo "  --docker          Clean up Docker resources"
        echo "  --system          Clean up system files (logs, temp, etc.)"
        echo "  --full            Full cleanup (everything + Docker system prune)"
        echo "  --help, -h        Show this help message"
        echo ""
        echo "Examples:"
        echo "  ./cleanup.sh              # Basic cleanup"
        echo "  ./cleanup.sh --python     # Python cleanup only"
        echo "  ./cleanup.sh --docker     # Docker cleanup only"
        echo "  ./cleanup.sh --full       # Full cleanup"
        exit 0
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

echo ""
print_status "Cleanup completed successfully!"
echo ""
echo "💡 Next steps:"
echo "  • Start the system: ./run_docker.sh"
echo "  • Check status: docker-compose ps"
echo "  • View logs: docker-compose logs -f" 