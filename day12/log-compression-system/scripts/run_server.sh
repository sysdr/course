#!/bin/bash
set -e

# Activate virtual environment
source venv/bin/activate

# Run the server
echo "Starting log receiver server..."
python src/server.py --host 0.0.0.0 --port 5000
