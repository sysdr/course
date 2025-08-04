#!/bin/bash

echo "🚀 Starting NLP Log Processor..."

# Activate virtual environment
source venv/bin/activate

# Start the Flask server
echo "🌐 Starting Flask server on http://localhost:5000"
python src/api/server.py
