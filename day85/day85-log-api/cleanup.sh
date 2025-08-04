#!/bin/bash

echo "🧹 Starting cleanup for Day 85 Log Platform API..."

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

# Stop running services
print_status "Stopping running services..."

# Stop backend API server
if [ -f "api.pid" ]; then
    API_PID=$(cat api.pid)
    if ps -p $API_PID > /dev/null 2>&1; then
        print_status "Stopping API server (PID: $API_PID)..."
        kill $API_PID
        sleep 2
        if ps -p $API_PID > /dev/null 2>&1; then
            print_warning "API server still running, force killing..."
            kill -9 $API_PID
        fi
        print_success "API server stopped"
    else
        print_warning "API server not running (PID file exists but process not found)"
    fi
    rm -f api.pid
else
    print_status "No API PID file found"
fi

# Stop frontend development server
FRONTEND_PID=$(lsof -ti:3000 2>/dev/null)
if [ ! -z "$FRONTEND_PID" ]; then
    print_status "Stopping frontend server (PID: $FRONTEND_PID)..."
    kill $FRONTEND_PID
    sleep 2
    if lsof -ti:3000 > /dev/null 2>&1; then
        print_warning "Frontend server still running, force killing..."
        kill -9 $FRONTEND_PID
    fi
    print_success "Frontend server stopped"
else
    print_status "No frontend server running on port 3000"
fi

# Stop any other uvicorn processes
UVICORN_PIDS=$(pgrep -f "uvicorn.*src.api.main:app" 2>/dev/null)
if [ ! -z "$UVICORN_PIDS" ]; then
    print_status "Stopping uvicorn processes..."
    echo $UVICORN_PIDS | xargs kill
    sleep 2
    UVICORN_PIDS=$(pgrep -f "uvicorn.*src.api.main:app" 2>/dev/null)
    if [ ! -z "$UVICORN_PIDS" ]; then
        print_warning "Force killing remaining uvicorn processes..."
        echo $UVICORN_PIDS | xargs kill -9
    fi
    print_success "Uvicorn processes stopped"
fi

# Stop any React development servers
REACT_PIDS=$(pgrep -f "react-scripts start" 2>/dev/null)
if [ ! -z "$REACT_PIDS" ]; then
    print_status "Stopping React development servers..."
    echo $REACT_PIDS | xargs kill
    sleep 2
    REACT_PIDS=$(pgrep -f "react-scripts start" 2>/dev/null)
    if [ ! -z "$REACT_PIDS" ]; then
        print_warning "Force killing remaining React processes..."
        echo $REACT_PIDS | xargs kill -9
    fi
    print_success "React development servers stopped"
fi

# Clean up temporary files
print_status "Cleaning up temporary files..."

# Remove database files
if [ -f "logs.db" ]; then
    print_status "Removing logs.db..."
    rm -f logs.db
    print_success "logs.db removed"
fi

if [ -f "test.db" ]; then
    print_status "Removing test.db..."
    rm -f test.db
    print_success "test.db removed"
fi

# Remove PID files
rm -f *.pid

# Clean up Python cache
print_status "Cleaning up Python cache..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find . -type f -name "*.pyc" -delete 2>/dev/null
find . -type f -name "*.pyo" -delete 2>/dev/null
print_success "Python cache cleaned"

# Clean up pytest cache
if [ -d ".pytest_cache" ]; then
    print_status "Removing pytest cache..."
    rm -rf .pytest_cache
    print_success "pytest cache removed"
fi

# Clean up frontend build artifacts
if [ -d "frontend/build" ]; then
    print_status "Removing frontend build directory..."
    rm -rf frontend/build
    print_success "frontend build directory removed"
fi

if [ -d "frontend/node_modules" ]; then
    print_warning "Removing frontend node_modules (this may take a while)..."
    rm -rf frontend/node_modules
    print_success "frontend node_modules removed"
fi

# Clean up any temporary test databases
find . -name "test_*.db" -delete 2>/dev/null
find . -name "*test*.db" -delete 2>/dev/null

# Clean up Docker artifacts (if using Docker)
if command -v docker >/dev/null 2>&1; then
    print_status "Cleaning up Docker artifacts..."
    
    # Stop and remove containers
    docker ps -a --filter "name=day85" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null
    
    # Remove images
    docker images --filter "reference=day85*" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null
    
    # Remove volumes
    docker volume ls --filter "name=day85" --format "{{.Name}}" | xargs -r docker volume rm 2>/dev/null
    
    print_success "Docker artifacts cleaned"
fi

# Check for any remaining processes on project ports
print_status "Checking for remaining processes on project ports..."

if lsof -ti:8000 > /dev/null 2>&1; then
    print_warning "Process still running on port 8000:"
    lsof -ti:8000 | xargs ps -p
fi

if lsof -ti:3000 > /dev/null 2>&1; then
    print_warning "Process still running on port 3000:"
    lsof -ti:3000 | xargs ps -p
fi

# Clean up environment
print_status "Cleaning up environment..."

# Deactivate virtual environment if active
if [ ! -z "$VIRTUAL_ENV" ]; then
    print_status "Deactivating virtual environment..."
    deactivate 2>/dev/null || true
    print_success "Virtual environment deactivated"
fi

# Reset environment variables
unset REACT_APP_API_URL 2>/dev/null || true

print_success "Cleanup completed successfully!"
echo ""
echo "📋 Summary of cleanup:"
echo "   ✅ Stopped API server"
echo "   ✅ Stopped frontend server"
echo "   ✅ Removed database files"
echo "   ✅ Cleaned Python cache"
echo "   ✅ Cleaned pytest cache"
echo "   ✅ Removed frontend build artifacts"
echo "   ✅ Cleaned Docker artifacts (if applicable)"
echo ""
echo "🔄 To restart the application:"
echo "   ./start.sh"
echo ""
echo "📚 To start only the backend:"
echo "   source venv/bin/activate && python -m uvicorn src.api.main:app --host 0.0.0.0 --port 8000 --reload"
echo ""
echo "🎨 To start only the frontend:"
echo "   cd frontend && npm install && npm start" 