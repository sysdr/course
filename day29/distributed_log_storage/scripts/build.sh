#!/bin/bash

echo "🔨 Building Anti-Entropy System..."

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Create necessary directories
mkdir -p data/{node_a,node_b,node_c} logs

echo "✅ Build completed successfully!"
echo "Run: source venv/bin/activate && python main.py"
