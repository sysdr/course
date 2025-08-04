#!/bin/bash

source venv/bin/activate

echo "🌐 Starting NLP Log Processing Server"
echo "===================================="

export FLASK_ENV=development
export FLASK_DEBUG=1

echo "Server will be available at: http://localhost:5000"
echo "Dashboard: http://localhost:5000"
echo "API Health: http://localhost:5000/api/health"
echo ""
echo "Press Ctrl+C to stop the server"

python src/api/server.py
