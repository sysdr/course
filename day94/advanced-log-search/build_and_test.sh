#!/bin/bash

echo "🏗️ Day 94: Advanced Search Interface - Build and Test"

# Create Python virtual environment
echo "📦 Setting up Python environment..."
python3.11 -m venv venv 2>/dev/null || python3 -m venv venv
source venv/bin/activate

# Install dependencies
echo "📚 Installing dependencies..."
pip install --upgrade pip --quiet
pip install -r backend/requirements.txt --quiet

# Create data directory
mkdir -p data

# Run syntax checks
echo "🔍 Running syntax checks..."
python -m py_compile backend/main.py
python -m py_compile demo.py
echo "✅ All Python files have valid syntax!"

# Initialize database
echo "🗄️ Initializing database..."
source venv/bin/activate
python init_db.py

# Run unit tests
echo "🧪 Running unit tests..."
cd backend
python -m pytest tests/ -v --tb=short
cd ..

# Start application in background
echo "🚀 Starting application..."
cd backend
python main.py &
APP_PID=$!
cd ..

# Wait for application to start
echo "⏳ Waiting for application to start..."
sleep 5

# Test application endpoints
echo "🔗 Testing application endpoints..."
curl -s http://localhost:8000/api/filters > /dev/null && echo "✅ API endpoints responding"

# Generate demo data
echo "📊 Generating demo data..."
python demo.py

# Test search functionality
echo "🔍 Testing search functionality..."
python demo.py test

# Check if frontend is accessible
echo "🌐 Testing frontend..."
curl -s http://localhost:8000/ > /dev/null && echo "✅ Frontend accessible at http://localhost:8000"

# Display completion message
echo ""
echo "🎉 Build and test completed successfully!"
echo "🌐 Open http://localhost:8000 to use the advanced search interface"
echo "💡 Try searching for: 'error', 'payment', 'timeout'"
echo "🔧 Use filters to narrow down results by level, service, time range"
echo ""
echo "📋 Next steps:"
echo "   1. Open browser and visit http://localhost:8000"
echo "   2. Try different search queries and filters"
echo "   3. Test real-time updates by opening browser console and running 'generateDemoLogs()'"
echo "   4. Export search results in different formats"
echo ""
echo "🛑 To stop: kill $APP_PID"

# Keep application running
wait $APP_PID
