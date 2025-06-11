#!/bin/bash

echo "🔨 Building Log Processing System - RabbitMQ Module"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Verify installation
echo "✅ Verifying installations..."
python -c "import pika; print(f'Pika version: {pika.__version__}')"
python -c "import yaml; print('YAML support: OK')"

echo "🎯 Build completed successfully!"
