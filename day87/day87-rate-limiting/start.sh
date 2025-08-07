#!/bin/bash

echo "🚀 Starting Day 87: Rate Limiting and Quota Management"

# Check if we're in the right directory
if [ ! -f "backend/src/main.py" ]; then
    echo "❌ Error: Please run this script from the day87-rate-limiting directory"
    exit 1
fi

# Activate virtual environment
if [ -d "venv" ]; then
    echo "📦 Activating virtual environment..."
    source venv/bin/activate
else
    echo "❌ Error: Virtual environment not found. Please run setup.sh first."
    exit 1
fi

# Start Redis if not running
if ! pgrep redis-server > /dev/null; then
    echo "🔄 Starting Redis..."
    redis-server --daemonize yes
    sleep 2
fi

# Start backend
echo "🚀 Starting backend server..."
cd backend
python src/main.py &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo "⏳ Waiting for backend to start..."
sleep 5

# Check if backend is running
if ! kill -0 $BACKEND_PID 2>/dev/null; then
    echo "❌ Error: Backend failed to start"
    exit 1
fi

# Start frontend
echo "🎨 Starting frontend..."
cd frontend
npm start &
FRONTEND_PID=$!
cd ..

# Wait for frontend to start
echo "⏳ Waiting for frontend to start..."
sleep 10

# Check if frontend is running
if ! kill -0 $FRONTEND_PID 2>/dev/null; then
    echo "❌ Error: Frontend failed to start"
    kill $BACKEND_PID 2>/dev/null
    exit 1
fi

# Save PIDs for cleanup
echo $BACKEND_PID > .backend.pid
echo $FRONTEND_PID > .frontend.pid

echo ""
echo "🎉 Day 87: Rate Limiting and Quota Management is running!"
echo ""
echo "📊 Dashboard: http://localhost:3000"
echo "🔧 API: http://localhost:8000"
echo "📈 Metrics: http://localhost:8000/metrics"
echo "🏥 Health: http://localhost:8000/health"
echo ""
echo "💡 Test the rate limiting by:"
echo "   1. Visit the dashboard"
echo "   2. Try the 'Test GraphQL Query' button multiple times"
echo "   3. Watch rate limits and quotas in action"
echo ""
echo "🐳 For Docker deployment: docker-compose up"
echo "🛑 To stop: ./stop.sh"
echo ""

# Wait for user to stop
echo "Press Ctrl+C to stop all services..."
wait 