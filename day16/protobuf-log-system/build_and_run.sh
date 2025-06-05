#!/bin/bash

echo "🏗️  Building Protocol Buffers Log System"
echo "========================================"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Generate Protocol Buffer code
echo "⚡ Generating Protocol Buffer code..."
python -m grpc_tools.protoc --proto_path=proto --python_out=proto --grpc_python_out=proto proto/log_entry.proto

# Verify generated files
if [ -f "proto/log_entry_pb2.py" ]; then
    echo "✅ Protocol Buffer code generated successfully"
else
    echo "❌ Failed to generate Protocol Buffer code"
    exit 1
fi

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed"
    exit 1
fi

# Run the main demonstration
echo "🚀 Running Protocol Buffers demonstration..."
cd src
python protobuf_log_processor.py
cd ..

echo "🌐 Starting web interface..."
echo "Open http://localhost:5000 in your browser"
cd web
python log_viewer.py &
WEB_PID=$!

echo "Press Ctrl+C to stop the web server"
wait $WEB_PID
