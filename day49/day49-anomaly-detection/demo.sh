#!/bin/bash

# Day 49: Anomaly Detection for Distributed Log Processing - Demo Script
# This script creates a complete anomaly detection system with real-time visualization

set -e

echo "🚀 Day 49: Setting up Anomaly Detection System for Distributed Log Processing"
echo "============================================================================"

echo "📦 Installing Python dependencies..."
python3 -m pip install --upgrade pip
pip3 install -r requirements.txt

echo "🧪 Running tests..."
python3 -m pytest tests/ -v

echo "🛑 Killing any process using port 5001 to avoid conflicts..."
lsof -ti:5001 | xargs kill -9 2>/dev/null || true

# Note about resource tracker warnings
cat <<EOF
⚠️  Note: You may see 'resource_tracker: There appear to be 1 leaked semaphore objects to clean up at shutdown' warnings. These are not fatal and can be ignored for the demo.
EOF

echo "🚀 Starting anomaly detection system..."
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"

# Start the application in background
python3 src/app.py &
APP_PID=$!

# Wait for app to start
sleep 5

echo ""
echo "✅ Day 49 Anomaly Detection System is running!"
echo "🌐 Dashboard: http://localhost:5001"
echo "📊 Real-time anomaly detection with multiple algorithms"
echo "🔍 Features: Z-score, Isolation Forest, and Temporal Pattern Detection"
echo ""
echo "The system is now:"
echo "- Processing real-time log streams"
echo "- Detecting anomalies using ensemble methods"
echo "- Displaying results on a live dashboard"
echo "- Tracking detection accuracy and false positive rates"
echo ""
echo "Press Ctrl+C to stop the demonstration"
echo ""
echo "If you do not see the latest UI changes, please refresh your browser (Ctrl+Shift+R or Cmd+Shift+R)."
echo ""

# Keep the script running
wait $APP_PID