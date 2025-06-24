#!/bin/bash

echo "🔧 Setting up Kafka Log Compaction System Development Environment..."

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

# Create virtual environment (optional but recommended)
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
    echo "✅ Virtual environment created"
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully!"
else
    echo "❌ Failed to install dependencies!"
    exit 1
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p data logs

# Check Docker availability
if command -v docker &> /dev/null; then
    echo "🐳 Docker found - containerized deployment available"
    
    # Check if docker-compose is available
    if command -v docker-compose &> /dev/null; then
        echo "✅ docker-compose found"
    else
        echo "⚠️  docker-compose not found - install for containerized deployment"
    fi
else
    echo "⚠️  Docker not found - will use local development mode only"
fi

# Set up pre-commit hooks (optional)
if command -v pre-commit &> /dev/null; then
    echo "🔧 Setting up pre-commit hooks..."
    pre-commit install
else
    echo "💡 Install pre-commit for automatic code formatting: pip install pre-commit"
fi

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "🚀 Next steps:"
echo "   Build:     ./scripts/build.sh"
echo "   Test:      ./scripts/test.sh"
echo "   Run Local: ./scripts/run.sh"
echo "   Run Docker: ./run_docker_demo.sh"
echo "   Cleanup:   ./scripts/cleanup.sh --all"
echo ""
echo "📊 Web Dashboard will be available at: http://localhost:8080"
