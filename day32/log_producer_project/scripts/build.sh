#!/bin/bash
set -e

echo "🔨 Building Log Producer..."

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Run syntax checks
echo "🔍 Running syntax checks..."
python -m py_compile src/producer/*.py
python -m py_compile src/models/*.py

echo "✅ Build completed successfully!"
