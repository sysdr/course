#!/bin/bash
set -e

echo "🎬 One-Click Protocol Buffers Demo Starting..."
echo "This will setup, build, test, and demonstrate the system!"
echo

# Step 1: Setup
echo "📋 Step 1: Setting up environment..."
chmod +x scripts/setup.sh
./scripts/setup.sh

# Step 2: Run unit tests
echo
echo "🧪 Step 2: Running unit tests..."
python -m pytest tests/test_protobuf_system.py -v

# Step 3: Performance benchmarks
echo
echo "⚡ Step 3: Running performance benchmarks..."
cd src && python performance_tester.py && cd ..

# Step 4: Generate sample data
echo
echo "💾 Step 4: Generating sample log files..."
python generate_sample_data.py

echo
echo "🎉 Demo Complete! Check the logs/ directory for generated files."
echo "📊 Performance results show the speed and size improvements of Protocol Buffers!"
