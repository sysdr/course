#!/bin/bash

# Day 45: MapReduce Framework - Cleanup Script
# Stops all processes and cleans environment

set +e  # Don't exit on errors during cleanup

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}🔹 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "🧹 MapReduce Framework - Cleanup"
echo "================================"

# Step 1: Stop running processes
print_step "Stopping MapReduce processes..."

# Kill processes by name
pkill -f "python.*src.main" 2>/dev/null || true
pkill -f "python.*src.web.app" 2>/dev/null || true
pkill -f "uvicorn.*src.web.app" 2>/dev/null || true

# Kill processes using port 8080
PORT_PROCS=$(lsof -ti:8080 2>/dev/null || true)
if [ ! -z "$PORT_PROCS" ]; then
    kill -9 $PORT_PROCS 2>/dev/null || true
    print_success "Stopped processes on port 8080"
fi

# Additional cleanup for any remaining Python processes
ps aux | grep "python.*mapreduce" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null || true

print_success "MapReduce processes stopped"

# Step 2: Clean generated data
print_step "Cleaning generated data..."

# Remove output data
if [ -d "data/output" ]; then
    rm -rf data/output/*
    print_success "Cleaned output data"
fi

# Remove intermediate files
if [ -d "data/output/intermediate" ]; then
    rm -rf data/output/intermediate
    print_success "Cleaned intermediate files"
fi

# Remove generated input data (optional - keep sample data by default)
read -p "Remove generated sample data? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "data/input" ]; then
        rm -rf data/input/*
        print_success "Cleaned input data"
    fi
else
    print_success "Kept sample data for future use"
fi

# Step 3: Clean logs
print_step "Cleaning log files..."

if [ -d "logs" ]; then
    rm -f logs/*.log
    rm -f logs/*.log.*
    print_success "Cleaned log files"
fi

# Step 4: Clean temporary files
print_step "Cleaning temporary files..."

# Remove Python cache
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
find . -type f -name "*.pyo" -delete 2>/dev/null || true

# Remove test artifacts
rm -rf .pytest_cache 2>/dev/null || true
rm -f .coverage 2>/dev/null || true
rm -rf htmlcov 2>/dev/null || true

print_success "Cleaned temporary files"

# Step 5: Virtual environment cleanup (optional)
read -p "Remove virtual environment? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "venv" ]; then
        rm -rf venv
        print_success "Removed virtual environment"
    fi
else
    print_success "Kept virtual environment"
fi

# Step 6: Docker cleanup (if applicable)
print_step "Cleaning Docker containers..."

if command -v docker &> /dev/null; then
    # Stop and remove containers
    docker ps -q --filter "ancestor=day45*" | xargs docker stop 2>/dev/null || true
    docker ps -aq --filter "ancestor=day45*" | xargs docker rm 2>/dev/null || true
    
    # Remove images (optional)
    read -p "Remove Docker images? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker images -q "day45*" | xargs docker rmi 2>/dev/null || true
        print_success "Removed Docker images"
    fi
    
    print_success "Docker cleanup completed"
else
    print_warning "Docker not found, skipping Docker cleanup"
fi

# Step 7: Verification
print_step "Verifying cleanup..."

# Check for running processes
REMAINING_PROCS=$(ps aux | grep "python.*mapreduce\|uvicorn.*src.web" | grep -v grep | wc -l)
if [ $REMAINING_PROCS -eq 0 ]; then
    print_success "No MapReduce processes running"
else
    print_warning "$REMAINING_PROCS MapReduce processes still running"
fi

# Check port availability
if ! lsof -i:8080 > /dev/null 2>&1; then
    print_success "Port 8080 is available"
else
    print_warning "Port 8080 still in use"
fi

# Check disk space freed
if [ -d "data/output" ]; then
    OUTPUT_SIZE=$(du -sh data/output 2>/dev/null | cut -f1 || echo "0K")
    echo "📁 Remaining output data: $OUTPUT_SIZE"
fi

echo ""
echo "🎯 Cleanup Summary:"
echo "=================="
echo "✅ Stopped all MapReduce processes"
echo "✅ Cleaned output and intermediate files"
echo "✅ Removed log files and temporary data"
echo "✅ Cleaned Python cache and test artifacts"
echo "✅ Port 8080 freed for future use"

echo ""
echo "📋 What was preserved:"
echo "===================="
echo "📁 Source code (src/)"
echo "📁 Test suite (tests/)"
echo "📁 Configuration files (config/)"
echo "📁 Documentation and scripts"
if [ -d "venv" ]; then
    echo "🐍 Virtual environment (venv/)"
fi
if [ -d "data/input" ] && [ "$(ls -A data/input 2>/dev/null)" ]; then
    echo "📊 Sample input data (data/input/)"
fi

echo ""
print_success "Cleanup completed successfully!"
echo ""
echo "🔄 To restart the demo: ./demo.sh"
echo "🛠️  To rebuild from scratch: ./build_and_test.sh"