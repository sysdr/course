#!/bin/bash

echo "🚀 Starting Correlation Analysis System"
echo "====================================="


echo "🐍 Setting up Python ${PYTHON_VERSION} environment..."
    
    python${PYTHON_VERSION} -m venv venv
    source venv/bin/activate
    
    # Backend dependencies
    cat > backend/requirements.txt << 'EOF'
fastapi==0.110.3
uvicorn==0.29.0
pandas==2.2.2
numpy==1.26.4
scipy==1.13.0
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
    
    pip install -r backend/requirements.txt
    
    echo "✅ Python environment ready"


# Check if virtual environment exists, if not create it
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3.11 -m venv venv
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create virtual environment"
        exit 1
    fi
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate
if [ $? -ne 0 ]; then
    echo "❌ Failed to activate virtual environment"
    exit 1
fi

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend

# Check if requirements.txt exists
if [ ! -f "requirements.txt" ]; then
    echo "❌ requirements.txt not found in backend directory"
    exit 1
fi

# Upgrade pip to latest version
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "📦 Installing Python packages..."
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "❌ Failed to install backend dependencies"
    exit 1
fi
cd ..

# Start backend
echo "🔧 Starting backend server..."
cd backend
export PYTHONPATH=$(pwd)/src:$PYTHONPATH
python src/main.py &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo "⏳ Waiting for backend to start..."
sleep 5

# Check if backend is running
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ Backend running on http://localhost:8000"
else
    echo "❌ Backend failed to start"
    kill $BACKEND_PID 2>/dev/null
    exit 1
fi

# Start frontend
echo "🎨 Starting frontend..."
cd frontend

npm install --force
# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found in frontend directory"
    kill $BACKEND_PID 2>/dev/null
    exit 1
fi

# Check if node_modules exists, if not install dependencies
if [ ! -d "node_modules" ]; then
    echo "📦 Installing frontend dependencies..."
    npm install
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install frontend dependencies"
        kill $BACKEND_PID 2>/dev/null
        exit 1
    fi
fi

# Start the frontend
npm start &
FRONTEND_PID=$!
cd ..

# Wait for frontend to start
echo "⏳ Waiting for frontend to start..."
sleep 10

# Check if frontend is running
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ Frontend running on http://localhost:3000"
else
    echo "⚠️  Frontend may still be starting up..."
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
