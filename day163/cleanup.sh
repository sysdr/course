#!/bin/bash

# Cleanup script for Day 163 project
# Removes node_modules, venv, cache files, and cleans Docker resources

set -e

echo "========================================="
echo "Day 163 Project Cleanup"
echo "========================================="

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo ""
echo "Step 1: Stopping all services..."
# Stop application services
if [ -f "$PROJECT_ROOT/dependency-mapper/stop.sh" ]; then
    bash "$PROJECT_ROOT/dependency-mapper/stop.sh" 2>/dev/null || true
fi

# Kill any remaining processes
pkill -f "http_server.py" 2>/dev/null || true
pkill -f "backend/server.py" 2>/dev/null || true
pkill -f "http.server" 2>/dev/null || true
pkill -f "server.py" 2>/dev/null || true
sleep 2
echo "✓ Services stopped"

echo ""
echo "Step 2: Stopping Docker containers..."
# Stop all Docker containers
docker stop $(docker ps -q) 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
echo "✓ Docker containers stopped"

echo ""
echo "Step 3: Removing Docker resources..."
# Remove stopped containers
docker container prune -f 2>/dev/null || true

# Remove unused images
docker image prune -a -f 2>/dev/null || true

# Remove unused volumes
docker volume prune -f 2>/dev/null || true

# Remove unused networks
docker network prune -f 2>/dev/null || true

# System prune (removes all unused data)
docker system prune -a -f 2>/dev/null || true
echo "✓ Docker resources cleaned"

echo ""
echo "Step 4: Removing Python cache files..."
# Remove __pycache__ directories
find "$PROJECT_ROOT" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# Remove .pyc, .pyo, .pyd files
find "$PROJECT_ROOT" -type f -name "*.pyc" -delete 2>/dev/null || true
find "$PROJECT_ROOT" -type f -name "*.pyo" -delete 2>/dev/null || true
find "$PROJECT_ROOT" -type f -name "*.pyd" -delete 2>/dev/null || true
echo "✓ Python cache files removed"

echo ""
echo "Step 5: Removing virtual environments..."
# Remove .venv and venv directories
if [ -d "$PROJECT_ROOT/dependency-mapper/.venv" ]; then
    rm -rf "$PROJECT_ROOT/dependency-mapper/.venv"
    echo "✓ Removed dependency-mapper/.venv"
fi

find "$PROJECT_ROOT" -type d -name ".venv" -exec rm -rf {} + 2>/dev/null || true
find "$PROJECT_ROOT" -type d -name "venv" -exec rm -rf {} + 2>/dev/null || true
echo "✓ Virtual environments removed"

echo ""
echo "Step 6: Removing node_modules..."
# Remove node_modules directories
find "$PROJECT_ROOT" -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true
echo "✓ node_modules removed"

echo ""
echo "Step 7: Removing pytest cache..."
# Remove .pytest_cache directories
find "$PROJECT_ROOT" -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
echo "✓ pytest cache removed"

echo ""
echo "Step 8: Removing Istio files..."
# Remove Istio-related files and directories
find "$PROJECT_ROOT" -type f -name "*istio*" -delete 2>/dev/null || true
find "$PROJECT_ROOT" -type d -name "*istio*" -exec rm -rf {} + 2>/dev/null || true
echo "✓ Istio files removed"

echo ""
echo "Step 9: Removing temporary files..."
# Remove .pid files
find "$PROJECT_ROOT" -type f -name "*.pid" -delete 2>/dev/null || true

# Remove .log files in logs directory (keep sample.log)
if [ -d "$PROJECT_ROOT/dependency-mapper/logs" ]; then
    find "$PROJECT_ROOT/dependency-mapper/logs" -type f -name "*.log" ! -name "sample.log" -delete 2>/dev/null || true
fi
echo "✓ Temporary files removed"

echo ""
echo "========================================="
echo "✓ Cleanup completed successfully!"
echo "========================================="
echo ""
echo "Removed:"
echo "  • Python cache files (__pycache__, *.pyc)"
echo "  • Virtual environments (.venv, venv)"
echo "  • node_modules directories"
echo "  • pytest cache (.pytest_cache)"
echo "  • Istio files"
echo "  • Docker unused resources"
echo "  • Temporary files"
echo ""
