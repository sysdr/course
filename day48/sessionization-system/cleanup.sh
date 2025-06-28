#!/bin/bash

# Sessionization System Cleanup Script
# This script stops all services and cleans up resources

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

# Function to stop Docker containers
stop_containers() {
    print_status "Stopping Docker containers..."
    
    if command_exists "docker-compose"; then
        # Stop containers gracefully
        docker-compose down --remove-orphans 2>/dev/null || true
        
        # Force stop any remaining containers
        docker-compose down --volumes --remove-orphans 2>/dev/null || true
        
        print_success "Docker containers stopped"
    else
        print_warning "Docker Compose not found, trying Docker directly..."
        
        # Stop containers by name pattern
        docker stop $(docker ps -q --filter "name=sessionization") 2>/dev/null || true
        docker rm $(docker ps -aq --filter "name=sessionization") 2>/dev/null || true
        
        print_success "Docker containers stopped"
    fi
}

# Function to remove Docker volumes
remove_volumes() {
    print_status "Removing Docker volumes..."
    
    # Remove volumes associated with the project
    docker volume rm $(docker volume ls -q --filter "name=sessionization") 2>/dev/null || true
    docker volume rm $(docker volume ls -q --filter "name=redis_data") 2>/dev/null || true
    
    # Remove any dangling volumes
    docker volume prune -f 2>/dev/null || true
    
    print_success "Docker volumes removed"
}

# Function to remove Docker images
remove_images() {
    print_status "Removing Docker images..."
    
    # Remove images associated with the project
    docker rmi $(docker images -q --filter "reference=sessionization*") 2>/dev/null || true
    
    # Remove any dangling images
    docker image prune -f 2>/dev/null || true
    
    print_success "Docker images removed"
}

# Function to clean up temporary files
cleanup_temp_files() {
    print_status "Cleaning up temporary files..."
    
    # Remove Python cache files
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "*.pyo" -delete 2>/dev/null || true
    
    # Remove test cache
    find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
    find . -type d -name ".coverage" -delete 2>/dev/null || true
    
    # Remove log files
    rm -rf logs/* 2>/dev/null || true
    
    # Remove temporary simulation files
    rm -f simulate_events.py 2>/dev/null || true
    
    # Remove any .DS_Store files (macOS)
    find . -name ".DS_Store" -delete 2>/dev/null || true
    
    print_success "Temporary files cleaned up"
}

# Function to deactivate virtual environment
deactivate_venv() {
    print_status "Deactivating virtual environment..."
    
    if [ -n "$VIRTUAL_ENV" ]; then
        deactivate 2>/dev/null || true
        print_success "Virtual environment deactivated"
    else
        print_status "No virtual environment to deactivate"
    fi
}

# Function to remove virtual environment
remove_venv() {
    print_status "Removing virtual environment..."
    
    if [ -d "venv" ]; then
        rm -rf venv
        print_success "Virtual environment removed"
    else
        print_status "No virtual environment to remove"
    fi
}

# Function to kill any remaining processes
kill_processes() {
    print_status "Checking for remaining processes..."
    
    # Kill any processes using the ports
    local ports=(8000 6379)
    
    for port in "${ports[@]}"; do
        local pids=$(lsof -ti:$port 2>/dev/null || true)
        if [ -n "$pids" ]; then
            print_warning "Killing processes using port $port: $pids"
            echo "$pids" | xargs kill -9 2>/dev/null || true
        fi
    done
    
    print_success "Process cleanup completed"
}

# Function to stop other servers and services
stop_other_servers() {
    print_status "Stopping other servers and services..."
    
    # Common server processes that might be running
    local server_processes=(
        "uvicorn"
        "gunicorn"
        "flask"
        "django"
        "fastapi"
        "redis-server"
        "redis"
        "node"
        "npm"
        "yarn"
        "python"
        "python3"
    )
    
    # Stop processes by name
    for process in "${server_processes[@]}"; do
        local pids=$(pgrep -f "$process.*sessionization\|$process.*8000\|$process.*6379" 2>/dev/null || true)
        if [ -n "$pids" ]; then
            print_warning "Stopping $process processes: $pids"
            echo "$pids" | xargs kill -TERM 2>/dev/null || true
            sleep 2
            # Force kill if still running
            echo "$pids" | xargs kill -9 2>/dev/null || true
        fi
    done
    
    # Stop any Python processes that might be running the app
    local python_pids=$(pgrep -f "python.*main\|python.*app\|python.*sessionization" 2>/dev/null || true)
    if [ -n "$python_pids" ]; then
        print_warning "Stopping Python application processes: $python_pids"
        echo "$python_pids" | xargs kill -TERM 2>/dev/null || true
        sleep 2
        echo "$python_pids" | xargs kill -9 2>/dev/null || true
    fi
    
    # Stop any background jobs
    jobs -p | xargs kill -TERM 2>/dev/null || true
    
    print_success "Other servers stopped"
}

# Function to stop system services (if running as systemd)
stop_system_services() {
    print_status "Checking for system services..."
    
    # Check if running as systemd service
    if command_exists "systemctl"; then
        local services=(
            "sessionization"
            "sessionization-app"
            "sessionization-system"
        )
        
        for service in "${services[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                print_warning "Stopping system service: $service"
                systemctl stop "$service" 2>/dev/null || true
                systemctl disable "$service" 2>/dev/null || true
            fi
        done
    fi
    
    print_success "System services checked"
}

# Function to stop Docker services more thoroughly
stop_docker_services() {
    print_status "Stopping Docker services thoroughly..."
    
    if command_exists "docker"; then
        # Stop all containers that might be related
        local containers=$(docker ps -q --filter "name=sessionization" 2>/dev/null || true)
        if [ -n "$containers" ]; then
            print_warning "Stopping sessionization containers: $containers"
            docker stop $containers 2>/dev/null || true
            docker rm $containers 2>/dev/null || true
        fi
        
        # Stop containers by image name
        local image_containers=$(docker ps -q --filter "ancestor=sessionization*" 2>/dev/null || true)
        if [ -n "$image_containers" ]; then
            print_warning "Stopping containers by image: $image_containers"
            docker stop $image_containers 2>/dev/null || true
            docker rm $image_containers 2>/dev/null || true
        fi
        
        # Stop any containers using the ports
        for port in 8000 6379; do
            local port_containers=$(docker ps -q --filter "publish=$port" 2>/dev/null || true)
            if [ -n "$port_containers" ]; then
                print_warning "Stopping containers using port $port: $port_containers"
                docker stop $port_containers 2>/dev/null || true
                docker rm $port_containers 2>/dev/null || true
            fi
        done
    fi
    
    print_success "Docker services stopped"
}

# Function to clean up network resources
cleanup_network() {
    print_status "Cleaning up network resources..."
    
    if command_exists "docker"; then
        # Remove unused networks
        docker network prune -f 2>/dev/null || true
        
        # Remove specific networks if they exist
        docker network rm sessionization_default 2>/dev/null || true
        docker network rm sessionization-system_default 2>/dev/null || true
    fi
    
    print_success "Network cleanup completed"
}

# Function to show cleanup summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "  🧹 Cleanup Summary"
    echo "=========================================="
    echo ""
    
    # Check if containers are still running
    if command_exists "docker"; then
        local running_containers=$(docker ps -q --filter "name=sessionization" 2>/dev/null || true)
        if [ -n "$running_containers" ]; then
            print_warning "Some containers are still running:"
            docker ps --filter "name=sessionization"
        else
            print_success "✓ All containers stopped"
        fi
        
        # Check for any containers using our ports
        for port in 8000 6379; do
            local port_containers=$(docker ps -q --filter "publish=$port" 2>/dev/null || true)
            if [ -n "$port_containers" ]; then
                print_warning "⚠️  Containers still using port $port:"
                docker ps --filter "publish=$port"
            else
                print_success "✓ Port $port is free"
            fi
        done
    fi
    
    # Check if ports are still in use by any process
    local ports=(8000 6379)
    for port in "${ports[@]}"; do
        if lsof -i:$port >/dev/null 2>&1; then
            print_warning "⚠️  Port $port is still in use by:"
            lsof -i:$port
        else
            print_success "✓ Port $port is free"
        fi
    done
    
    # Check for remaining processes
    local remaining_processes=$(pgrep -f "sessionization\|uvicorn.*8000\|redis.*6379" 2>/dev/null || true)
    if [ -n "$remaining_processes" ]; then
        print_warning "⚠️  Some processes are still running:"
        ps aux | grep -E "sessionization|uvicorn.*8000|redis.*6379" | grep -v grep || true
    else
        print_success "✓ All processes stopped"
    fi
    
    echo ""
    print_success "🎉 Cleanup completed successfully!"
    echo ""
    print_status "To start the demo again, run: ./demo.sh"
}

# Main cleanup workflow
main() {
    echo "=========================================="
    echo "  🧹 Sessionization System Cleanup"
    echo "=========================================="
    echo ""
    
    # Step 1: Deactivate virtual environment
    deactivate_venv
    
    # Step 2: Stop system services
    stop_system_services
    
    # Step 3: Stop other servers
    stop_other_servers
    
    # Step 4: Stop Docker services thoroughly
    stop_docker_services
    
    # Step 5: Stop containers
    stop_containers
    
    # Step 6: Remove volumes
    remove_volumes
    
    # Step 7: Clean up network resources
    cleanup_network
    
    # Step 8: Remove images (optional - uncomment if you want to remove images too)
    # remove_images
    
    # Step 9: Kill any remaining processes
    kill_processes
    
    # Step 10: Clean up temporary files
    cleanup_temp_files
    
    # Step 11: Show summary
    show_summary
}

# Handle Ctrl+C gracefully
trap 'echo ""; print_warning "Cleanup interrupted."; exit 1' INT

# Run the main function
main 