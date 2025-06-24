#!/bin/bash

echo "🧹 Starting cleanup process..."

# Function to find and kill data generator processes
cleanup_data_generator() {
    echo "📈 Stopping data generator processes..."
    
    # Find Python processes running data_generator.py
    PIDS=$(ps aux | grep "data_generator.py" | grep -v grep | awk '{print $2}')
    
    if [ ! -z "$PIDS" ]; then
        echo "Found data generator processes: $PIDS"
        for PID in $PIDS; do
            echo "Killing process $PID..."
            kill $PID 2>/dev/null || true
        done
        
        # Wait a moment and force kill if still running
        sleep 2
        PIDS=$(ps aux | grep "data_generator.py" | grep -v grep | awk '{print $2}')
        if [ ! -z "$PIDS" ]; then
            echo "Force killing remaining processes..."
            for PID in $PIDS; do
                kill -9 $PID 2>/dev/null || true
            done
        fi
    else
        echo "No data generator processes found."
    fi
}

# Function to stop Docker containers
cleanup_docker() {
    echo "🐳 Stopping Docker containers..."
    
    if [ -d "docker" ]; then
        cd docker
        docker-compose down --remove-orphans 2>/dev/null || true
        cd ..
    else
        echo "Docker directory not found."
    fi
}

# Function to clean up temporary files
cleanup_files() {
    echo "📁 Cleaning up temporary files..."
    
    # Remove copied files from docker directory
    if [ -d "docker" ]; then
        echo "Removing copied files from docker directory..."
        rm -f docker/requirements.txt 2>/dev/null || true
        rm -rf docker/src 2>/dev/null || true
        rm -rf docker/web 2>/dev/null || true
    fi
    
    # Remove any Python cache files
    echo "Removing Python cache files..."
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "*.pyo" -delete 2>/dev/null || true
    
    # Remove any log files
    echo "Removing log files..."
    find . -name "*.log" -delete 2>/dev/null || true
}

# Function to check if anything is still running
check_remaining_processes() {
    echo "🔍 Checking for remaining processes..."
    
    # Check for data generator processes
    REMAINING_PIDS=$(ps aux | grep "data_generator.py" | grep -v grep | awk '{print $2}')
    if [ ! -z "$REMAINING_PIDS" ]; then
        echo "⚠️  Warning: Data generator processes still running: $REMAINING_PIDS"
    else
        echo "✅ No data generator processes found."
    fi
    
    # Check for Docker containers
    if command -v docker >/dev/null 2>&1; then
        RUNNING_CONTAINERS=$(docker ps --filter "name=kafka-dashboard" --format "{{.Names}}" 2>/dev/null || true)
        if [ ! -z "$RUNNING_CONTAINERS" ]; then
            echo "⚠️  Warning: Docker containers still running:"
            echo "$RUNNING_CONTAINERS"
        else
            echo "✅ No Docker containers found."
        fi
    fi
}

# Main cleanup execution
echo "🚀 Starting comprehensive cleanup..."

# Stop data generator first
cleanup_data_generator

# Stop Docker containers
cleanup_docker

# Clean up files
cleanup_files

# Wait a moment for processes to fully stop
sleep 3

# Check for any remaining processes
check_remaining_processes

echo ""
echo "🎉 Cleanup completed!"
echo ""
echo "📋 Summary:"
echo "  ✅ Data generator processes stopped"
echo "  ✅ Docker containers stopped"
echo "  ✅ Temporary files cleaned up"
echo ""
echo "💡 To start fresh, run: ./run_demo.sh" 