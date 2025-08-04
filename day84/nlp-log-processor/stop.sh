#!/bin/bash

echo "🛑 Stopping NLP Log Processing System"
echo "====================================="

# Stop any running Python processes
echo "🔍 Stopping Python processes..."
pkill -f "python src/api/server.py" || true
pkill -f "python scripts/demo.py" || true

# Stop Docker containers
if [ -f "docker-compose.yml" ]; then
    echo "🐳 Stopping Docker containers..."
    docker-compose down
fi

# Deactivate virtual environment
if [ "$VIRTUAL_ENV" != "" ]; then
    echo "📦 Deactivating virtual environment..."
    deactivate
fi

echo "✅ System stopped successfully"

# Cleanup instructions
echo ""
echo "🧹 Cleanup Instructions:"
echo "========================"
echo ""
echo "📁 Data Cleanup:"
echo "  • Remove processed logs: rm -rf data/logs/*"
echo "  • Remove cached models: rm -rf data/models/*"
echo "  • Remove sample data: rm -rf data/sample_logs/*"
echo "  • Remove training data: rm -rf data/training/*"
echo ""
echo "🐳 Docker Cleanup:"
echo "  • Remove unused images: docker image prune -f"
echo "  • Remove unused containers: docker container prune -f"
echo "  • Remove unused networks: docker network prune -f"
echo "  • Remove unused volumes: docker volume prune -f"
echo "  • Full cleanup: docker system prune -a -f"
echo ""
echo "📦 Python Cleanup:"
echo "  • Remove cache: find . -type d -name '__pycache__' -exec rm -rf {} +"
echo "  • Remove .pyc files: find . -name '*.pyc' -delete"
echo "  • Remove virtual env: rm -rf venv/"
echo ""
echo "🔧 System Cleanup:"
echo "  • Remove temp files: rm -rf tmp/ temp/"
echo "  • Remove log files: rm -f *.log"
echo "  • Remove PID files: rm -f *.pid"
echo ""
echo "💡 Quick Cleanup Commands:"
echo "  • Basic cleanup: ./cleanup.sh"
echo "  • Full cleanup: ./cleanup.sh --full"
echo "  • Docker only: ./cleanup.sh --docker"
echo ""
echo "⚠️  Note: Use cleanup commands carefully as they will delete data!"
