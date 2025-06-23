#!/bin/bash

echo "🔨 Building Kafka Log Compaction System..."

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found. Please install Python3 first."
    exit 1
fi

# Check if pip is available
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 not found. Please install pip3 first."
    exit 1
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install -r requirements.txt

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully!"
else
    echo "❌ Failed to install dependencies!"
    exit 1
fi

# Create necessary directories if they don't exist
echo "📁 Creating necessary directories..."
mkdir -p data logs

# Check if Docker is available for containerized deployment
if command -v docker &> /dev/null; then
    echo "🐳 Docker found - ready for containerized deployment"
else
    echo "⚠️  Docker not found - will use local development mode only"
fi

echo "✅ Build successful!"
echo "🚀 You can now run the system with:"
echo "   Local mode: ./scripts/run.sh"
echo "   Docker mode: ./run_docker_demo.sh"
