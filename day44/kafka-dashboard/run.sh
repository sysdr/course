#!/bin/bash

echo "Starting Kafka Dashboard..."

# Start Docker services
docker-compose -f docker/docker-compose.yml up -d

echo "Waiting for Kafka to be ready..."
sleep 30

# Setup topics
./setup.sh

echo "Dashboard available at http://localhost:5000"
echo "Starting data generator..."

# Start data generator in background
python src/main/data_generator.py &

# Start dashboard
python src/main/web_app.py
