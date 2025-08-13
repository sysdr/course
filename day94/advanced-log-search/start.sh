#!/bin/bash

echo "🚀 Starting Advanced Log Search System (Day 94)"

# Check if Python 3.11 is available
if command -v python3.11 &> /dev/null; then
    PYTHON_CMD=python3.11
elif command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
else
    echo "❌ Python 3.11+ required but not found"
    exit 1
fi

echo "🐍 Using Python: $($PYTHON_CMD --version)"

# Create virtual environment
echo "📦 Creating virtual environment..."
$PYTHON_CMD -m venv venv

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install backend dependencies
echo "📚 Installing backend dependencies..."
pip install --upgrade pip
pip install -r backend/requirements.txt

# Create data directory
echo "📁 Creating data directory..."
mkdir -p data

# Initialize database
echo "🗄️ Initializing database..."
cd backend && $PYTHON_CMD -c "
import asyncio
from main import init_database
asyncio.run(init_database())
print('✅ Database initialized')
" && cd ..

# Start the application
echo "🎯 Starting application..."
echo "🌐 Open http://localhost:8000 in your browser"
echo "📊 Search interface will be available shortly..."
echo ""
echo "💡 Tip: Open browser console and run 'generateDemoLogs()' to create test data"
echo ""

cd backend && $PYTHON_CMD main.py
