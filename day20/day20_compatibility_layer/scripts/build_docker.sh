#!/bin/bash

echo "🐳 Building Day 20: Compatibility Layer (Docker)"
echo "=============================================="

# Create Dockerfile
cat > Dockerfile << 'DOCKERFILE'
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY config/ ./config/
COPY tests/ ./tests/
COPY logs/ ./logs/
COPY ui/ ./ui/

# Create non-root user
RUN useradd -m -u 1000 logprocessor && \
    chown -R logprocessor:logprocessor /app

USER logprocessor

# Expose port for web UI
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 -c "from src.compatibility_processor import CompatibilityProcessor; CompatibilityProcessor()" || exit 1

# Default command
CMD ["python3", "-m", "http.server", "8080", "--directory", "ui"]
DOCKERFILE

# Create docker-compose.yml
cat > docker-compose.yml << 'COMPOSE'
version: '3.8'

services:
  compatibility-layer:
    build: .
    container_name: day20_compatibility_layer
    ports:
      - "8080:8080"
    volumes:
      - ./logs:/app/logs
      - ./config:/app/config
    environment:
      - PYTHONPATH=/app/src
      - LOG_LEVEL=INFO
    restart: unless-stopped
    
  # Optional: Log file watcher for real-time processing
  log-watcher:
    build: .
    container_name: day20_log_watcher
    volumes:
      - ./logs:/app/logs
    command: python3 -c "print('Log watcher ready for real-time processing')"
    depends_on:
      - compatibility-layer
    restart: unless-stopped

networks:
  default:
    name: compatibility_layer_network
COMPOSE

# Build Docker image
echo "🏗️ Building Docker image..."
docker build -t day20_compatibility_layer .

echo "✅ Docker build complete!"
echo ""
echo "🚀 Docker Commands:"
echo "   docker-compose up -d    # Start services"
echo "   docker-compose logs -f  # View logs"
echo "   docker-compose down     # Stop services"
echo "   Open http://localhost:8080 for web UI"
