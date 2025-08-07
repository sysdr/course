#!/bin/bash

set -e

echo "🎬 Multi-Language SDK Demo"
echo "=========================="

# Check if API server is running
if ! curl -s http://localhost:8000/api/v1/health > /dev/null 2>&1; then
    echo "🌐 Starting API server..."
    source api-env/bin/activate
    python api-server/src/main.py &
    API_PID=$!
    
    # Wait for server to start
    echo "⏳ Waiting for API server to start..."
    for i in {1..30}; do
        if curl -s http://localhost:8000/api/v1/health > /dev/null 2>&1; then
            echo "✅ API server started successfully"
            break
        fi
        sleep 1
    done
    
    if [ $i -eq 30 ]; then
        echo "❌ Failed to start API server"
        exit 1
    fi
else
    echo "✅ API server already running"
    API_PID=""
fi

echo ""
echo "🐍 Running Python SDK demo..."
cd python-sdk
source venv/bin/activate
python examples/example_usage.py
cd ..

if command -v mvn &> /dev/null && [ -f java-sdk/pom.xml ]; then
    echo ""
    echo "☕ Running Java SDK demo..."
    cd java-sdk
    timeout 30s mvn -q exec:java -Dexec.mainClass="ExampleUsage" -Dexec.args="" || echo "⏰ Java demo timeout"
    cd ..
fi

if command -v node &> /dev/null && [ -f javascript-sdk/dist/index.js ]; then
    echo ""
    echo "🟨 Running JavaScript SDK demo..."
    cd javascript-sdk
    timeout 30s node examples/example-usage.js || echo "⏰ JavaScript demo timeout"
    cd ..
fi

echo ""
echo "🎉 Demo completed! Check the dashboard at: http://localhost:8000"

# Clean up if we started the server
if [ ! -z "$API_PID" ]; then
    echo "🛑 Stopping API server..."
    kill $API_PID 2>/dev/null || true
fi
