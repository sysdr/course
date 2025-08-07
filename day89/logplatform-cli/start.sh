#!/bin/bash

# Day 89: LogPlatform CLI - Start Script
set -e

echo "🚀 Starting LogPlatform CLI Environment"
echo "======================================"

# Create and activate virtual environment
echo "📦 Setting up Python virtual environment..."
python3.11 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
echo "📚 Installing dependencies..."
pip install -r requirements.txt

# Install CLI package in development mode
echo "⚙️ Installing CLI package..."
pip install -e .

# Start mock API server in background
echo "🎭 Starting mock API server..."
python scripts/mock_api.py &
MOCK_API_PID=$!
echo "Mock API PID: $MOCK_API_PID" > .mock_api_pid

# Wait for API to start
sleep 3

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v

# Demo the CLI
echo ""
echo "🎯 CLI Demo - Basic Commands"
echo "============================"

# Initialize configuration
echo "📝 Initializing configuration..."
logplatform config init --server-url http://localhost:8000 --profile-name demo

# Login demo
echo "🔐 Demo login..."
echo -e "demo\ndemo" | logplatform auth login

# Show status
echo "📊 Authentication status:"
logplatform auth status

# Search logs
echo "🔍 Searching logs..."
logplatform logs search --limit 5

# Show alerts
echo "🚨 Listing alerts..."
logplatform alerts list

# Show health
echo "💚 Health check..."
logplatform admin health

# Show platform stats
echo "📈 Platform statistics..."
logplatform admin stats

echo ""
echo "✅ LogPlatform CLI is ready!"
echo "=============================="
echo ""
echo "📋 Available Commands:"
echo "  logplatform auth login     - Login to platform"
echo "  logplatform logs search    - Search logs"
echo "  logplatform logs stream    - Stream logs in real-time"
echo "  logplatform alerts list    - List alerts"
echo "  logplatform config get     - Show configuration"
echo "  logplatform admin health   - Check platform health"
echo "  logplatform --help         - Show all commands"
echo ""
echo "🌐 Mock API Server: http://localhost:8000"
echo "🔑 Demo Credentials: demo/demo"
echo ""
echo "🛑 To stop: run ./stop.sh"
