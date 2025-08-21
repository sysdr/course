#!/bin/bash

echo "🚀 Day 95: Starting Customizable Dashboard System"
echo "=================================================="

# Check if virtual environment exists, create if not
if [ ! -d "venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3.11 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install/upgrade pip
pip install --upgrade pip

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend && pip install -r requirements.txt && cd ..

# Run tests
echo "🧪 Running tests..."
python run_tests.py

# Start the demo
echo "🎬 Starting demo..."
python demo.py
