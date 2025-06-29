#!/bin/bash

# Day 49: Anomaly Detection System - Cleanup Script
# This script stops all processes and cleans up the demonstration environment

echo "🧹 Day 49: Cleaning up Anomaly Detection System"
echo "=============================================="

# Kill any running Flask applications on port 5000
echo "🛑 Stopping web applications..."
lsof -ti:5000 | xargs kill -9 2>/dev/null || true

# Stop any Docker containers
echo "🐳 Stopping Docker containers..."
docker-compose down 2>/dev/null || true
docker stop $(docker ps -q --filter "ancestor=day49-anomaly-detection*") 2>/dev/null || true

# Remove Docker images
echo "🗑️  Removing Docker images..."
docker rmi $(docker images "day49-anomaly-detection*" -q) 2>/dev/null || true

# Clean up project directory
if [ -d "day49-anomaly-detection" ]; then
    echo "📁 Removing project directory..."
    rm -rf day49-anomaly-detection
    echo "✅ Project directory removed"
else
    echo "ℹ️  Project directory not found"
fi

# Clean up any leftover Python processes
echo "🐍 Cleaning up Python processes..."
pkill -f "anomaly_detector" 2>/dev/null || true
pkill -f "app.py" 2>/dev/null || true

# Clean up any log files in current directory
rm -f *.log 2>/dev/null || true
rm -f anomaly_*.json 2>/dev/null || true

# Remove any virtual environment if created in current directory
if [ -d "venv" ]; then
    echo "🗑️  Removing virtual environment..."
    rm -rf venv
fi

# Clean up pip cache
echo "🧹 Cleaning pip cache..."
pip cache purge 2>/dev/null || true

echo ""
echo "✅ Cleanup completed successfully!"
echo "📋 Summary:"
echo "   - Stopped all running processes"
echo "   - Removed Docker containers and images"
echo "   - Deleted project directory and files"
echo "   - Cleaned up temporary files"
echo ""
echo "🎯 Environment has been reset to original state"