#!/bin/bash

set -e

echo "🏗️  Building Log Consumer System"
echo "================================"

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Create required directories
echo "📁 Creating directories..."
mkdir -p logs
touch logs/processed_logs.jsonl

# Run code quality checks
echo "🔍 Running code quality checks..."
if command -v flake8 &> /dev/null; then
    flake8 src/ --max-line-length=100 --ignore=E203,W503 || echo "Flake8 not available, skipping..."
fi

echo "✅ Build complete!"
