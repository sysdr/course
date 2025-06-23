#!/bin/bash

echo "📊 Kafka Log Compaction System Status"
echo "====================================="

# Check if Docker is running
if docker info > /dev/null 2>&1; then
    echo "✅ Docker is running"
    
    # Check container status
    echo ""
    echo "🐳 Container Status:"
    docker-compose ps 2>/dev/null || echo "   No containers running"
    
    # Check if web dashboard is accessible
    echo ""
    echo "🌐 Web Dashboard Status:"
    if curl -s http://localhost:8080/api/metrics > /dev/null 2>&1; then
        echo "✅ Dashboard is accessible at http://localhost:8080"
        
        # Get current metrics
        echo ""
        echo "📈 Current Metrics:"
        curl -s http://localhost:8080/api/metrics | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(f'   Total Messages: {data.get(\"total_messages\", 0)}')
    print(f'   Unique Keys: {data.get(\"unique_keys\", 0)}')
    print(f'   Compaction Ratio: {data.get(\"compaction_ratio\", 0):.1%}')
    print(f'   Storage Saved: {data.get(\"storage_saved_percent\", 0):.1f}%')
except:
    print('   Unable to parse metrics')
"
    else
        echo "❌ Dashboard is not accessible"
    fi
else
    echo "❌ Docker is not running"
fi

# Check Python environment
echo ""
echo "🐍 Python Environment:"
if command -v python3 &> /dev/null; then
    echo "✅ Python3 is available"
    if [ -d "venv" ]; then
        echo "✅ Virtual environment exists"
    else
        echo "⚠️  No virtual environment found"
    fi
else
    echo "❌ Python3 is not available"
fi

# Check dependencies
echo ""
echo "📦 Dependencies:"
if [ -f "requirements.txt" ]; then
    echo "✅ requirements.txt exists"
    if pip list | grep -q "confluent-kafka"; then
        echo "✅ Kafka dependencies installed"
    else
        echo "⚠️  Kafka dependencies not installed"
    fi
else
    echo "❌ requirements.txt not found"
fi

# Show available commands
echo ""
echo "🚀 Available Commands:"
echo "   Setup:     ./scripts/setup.sh"
echo "   Build:     ./scripts/build.sh"
echo "   Test:      ./scripts/test.sh"
echo "   Run Local: ./scripts/run.sh"
echo "   Run Docker: ./run_docker_demo.sh"
echo "   Cleanup:   ./scripts/cleanup.sh --all"
echo "   Status:    ./scripts/status.sh"
echo ""
echo "📊 Web Dashboard: http://localhost:8080"
echo "📋 Logs: docker-compose logs -f" 