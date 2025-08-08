#!/bin/bash

echo "🧹 Starting comprehensive project cleanup..."

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Stop all running containers
echo -e "${BLUE}[INFO]${NC} Stopping all containers..."
./stop.sh 2>/dev/null || true

# Remove Docker containers, images, and volumes
echo -e "${BLUE}[INFO]${NC} Cleaning up Docker resources..."
docker-compose down -v --remove-orphans 2>/dev/null || true
docker rmi day92-log-viewer-backend day92-log-viewer-frontend 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# Remove Python cache files
echo -e "${BLUE}[INFO]${NC} Removing Python cache files..."
find . -type f -name "*.pyc" -delete
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# Remove Node.js cache and build files
echo -e "${BLUE}[INFO]${NC} Cleaning Node.js cache and build files..."
rm -rf frontend/node_modules 2>/dev/null || true
rm -rf frontend/build 2>/dev/null || true
rm -f frontend/package-lock.json 2>/dev/null || true

# Remove virtual environment
echo -e "${BLUE}[INFO]${NC} Removing virtual environment..."
rm -rf venv 2>/dev/null || true

# Remove temporary files
echo -e "${BLUE}[INFO]${NC} Removing temporary files..."
find . -name "*.log" -delete 2>/dev/null || true
find . -name ".DS_Store" -delete 2>/dev/null || true
find . -name "*.tmp" -delete 2>/dev/null || true
find . -name "*.swp" -delete 2>/dev/null || true
find . -name "*.swo" -delete 2>/dev/null || true

# Remove data files (logs, exports)
echo -e "${BLUE}[INFO]${NC} Cleaning data files..."
rm -rf data/logs/* 2>/dev/null || true
rm -rf data/exports/* 2>/dev/null || true

# Remove any PID files
echo -e "${BLUE}[INFO]${NC} Removing PID files..."
rm -f *.pid 2>/dev/null || true
rm -f backend/*.pid 2>/dev/null || true
rm -f frontend/*.pid 2>/dev/null || true

# Remove any temporary database files
echo -e "${BLUE}[INFO]${NC} Removing database files..."
rm -f backend/*.db 2>/dev/null || true
rm -f backend/*.sqlite 2>/dev/null || true
rm -f backend/*.sqlite3 2>/dev/null || true

# Clean up any backup files
echo -e "${BLUE}[INFO]${NC} Removing backup files..."
find . -name "*.bak" -delete 2>/dev/null || true
find . -name "*.backup" -delete 2>/dev/null || true

# Remove any coverage reports
echo -e "${BLUE}[INFO]${NC} Removing coverage reports..."
rm -rf htmlcov 2>/dev/null || true
rm -f .coverage 2>/dev/null || true

# Remove any test artifacts
echo -e "${BLUE}[INFO]${NC} Removing test artifacts..."
rm -rf .pytest_cache 2>/dev/null || true
rm -rf .tox 2>/dev/null || true

# Clean up any IDE files
echo -e "${BLUE}[INFO]${NC} Removing IDE files..."
rm -rf .vscode 2>/dev/null || true
rm -rf .idea 2>/dev/null || true
find . -name "*.sublime-*" -delete 2>/dev/null || true

# Remove any OS-specific files
echo -e "${BLUE}[INFO]${NC} Removing OS-specific files..."
find . -name "Thumbs.db" -delete 2>/dev/null || true
find . -name ".DS_Store" -delete 2>/dev/null || true

# Clean up any npm/yarn cache
echo -e "${BLUE}[INFO]${NC} Cleaning npm cache..."
npm cache clean --force 2>/dev/null || true

# Remove any Docker build cache
echo -e "${BLUE}[INFO]${NC} Cleaning Docker build cache..."
docker builder prune -f 2>/dev/null || true

# Show cleanup summary
echo ""
echo -e "${GREEN}[SUCCESS]${NC} Project cleanup completed!"
echo ""
echo -e "${YELLOW}Cleaned up:${NC}"
echo "  ✅ Docker containers, images, and volumes"
echo "  ✅ Python cache files (__pycache__, *.pyc)"
echo "  ✅ Node.js cache and build files"
echo "  ✅ Virtual environment"
echo "  ✅ Temporary files (*.log, *.tmp, .DS_Store)"
echo "  ✅ Data files (logs, exports)"
echo "  ✅ PID files"
echo "  ✅ Database files"
echo "  ✅ Backup files"
echo "  ✅ Coverage reports"
echo "  ✅ Test artifacts"
echo "  ✅ IDE files"
echo "  ✅ OS-specific files"
echo "  ✅ NPM cache"
echo "  ✅ Docker build cache"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  🚀 Run './start.sh' to start the application"
echo "  📝 Run './scripts/ingest_logs.sh' to add sample data"
echo ""
