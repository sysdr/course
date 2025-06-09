#!/bin/bash
# verify_system.sh - Working verification script

set -e

echo "🚀 DISTRIBUTED LOG SYSTEM - WEEK 2 VERIFICATION"
echo "=============================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_TOTAL=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "\n${YELLOW}TEST ${TESTS_TOTAL}: ${test_name}${NC}"
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

cleanup() {
    echo "🧹 Cleaning up..."
    pkill -f "python.*tcp_server.py" 2>/dev/null || true
    pkill -f "python.*server.py" 2>/dev/null || true
    sleep 1
}

trap cleanup EXIT

echo "📋 STEP 1: Project Setup"
echo "========================"

# Create project structure
mkdir -p {src,tests,certs,logs,results}

# Create source files if they don't exist
cat > src/__init__.py << 'EOF'
# Empty init file
EOF

# Install requirements
if command -v pip3 &> /dev/null; then
    pip3 install pytest pytest-asyncio psutil >/dev/null 2>&1 || echo "Note: Some packages may not install"
else
    echo "Warning: pip3 not found"
fi

# Generate certificates
if [ ! -f "certs/server.crt" ]; then
    echo "Generating TLS certificates..."
    mkdir -p certs
    openssl req -x509 -newkey rsa:2048 -keyout certs/server.key -out certs/server.crt -days 365 -nodes -subj "/CN=localhost" 2>/dev/null || echo "Warning: Certificate generation failed"
fi

echo ""
echo "📋 STEP 2: Source Code Verification"
echo "=================================="

run_test "TCP Server syntax check" "python3 -m py_compile src/tcp_server.py"
run_test "Log Shipper syntax check" "python3 -m py_compile src/log_shipper.py"  
run_test "Load Generator syntax check" "python3 -m py_compile src/load_generator.py"

echo ""
echo "📋 STEP 3: Unit Tests"
echo "===================="

if [ -f "tests/test_load_generator.py" ]; then
    run_test "Unit tests execution" "cd $(pwd) && python3 -m pytest tests/test_load_generator.py::test_log_generation -v"
else
    echo "⚠️  Unit tests not found, skipping"
fi

echo ""
echo "📋 STEP 4: Server Startup Test"
echo "=============================="

# Test server can start
echo "Testing server startup..."
python3 src/tcp_server.py --no-tls > server_test.log 2>&1 &
SERVER_PID=$!
sleep 3

if ps -p $SERVER_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Server started successfully${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ Server failed to start${NC}"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test basic connectivity
if command -v nc &> /dev/null; then
    run_test "Server connectivity" "timeout 2 nc -z localhost 8888"
elif command -v telnet &> /dev/null; then
    run_test "Server connectivity" "timeout 2 bash -c 'echo | telnet localhost 8888' 2>/dev/null"
else
    echo "⚠️  Neither nc nor telnet available, skipping connectivity test"
fi

echo ""
echo "📋 STEP 5: Load Test"
echo "==================="

# Run a simple load test
run_test "Basic load test (50 RPS, 5s)" "timeout 10 python3 src/load_generator.py 50 5 2"

# Stop server
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

echo ""
echo "📋 STEP 6: Integration Test" 
echo "=========================="

# Start fresh server for integration test
python3 src/tcp_server.py --no-tls > server_integration.log 2>&1 &
INT_SERVER_PID=$!
sleep 2

if ps -p $INT_SERVER_PID > /dev/null 2>&1; then
    # Run log shipper test
    python3 -c "
import asyncio
import sys
import os
sys.path.insert(0, 'src')
from log_shipper import LogShipper

async def test():
    shipper = LogShipper(use_tls=False, batch_size=5)
    if await shipper.start():
        for i in range(5):
            await shipper.ship_log({'test': f'message {i}'})
        await asyncio.sleep(1)
        await shipper.close()
        print('Integration test completed')
        return True
    return False

try:
    result = asyncio.run(test())
    exit(0 if result else 1)
except Exception as e:
    print(f'Integration test failed: {e}')
    exit(1)
" && echo -e "${GREEN}✅ Integration test passed${NC}" || echo -e "${RED}❌ Integration test failed${NC}"

    if [ $? -eq 0 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
else
    echo -e "${RED}❌ Server not running for integration test${NC}"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Cleanup integration server
kill $INT_SERVER_PID 2>/dev/null || true
wait $INT_SERVER_PID 2>/dev/null || true

echo ""
echo "📋 STEP 7: Benchmark Test"
echo "========================"

# Start server for benchmark
python3 src/tcp_server.py --no-tls > server_benchmark.log 2>&1 &
BENCH_SERVER_PID=$!
sleep 2

if ps -p $BENCH_SERVER_PID > /dev/null 2>&1; then
    run_test "Benchmark suite execution" "timeout 60 python3 src/benchmark.py"
else
    echo -e "${RED}❌ Server not running for benchmark${NC}"
fi

# Cleanup benchmark server
kill $BENCH_SERVER_PID 2>/dev/null || true
wait $BENCH_SERVER_PID 2>/dev/null || true

echo ""
echo "📋 STEP 8: Output Verification"
echo "============================="

# Check for output files
if [ -f "benchmark_results.json" ]; then
    run_test "Benchmark results file exists" "test -s benchmark_results.json"
    
    # Validate JSON format
    if python3 -c "import json; json.load(open('benchmark_results.json'))" 2>/dev/null; then
        echo -e "${GREEN}✅ Benchmark JSON valid${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ Invalid benchmark JSON${NC}"
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
else
    echo "⚠️  No benchmark results found"
fi

# Check for benchmark report
if ls benchmark_report_*.json >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Benchmark report generated${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
else
    echo "⚠️  No benchmark report found"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
fi

echo ""
echo "📋 STEP 9: Docker Verification"
echo "=============================="

if command -v docker &> /dev/null; then
    if [ -f "docker-compose.yml" ]; then
        run_test "Docker compose config validation" "docker-compose config -q"
    else
        echo "⚠️  docker-compose.yml not found"
    fi
else
    echo "⚠️  Docker not available, skipping container tests"
fi

echo ""
echo "🎯 FINAL RESULTS"
echo "================"
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}/${TESTS_TOTAL}"

# Calculate success percentage
SUCCESS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))

if [ $SUCCESS_RATE -ge 80 ]; then
    echo -e "${GREEN}🎉 SYSTEM WORKING! ($SUCCESS_RATE% tests passed)${NC}"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Start server: python3 src/tcp_server.py --no-tls"
    echo "   2. Run load test: python3 src/load_generator.py 100 10 3"
    echo "   3. Check results: cat benchmark_results.json"
    echo "   4. Try optimization challenge for 1000+ RPS"
    exit 0
else
    echo -e "${RED}⚠️  Some issues found ($SUCCESS_RATE% success rate)${NC}"
    echo "Check the output above for details."
    exit 1
fi