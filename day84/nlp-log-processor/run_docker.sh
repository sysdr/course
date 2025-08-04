#!/bin/bash

echo "🐳 Running NLP Log Processor with Docker"
echo "========================================"

# Build and start with docker-compose
docker-compose up --build -d

echo "✅ Docker containers started"
echo ""
echo "🌐 Application URLs:"
echo "  Dashboard: http://localhost:5000"
echo "  API Health: http://localhost:5000/api/health"
echo ""
echo "📊 Container status:"
docker-compose ps

echo ""
echo "📝 View logs with: docker-compose logs -f"
echo "🛑 Stop with: docker-compose down"
