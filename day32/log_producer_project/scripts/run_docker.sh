#!/bin/bash
set -e

echo "🐳 Starting with Docker..."

cd docker
docker-compose up --build
