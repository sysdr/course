#!/bin/bash

echo "🚀 Starting Day 85 Log Platform API..."

# Activate virtual environment
source venv/bin/activate

# Set Python path
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

echo "📊 Running tests..."
python3.11 -m pytest tests/ -v

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
    
    echo "🔧 Starting API server..."
    uvicorn src.api.main:app --host 0.0.0.0 --port 8000 --reload &
    API_PID=$!
    
    echo "⏳ Waiting for API to start..."
    sleep 5
    
    echo "🧪 Testing API endpoints..."
    curl -s http://localhost:8000/api/v1/health | python -m json.tool
    
    echo ""
    echo "🎉 Day 85 Log Platform API is running!"
    echo "📊 API Documentation: http://localhost:8000/docs"
    echo "🌐 Health Check: http://localhost:8000/api/v1/health"
    echo "📱 Frontend (if installed): http://localhost:3000"
    echo ""
    echo "💡 Test the API:"
    echo "   curl http://localhost:8000/api/v1/logs"
    echo "   curl -X POST http://localhost:8000/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"developer\",\"password\":\"dev123\"}'"
    echo ""
    echo "🛑 Press Ctrl+C to stop the server"
    
    # Save PID for stop script
    echo $API_PID > api.pid
    
    # Keep script running
    wait $API_PID
else
    echo "❌ Tests failed! Please check the output above."
    exit 1
fi
