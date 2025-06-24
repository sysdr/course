#!/bin/bash

echo "🔨 Building Day 20: Compatibility Layer"
echo "====================================="

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔄 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install --upgrade pip

# Create requirements.txt
cat > requirements.txt << 'REQUIREMENTS'
# Core dependencies
python-dateutil>=2.8.0
pytz>=2021.1

# Development dependencies  
pytest>=6.0.0
pytest-cov>=2.10.0

# Optional dependencies for extended functionality
colorama>=0.4.4
tabulate>=0.8.9
REQUIREMENTS

pip install -r requirements.txt

echo "✅ Build complete!"
echo ""
echo "🚀 Quick Start Commands:"
echo "   source venv/bin/activate"  
echo "   python3 tests/test_compatibility_layer.py"
echo "   python3 -c \"from src.compatibility_processor import CompatibilityProcessor; cp = CompatibilityProcessor(); print('Ready to process logs!')\""
