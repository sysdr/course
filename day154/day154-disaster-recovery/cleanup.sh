#!/bin/bash

echo "🧹 Starting comprehensive cleanup..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Stop all services first
echo ""
echo "=========================================="
echo "Stopping all services..."
echo "=========================================="

# Stop backend services
echo "Stopping backend API..."
pkill -f "uvicorn src.api.main:app" 2>/dev/null || echo "No backend API running"

# Stop frontend services
echo "Stopping frontend..."
pkill -f "react-scripts start" 2>/dev/null || echo "No frontend running"

# Stop docker-compose services
echo "Stopping docker-compose services..."
docker-compose down 2>/dev/null || echo "No docker-compose services running"

# Stop all running containers
echo "Stopping all running Docker containers..."
docker stop $(docker ps -aq) 2>/dev/null || echo "No containers to stop"

# Remove all stopped containers
echo "Removing stopped containers..."
docker rm $(docker ps -aq) 2>/dev/null || echo "No containers to remove"

# Remove all unused images
echo "Removing unused Docker images..."
docker image prune -a -f 2>/dev/null || echo "No unused images to remove"

# Remove all unused volumes
echo "Removing unused Docker volumes..."
docker volume prune -f 2>/dev/null || echo "No unused volumes to remove"

# Remove all unused networks
echo "Removing unused Docker networks..."
docker network prune -f 2>/dev/null || echo "No unused networks to remove"

# Remove all unused build cache
echo "Removing unused Docker build cache..."
docker builder prune -a -f 2>/dev/null || echo "No build cache to remove"

# System prune (removes all unused containers, networks, images, and build cache)
echo "Running system-wide Docker cleanup..."
docker system prune -a -f --volumes 2>/dev/null || echo "Docker system prune completed"

echo ""
echo "=========================================="
echo "Removing project files..."
echo "=========================================="

# Remove node_modules
if [ -d "web/node_modules" ]; then
    echo "Removing node_modules..."
    chown -R $(whoami):$(whoami) web/node_modules 2>/dev/null || true
    if rm -rf web/node_modules 2>/dev/null; then
        echo "✅ node_modules removed"
    else
        echo "⚠️  Attempting with sudo..."
        sudo rm -rf web/node_modules 2>/dev/null && echo "✅ node_modules removed with sudo" || echo "⚠️  Could not remove node_modules"
    fi
else
    echo "✅ node_modules not found"
fi

# Remove virtual environments
echo "Removing virtual environments..."
for venv_dir in venv .venv env ENV; do
    if [ -d "$venv_dir" ]; then
        rm -rf "$venv_dir" 2>/dev/null && echo "✅ $venv_dir removed" || echo "⚠️  Could not remove $venv_dir"
    fi
done

# Remove .pytest_cache directories
echo "Removing .pytest_cache directories..."
find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null && echo "✅ .pytest_cache removed" || echo "✅ No .pytest_cache found"

# Remove __pycache__ directories
echo "Removing __pycache__ directories..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null && echo "✅ __pycache__ removed" || echo "✅ No __pycache__ found"

# Remove .pyc and .pyo files
echo "Removing .pyc and .pyo files..."
find . -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null && echo "✅ .pyc/.pyo files removed" || echo "✅ No .pyc/.pyo files found"

# Remove Istio files
echo "Removing Istio files..."
find . -type f -name "*istio*" -delete 2>/dev/null || true
find . -type d -name "istio" -exec rm -rf {} + 2>/dev/null || true
echo "✅ Istio files removed (if any)"

echo ""
echo "=========================================="
echo "✅ Cleanup completed!"
echo "=========================================="
echo ""
echo "Docker system summary:"
docker system df 2>/dev/null || echo "Docker system info unavailable"
echo ""