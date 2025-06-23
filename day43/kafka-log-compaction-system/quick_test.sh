#!/bin/bash

echo "⚡ Quick Test Runner"
echo "=================="

# Build and test only
./scripts/build.sh
./scripts/test.sh

echo ""
echo "✅ Quick test completed!"
echo "🚀 To run full demo: ./run_demo.sh"
echo "🐳 To run Docker demo: ./run_docker_demo.sh"
