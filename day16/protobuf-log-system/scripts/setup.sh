#!/bin/bash
set -e

echo "🚀 Setting up Protocol Buffers Log System..."

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Generate Protocol Buffer code
echo "🔧 Generating Protocol Buffer code..."
python -m grpc_tools.protoc \
    --proto_path=proto \
    --python_out=proto \
    --grpc_python_out=proto \
    proto/log_entry.proto

echo "✅ Protocol Buffer code generated successfully!"

# Create log directories
mkdir -p logs/{json,protobuf}

echo "🎉 Setup complete! Ready to run the system."
