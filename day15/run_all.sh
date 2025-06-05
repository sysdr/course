# JSON Log Processing System - Build and Test Instructions
# Day 15: Add JSON support for structured log data

# =====================================
# STEP 1: Project Setup
# =====================================

# Create project directory and navigate into it
mkdir day15-json-logs
cd day15-json-logs

# Create complete directory structure
mkdir -p src tests schemas docker frontend/{static,templates} logs test-results

# Expected Output:
# Directory structure created with all necessary folders

# =====================================
# STEP 2: Environment Setup
# =====================================

# Create Python virtual environment
python3 -m venv venv

# Activate virtual environment (Linux/Mac)
source venv/bin/activate

# For Windows users:
# venv\Scripts\activate

# Expected Output:
# (venv) prefix should appear in your terminal prompt

kill $(lsof -t -i:8080)
ill $(lsof -t -i:5000)

# Install dependencies
pip install jsonschema==4.17.3 flask==2.3.3 requests==2.31.0 pytest==7.4.0 colorama==0.4.6 websockets==11.0.3

# Expected Output:
# Successfully installed jsonschema-4.17.3 flask-2.3.3 requests-2.31.0 pytest-7.4.0 colorama-0.4.6 websockets-11.0.3

# =====================================
# STEP 3: Create Source Files
# =====================================

# Create all Python source files (copy content from previous artifacts)
# - src/schema_validator.py
# - src/json_processor.py
# - src/json_server.py
# - src/json_client.py
# - tests/test_json_processor.py
# - schemas/log_schema.json
# - frontend/app.py
# - frontend/templates/dashboard.html

# Set Python path for module imports
export PYTHONPATH="${PWD}/src:${PYTHONPATH}"

# =====================================
# STEP 4: Test Schema Validation
# =====================================

# Test the schema validator individually
cd src
python -c "
from schema_validator import SchemaValidator
import json

# Initialize validator
validator = SchemaValidator('../schemas')

# Test valid log
valid_log = {
    'timestamp': '2024-01-15T10:30:00Z',
    'level': 'INFO',
    'service': 'test-service',
    'message': 'Test message'
}

is_valid, error = validator.validate_log(valid_log, 'log_schema')
print(f'Valid log test: {is_valid}, Error: {error}')

# Test invalid log
invalid_log = {'level': 'INFO'}  # Missing required fields
is_valid, error = validator.validate_log(invalid_log, 'log_schema')
print(f'Invalid log test: {is_valid}, Error: {error}')

# Show statistics
stats = validator.get_validation_stats()
print(f'Validation stats: {stats}')
"

# Expected Output:
# ✓ Loaded schema: log_schema
# Valid log test: True, Error: None
# Invalid log test: False, Error: Validation failed: 'timestamp' is a required property
# Validation stats: {'total_validated': 2, 'valid_count': 1, 'invalid_count': 1, 'error_types': {'missing_required_field': 1}, 'success_rate_percent': 50.0}

# =====================================
# STEP 5: Test JSON Processor
# =====================================

# Test the JSON processor
python -c "
from json_processor import JSONLogProcessor
import json
import time

# Create processor
processor = JSONLogProcessor(max_workers=2)

# Add simple handlers
processed_logs = []
def handler(log): processed_logs.append(log)
processor.add_output_handler(handler)

# Start processor
processor.start()

# Submit test logs
valid_log = json.dumps({
    'timestamp': '2024-01-15T10:30:00Z',
    'level': 'INFO',
    'service': 'test-service',
    'message': 'Test message'
})

success = processor.submit_log(valid_log)
print(f'Log submission success: {success}')

# Wait for processing
time.sleep(1)

print(f'Processed logs count: {len(processed_logs)}')
if processed_logs:
    print(f'First processed log: {processed_logs[0]}')

# Get statistics
stats = processor.get_stats()
print(f'Processor stats: {stats}')

processor.stop()
"

# Expected Output:
# JSON Log Processor initialized with 2 workers
# Added output handler: handler
# ✓ JSON Log Processor started successfully
# Log submission success: True
# Processed logs count: 1
# First processed log: {'timestamp': '2024-01-15T10:30:00Z', 'level': 'INFO', 'service': 'test-service', 'message': 'Test message', 'processed_at': '2024-01-15T10:30:01.123456', 'validation_status': 'passed', 'metadata': {'processor_version': '1.0.0', 'validation_timestamp': '2024-01-15T10:30:01.123456'}}

# =====================================
# STEP 6: Run Unit Tests
# =====================================

cd ..  # Back to project root
python -m pytest tests/ -v --tb=short

# Expected Output:
# ======================== test session starts ========================
# tests/test_json_processor.py::TestSchemaValidator::test_valid_log_passes_validation PASSED
# tests/test_json_processor.py::TestSchemaValidator::test_missing_required_field_fails_validation PASSED
# tests/test_json_processor.py::TestSchemaValidator::test_invalid_enum_value_fails_validation PASSED
# tests/test_json_processor.py::TestJSONLogProcessor::test_valid_json_log_processing PASSED
# tests/test_json_processor.py::TestIntegration::test_client_server_communication PASSED
# ======================== X passed in Y.YYs ========================

# =====================================
# STEP 7: Test Server Individually
# =====================================

# Start the JSON server (in background)
python src/json_server.py &
SERVER_PID=$!

# Wait for server to start
sleep 2

# Test server connectivity
echo "Testing server connectivity..."
nc -z localhost 8080 && echo "✅ Server is listening on port 8080" || echo "❌ Server connection failed"

# Send test data using netcat (if available)
if command -v nc >/dev/null 2>&1; then
    echo '{"timestamp":"2024-01-15T10:30:00Z","level":"INFO","service":"test","message":"Hello from netcat"}' | nc localhost 8080
    echo "✅ Test message sent to server"
fi

# Expected Output:
# JSON Log Server initialized on localhost:8080
# ✓ Loaded schema: log_schema
# Added output handler: console_output_handler
# Added error handler: console_error_handler
# JSON Log Processor initialized with 4 workers
# ✓ JSON Log Processor started successfully
# ✓ JSON Log Server listening on localhost:8080
# ✅ Server is listening on port 8080
# New connection from ('127.0.0.1', XXXXX)
# [2024-01-15T10:30:00Z] test INFO: Hello from netcat

# Stop the server
kill $SERVER_PID

# =====================================
# STEP 8: Test Client Individually
# =====================================

# Start server again for client testing
python src/json_server.py &
SERVER_PID=$!
sleep 2

# Run client test
python -c "
from src.json_client import JSONLogClient
import time

# Create client
client = JSONLogClient('localhost', 8080)

# Connect to server
if client.connect():
    print('✅ Client connected successfully')
    
    # Send sample logs
    for i in range(3):
        log = client.generate_sample_log()
        success = client.send_log(log)
        print(f'Log {i+1} sent: {success}')
        time.sleep(0.5)
    
    # Get statistics
    stats = client.get_stats()
    print(f'Client stats: {stats}')
    
    client.disconnect()
else:
    print('❌ Client connection failed')
"

# Expected Output:
# JSON Log Client initialized for localhost:8080
# ✅ Connected to log server at localhost:8080
# ✅ Client connected successfully
# Log 1 sent: True
# Log 2 sent: True
# Log 3 sent: True
# Client stats: {'logs_sent': 3, 'bytes_sent': XXX, 'connection_errors': 0, 'send_errors': 0, ...}
# Disconnected from log server

kill $SERVER_PID

# =====================================
# STEP 9: Test Web Dashboard
# =====================================

# Start the web dashboard
python frontend/app.py &
DASHBOARD_PID=$!
sleep 3

# Test dashboard API
curl -s http://localhost:5000/api/dashboard-data | python -m json.tool

# Expected Output:
# {
#   "stats": {
#     "total_logs": 50,
#     "valid_logs": 45,
#     "invalid_logs": 5,
#     "error_rate": 10.0,
#     ...
#   },
#   "recent_logs": [...],
#   "log_level_distribution": {...},
#   ...
# }

# Test health endpoint
curl -s http://localhost:5000/health

# Expected Output:
# {"status":"healthy","timestamp":"2024-01-15T10:30:00.123456","service":"json-log-dashboard"}

kill $DASHBOARD_PID

# =====================================
# STEP 10: Integration Test
# =====================================

echo "Running full integration test..."

# Start all services
python src/json_server.py &
SERVER_PID=$!

python frontend/app.py &
DASHBOARD_PID=$!

sleep 3

# Run client simulation
python -c "
from src.json_client import JSONLogClient
import time

client = JSONLogClient('localhost', 8080)
if client.connect():
    print('Running integration test...')
    client.simulate_application_traffic(duration_seconds=20, logs_per_second=2.0)
    client.disconnect()
    print('✅ Integration test completed')
"

# Check dashboard data after simulation
echo "Checking dashboard data..."
curl -s http://localhost:5000/api/dashboard-data | python -c "
import json, sys
data = json.load(sys.stdin)
print(f'Total logs processed: {data[\"stats\"][\"total_logs\"]}')
print(f'Success rate: {100 - data[\"stats\"][\"error_rate\"]:.1f}%')
"

# Expected Output:
# Running integration test...
# Simulating application traffic for 20 seconds at 2.0 logs/sec
# ✅ Integration test completed
# Total logs processed: XX
# Success rate: XX.X%

# Clean up
kill $SERVER_PID $DASHBOARD_PID
wait

# =====================================
# STEP 11: Docker Build and Test
# =====================================

# Build Docker image
docker build -t json-log-processor -f docker/Dockerfile .

# Expected Output:
# Successfully built json-log-processor
# Successfully tagged json-log-processor:latest

# Test Docker container
docker run --rm -d --name test-container -p 8081:8080 json-log-processor

# Wait for container to start
sleep 5

# Test container
curl -s http://localhost:8081 >/dev/null && echo "✅ Docker container is responding" || echo "❌ Docker container test failed"

# Stop test container
docker stop test-container

# =====================================
# STEP 12: Docker Compose Test
# =====================================

# Start all services with Docker Compose
docker-compose up -d

# Expected Output:
# Creating network "day15-json-logs_log-network" with driver "bridge"
# Creating json-log-server ... done
# Creating json-log-frontend ... done

# Check service status
docker-compose ps

# Expected Output:
# Name                State         Ports
# json-log-server     Up           0.0.0.0:8080->8080/tcp
# json-log-frontend   Up           0.0.0.0:5000->5000/tcp

# Test services
curl -s http://localhost:8080 >/dev/null && echo "✅ Server container working"
curl -s http://localhost:5000 >/dev/null && echo "✅ Frontend container working"

# View logs
docker-compose logs --tail=10

# Stop all services
docker-compose down

# Expected Output:
# Stopping json-log-frontend ... done
# Stopping json-log-server ... done
# Removing json-log-frontend ... done
# Removing json-log-server ... done
# Removing network day15-json-logs_log-network

echo "🎉 All tests completed successfully!"
