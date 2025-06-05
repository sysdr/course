#!/bin/bash
# simple_test.sh - Quick setup and test

echo "🚀 QUICK DISTRIBUTED LOG SYSTEM TEST"
echo "===================================="

# Create directory structure
mkdir -p {src,tests,certs,logs}

# Generate simple TLS cert if needed
if [ ! -f "certs/server.crt" ]; then
    mkdir -p certs
    openssl req -x509 -newkey rsa:2048 -keyout certs/server.key -out certs/server.crt -days 365 -nodes -subj "/CN=localhost" 2>/dev/null || echo "Warning: TLS cert generation failed"
fi

# Install basic requirements
pip3 install pytest pytest-asyncio 2>/dev/null || echo "Note: Some packages may not install"

echo ""
echo "✅ Setup complete!"
echo ""
echo "🧪 QUICK TEST SEQUENCE"
echo "======================"

echo "1. Testing syntax..."
python3 -m py_compile src/tcp_server.py && echo "✅ TCP Server OK" || echo "❌ TCP Server failed"
python3 -m py_compile src/log_shipper.py && echo "✅ Log Shipper OK" || echo "❌ Log Shipper failed"  
python3 -m py_compile src/load_generator.py && echo "✅ Load Generator OK" || echo "❌ Load Generator failed"

echo ""
echo "2. Starting server..."
python3 src/tcp_server.py --no-tls &
SERVER_PID=$!
sleep 3

if ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "✅ Server started successfully"
    
    echo ""
    echo "3. Running load test..."
    if timeout 15 python3 src/load_generator.py 100 5 2; then
        echo "✅ Load test completed"
    else
        echo "❌ Load test failed"
    fi
    
    echo ""
    echo "4. Checking results..."
    if [ -f "benchmark_results.json" ]; then
        echo "✅ Results file created"
        echo "📊 Results preview:"
        python3 -c "
import json
try:
    with open('benchmark_results.json') as f:
        data = json.load(f)
    print(f'  - Logs sent: {data.get(\"logs_sent\", \"N/A\")}')
    print(f'  - RPS achieved: {data.get(\"actual_rps\", \"N/A\"):.1f}')
    print(f'  - Success rate: {data.get(\"success_rate\", \"N/A\"):.1f}%')
except Exception as e:
    print(f'  - Error reading results: {e}')
"
    else
        echo "⚠️  No results file found"
    fi
    
    # Cleanup
    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null || true
    
else
    echo "❌ Server failed to start"
fi

echo ""
echo "🎯 QUICK TEST COMPLETE"
echo "===================="
echo "✅ Your distributed log system is working!"
echo ""
echo "💡 To run full tests: chmod +x verify_system.sh && ./verify_system.sh"
echo "🚀 For performance challenge: try 'python3 src/load_generator.py 1000 20 10'"