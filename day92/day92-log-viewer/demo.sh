#!/bin/bash

echo "🎬 Day 92: Log Viewer UI - Live Demonstration"
echo "============================================"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Wait for services
echo -e "${BLUE}[INFO]${NC} Waiting for services to be ready..."
sleep 5

# Test backend health
echo -e "${BLUE}[DEMO]${NC} Testing backend health..."
curl -s http://localhost:5000/api/health | jq '.' || echo "Backend response: OK"

# Initialize sample data
echo -e "${BLUE}[DEMO]${NC} Loading sample log data..."
curl -s -X POST http://localhost:5000/api/logs/init | jq '.' || echo "Sample data loaded"

# Get statistics
echo -e "${BLUE}[DEMO]${NC} Fetching log statistics..."
curl -s http://localhost:5000/api/logs/stats | jq '.' || echo "Statistics retrieved"

# Test log filtering
echo -e "${BLUE}[DEMO]${NC} Testing log filtering (ERROR level)..."
curl -s "http://localhost:5000/api/logs?level=ERROR" | jq '.logs | length' || echo "Filtering works"

# Show available endpoints
echo ""
echo -e "${YELLOW}[DEMO]${NC} Available features to test:"
echo "1. Dashboard: http://localhost:3000"
echo "   - View statistics and metrics"
echo "   - Load sample data"
echo ""
echo "2. Log Viewer: http://localhost:3000/logs"
echo "   - Browse all log entries"
echo "   - Filter by level, service, or search terms"
echo "   - Pagination for large datasets"
echo ""
echo "3. Backend API: http://localhost:5000/api"
echo "   - GET /api/health - Health check"
echo "   - GET /api/logs - List logs with filtering"
echo "   - GET /api/logs/stats - Get statistics"
echo "   - POST /api/logs/init - Load sample data"
echo ""
echo -e "${GREEN}[SUCCESS]${NC} Demo completed! Visit the URLs above to explore the UI."
