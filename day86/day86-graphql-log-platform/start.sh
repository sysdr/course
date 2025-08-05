#!/bin/bash
set -e

echo "🚀 Starting Day 86: GraphQL Log Platform"
echo "======================================"

# Create logs directory if it doesn't exist
mkdir -p logs

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "⚠️  Port $port is already in use. Stopping existing process..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
}

# Check and clear ports
check_port 8000
check_port 3000

# Start backend
echo "📡 Starting GraphQL backend server..."
cd backend
source ../venv/bin/activate
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload > ../logs/backend.log 2>&1 &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo "⏳ Waiting for backend to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Backend is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Backend failed to start within 30 seconds"
        exit 1
    fi
    sleep 1
done

# Generate sample data
echo "📊 Generating sample log data..."
cd backend
source ../venv/bin/activate
python -c "
import asyncio
import httpx
import json

async def generate_sample_data():
    mutation = '''
    mutation CreateLog(\$logData: LogCreateInput!) {
        createLog(logData: \$logData) {
            id
            service
            level
            message
        }
    }
    '''
    
    sample_logs = [
        {'service': 'api-gateway', 'level': 'INFO', 'message': 'Request processed successfully'},
        {'service': 'user-service', 'level': 'ERROR', 'message': 'Database connection failed'},
        {'service': 'order-service', 'level': 'WARNING', 'message': 'High memory usage detected'},
        {'service': 'payment-service', 'level': 'INFO', 'message': 'Payment processed'},
        {'service': 'inventory-service', 'level': 'DEBUG', 'message': 'Stock level checked'},
    ]
    
    async with httpx.AsyncClient() as client:
        for log_data in sample_logs:
            try:
                response = await client.post(
                    'http://localhost:8000/graphql',
                    json={'query': mutation, 'variables': {'logData': log_data}}
                )
                print(f'Created log: {log_data[\"service\"]} - {log_data[\"level\"]}')
            except Exception as e:
                print(f'Error creating log: {e}')

asyncio.run(generate_sample_data())
"
cd ..

# Start frontend
echo "🎨 Starting React frontend..."
cd frontend
npm start > ../logs/frontend.log 2>&1 &
FRONTEND_PID=$!
cd ..

# Wait for frontend to start
echo "⏳ Waiting for frontend to be ready..."
for i in {1..60}; do
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        echo "✅ Frontend is ready!"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "⚠️  Frontend may still be starting up..."
    fi
    sleep 1
done

echo ""
echo "✅ GraphQL Log Platform is running!"
echo ""
echo "🌐 Access points:"
echo "   Frontend Dashboard: http://localhost:3000"
echo "   Backend API: http://localhost:8000"
echo "   GraphQL Playground: http://localhost:8000/graphql"
echo "   Health Check: http://localhost:8000/health"
echo ""
echo "📁 Log files:"
echo "   Backend logs: logs/backend.log"
echo "   Frontend logs: logs/frontend.log"
echo ""
echo "🔧 Test commands:"
echo "   Run tests: cd backend && source ../venv/bin/activate && python -m pytest tests/ -v"
echo "   Stop server: ./stop.sh"
echo ""
echo "Press Ctrl+C to stop..."

# Save PIDs to file for stop script
echo $BACKEND_PID > .backend.pid
echo $FRONTEND_PID > .frontend.pid

# Keep script running and handle cleanup on exit
trap 'echo ""; echo "🛑 Shutting down..."; ./stop.sh; exit 0' INT TERM

# Wait for background processes
wait $BACKEND_PID $FRONTEND_PID
