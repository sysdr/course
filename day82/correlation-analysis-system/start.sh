#!/bin/bash

# Function to cleanup on exit
cleanup() {
    local exit_code=$?
    echo "🧹 Cleaning up..."
    
    # Kill backend if running
    if [ -n "$BACKEND_PID" ]; then
        kill -9 $BACKEND_PID 2>/dev/null || true
        rm -f .backend.pid
    fi
    
    # Kill frontend if running
    if [ -n "$FRONTEND_PID" ]; then
        kill -9 $FRONTEND_PID 2>/dev/null || true
        rm -f .frontend.pid
    fi
    
    # Remove log files
    rm -f backend.log frontend.log
    
    exit $exit_code
}

# Set up trap for cleanup on script exit
trap cleanup EXIT INT TERM

# Initialize PIDs as empty
BACKEND_PID=""
FRONTEND_PID=""

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -i :$port > /dev/null; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to cleanup existing processes
cleanup_existing() {
    echo "🧹 Cleaning up existing processes..."
    
    # Kill any existing processes on ports 3000 and 8000
    if check_port 3000; then
        echo "Stopping process on port 3000..."
        lsof -ti:3000 | xargs kill -9 2>/dev/null || true
    fi
    
    if check_port 8000; then
        echo "Stopping process on port 8000..."
        lsof -ti:8000 | xargs kill -9 2>/dev/null || true
    fi
    
    # Kill any existing processes from previous runs
    if [ -f .backend.pid ]; then
        kill -9 $(cat .backend.pid) 2>/dev/null || true
        rm .backend.pid
    fi
    
    if [ -f .frontend.pid ]; then
        kill -9 $(cat .frontend.pid) 2>/dev/null || true
        rm .frontend.pid
    fi
    
    # Remove any temporary files
    rm -f backend.log
    
    echo "✅ Cleanup complete"
}

echo "🚀 Starting Correlation Analysis System"
echo "====================================="

# Clean up any existing processes
cleanup_existing

# Check if Python 3.11 is installed
if ! command -v python3.11 &> /dev/null; then
    echo "❌ Python 3.11 is not installed"
    echo "🔧 Installing Python 3.11 using Homebrew..."
    brew install python@3.11
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install Python 3.11"
        exit 1
    fi
fi

echo "🐍 Setting up Python 3.11 environment..."

# Create virtual environment with Python 3.11
python3.11 -m venv venv
if [ $? -ne 0 ]; then
    echo "❌ Failed to create virtual environment"
    exit 1
fi

# Activate virtual environment
source venv/bin/activate
if [ $? -ne 0 ]; then
    echo "❌ Failed to activate virtual environment"
    exit 1
fi

# Upgrade pip to latest version
echo "⬆️  Upgrading pip..."
python -m pip install --upgrade pip

# Install wheel and setuptools first
echo "📦 Installing build dependencies..."
pip install --upgrade wheel setuptools

# Backend dependencies
echo "📝 Creating requirements.txt..."
cat > backend/requirements.txt << 'EOF'
fastapi==0.110.3
uvicorn==0.29.0
pandas==2.2.2
numpy==1.26.4
scipy==1.11.4
scikit-learn==1.4.2
redis==5.0.4
aiofiles==23.2.1
aioredis==2.0.1
pytest==8.2.1
pytest-asyncio==0.23.7
websockets==12.0
pydantic==2.7.1
matplotlib==3.8.4
seaborn==0.13.2
plotly==5.20.0
structlog==24.1.0
asyncio-mqtt==0.16.1
python-multipart==0.0.9
jinja2==3.1.4
httpx==0.27.0
EOF

# Install each dependency individually with error checking
echo "📦 Installing Python packages..."
while IFS= read -r package || [[ -n "$package" ]]; do
    # Skip empty lines and comments
    if [[ -z "$package" ]] || [[ "$package" =~ ^#.* ]]; then
        continue
    fi
    
    echo "Installing $package..."
    pip install "$package"
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install $package"
        exit 1
    fi
done < backend/requirements.txt

echo "✅ Python environment ready"


# Install frontend dependencies
echo "🎨 Installing frontend dependencies..."
cd frontend

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found in frontend directory"
    exit 1
fi

# Install Node.js dependencies
echo "📦 Installing Node.js packages..."
npm install --force
if [ $? -ne 0 ]; then
    echo "❌ Failed to install frontend dependencies"
    exit 1
fi
cd ..

# Check if Redis is running
echo "🔍 Checking Redis server..."
if ! command -v redis-cli &> /dev/null; then
    echo "❌ Redis is not installed. Installing Redis..."
    brew install redis
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install Redis"
        exit 1
    fi
fi

# Start Redis if not running
if ! redis-cli ping &> /dev/null; then
    echo "🚀 Starting Redis server..."
    brew services start redis
    if [ $? -ne 0 ]; then
        echo "❌ Failed to start Redis"
        exit 1
    fi
    sleep 2
fi

# Function to wait for port to be available
wait_for_port() {
    local port=$1
    local service=$2
    local retries=10
    local wait=2
    
    echo "⏳ Waiting for port $port to be available..."
    while check_port $port && [ $retries -gt 0 ]; do
        echo "Port $port is still in use by another process. Waiting..."
        sleep $wait
        retries=$((retries - 1))
    done
    
    if check_port $port; then
        echo "❌ Port $port is still in use after waiting. Cannot start $service."
        return 1
    fi
    return 0
}

# Function to wait for service health
wait_for_health() {
    local url=$1
    local service=$2
    local retries=12
    local wait=5
    local ready=false
    
    echo "⏳ Waiting for $service to be healthy..."
    while [ $retries -gt 0 ]; do
        if curl -s "$url" > /dev/null; then
            echo "✅ $service is healthy"
            ready=true
            break
        fi
        echo "⏳ Waiting for $service to initialize... (attempts remaining: $retries)"
        sleep $wait
        retries=$((retries - 1))
    done
    
    if [ "$ready" = false ]; then
        echo "❌ $service health check failed after all retries"
        return 1
    fi
    return 0
}

# Start backend
echo "🔧 Starting backend server..."

# Check if backend port is available
if ! wait_for_port 8000 "backend"; then
    exit 1
fi

cd backend/src
source ../../venv/bin/activate
export PYTHONPATH=$(pwd):$PYTHONPATH
python3.11 main.py > ../../backend.log 2>&1 &
BACKEND_PID=$!
cd ../..

# Wait for backend to be healthy
if ! wait_for_health "http://localhost:8000/health" "backend"; then
    if ! ps -p $BACKEND_PID > /dev/null; then
        echo "❌ Backend process died"
        exit 1
    else
        echo "⚠️  Backend running but health check failed - continuing anyway"
    fi
fi

# Start frontend
echo "🎨 Starting frontend..."

# Check if frontend port is available
if ! wait_for_port 3000 "frontend"; then
    kill $BACKEND_PID 2>/dev/null
    exit 1
fi

cd frontend

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found in frontend directory"
    kill $BACKEND_PID 2>/dev/null
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ] || [ ! -f "node_modules/.package-lock.json" ]; then
    echo "📦 Installing frontend dependencies..."
    npm install --force
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install frontend dependencies"
        kill $BACKEND_PID 2>/dev/null
        exit 1
    fi
fi

# Start the frontend
echo "🚀 Starting frontend server..."
PORT=3000 BROWSER=none npm start > ../frontend.log 2>&1 &
FRONTEND_PID=$!
cd ..

# Wait for frontend to be healthy
if ! wait_for_health "http://localhost:3000" "frontend"; then
    if ! ps -p $FRONTEND_PID > /dev/null; then
        echo "❌ Frontend process died"
        kill $BACKEND_PID 2>/dev/null
        exit 1
    else
        echo "⚠️  Frontend running but health check failed - continuing anyway"
    fi
fi

# Save PIDs for stop script
echo $BACKEND_PID > .backend.pid
echo $FRONTEND_PID > .frontend.pid

echo "✅ System started successfully!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔧 Backend API: http://localhost:8000"
echo "📊 Dashboard: http://localhost:8000/api/v1/dashboard"
echo ""
echo "Run ./scripts/stop.sh to stop the system"
