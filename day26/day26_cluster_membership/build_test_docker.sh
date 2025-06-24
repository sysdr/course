#!/bin/bash
echo "=== Building and testing with Docker ==="

# Build Docker image
docker build -t cluster-membership .

# Run tests in container
docker run --rm cluster-membership

echo "=== Docker build and test completed successfully ==="
