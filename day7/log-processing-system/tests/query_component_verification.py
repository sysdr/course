#!/usr/bin/env bash
# query_component_verification.sh - Command-line tests for the Query component

# Set error handling
set -e
set -o pipefail

# Setup test environment
echo "Setting up test environment for Query component verification..."
TEST_DIR="./query_test_$(date +%s)"
mkdir -p "$TEST_DIR"
mkdir -p "$TEST_DIR/storage/active"
mkdir -p "$TEST_DIR/storage/index/level"
mkdir -p "$TEST_DIR/storage/index/source"
mkdir -p "$TEST_DIR/logs"

# Cleanup function
cleanup() {
    echo "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
}

# Register cleanup on exit
trap cleanup EXIT

# Create sample stored logs
echo "Creating sample stored logs..."

# Log 1: INFO level, auth_service
cat > "$TEST_DIR/storage/active/log_001.json" << EOF
{
    "log_id": "log_001",
    "timestamp": "2023-09-25T14:23:11",
    "level": "INFO",
    "message": "User login successful for user123",
    "source": "auth_service",
    "ip": "192.168.1.1",
    "user_id": "user123",
    "storage_timestamp": $(date +%s)
}
EOF

# Log 2: ERROR level, db_service
cat > "$TEST_DIR/storage/active/log_002.json" << EOF
{
    "log_id": "log_002",
    "timestamp": "2023-09-25T14:24:11",
    "level": "ERROR",
    "message": "Database connection failed",
    "source": "db_service",
    "error_code": "DB_CONN_001",
    "storage_timestamp": $(date +%s)
}
EOF

# Log 3: WARN level, monitor_service
cat > "$TEST_DIR/storage/active/log_003.json" << EOF
{
    "log_id": "log_003",
    "timestamp": "2023-09-25T14:25:11",
    "level": "WARN",
    "message": "High memory usage detected",
    "source": "monitor_service",
    "memory_usage": "85%",
    "storage_timestamp": $(date +%s)
}
EOF

# Log 4: INFO level, api_service
cat > "$TEST_DIR/storage/active/log_004.json" << EOF
{
    "log_id": "log_004",
    "timestamp": "2023-09-25T14:26:11",
    "level": "INFO",
    "message": "API request processed",
    "source": "api_service",
    "endpoint": "/users",
    "method": "GET",
    "response_time": 120,
    "storage_timestamp": $(date +%s)
}
EOF

# Log 5: ERROR level, auth_service
cat > "$TEST_DIR/storage/active/log_005.json" << EOF
{
    "log_id": "log_005",
    "timestamp": "2023-09-25T14:27:11",
    "level": "ERROR",
    "message": "User login failed for user456",
    "source": "auth_service",
    "ip": "192.168.1.2",
    "user_id": "user456",
    "reason": "Invalid password",
    "storage_timestamp": $(date +%s)
}
EOF

# Create index files
echo "Creating index files..."

# Level index: INFO
cat > "$TEST_DIR/storage/index/level/INFO" << EOF
log_001
log_004
EOF

# Level index: ERROR
cat > "$TEST_DIR/storage/index/level/ERROR" << EOF
log_002
log_005
EOF

# Level index: WARN
cat > "$TEST_DIR/storage/index/level/WARN" << EOF
log_003
EOF

# Source index: auth_service
cat > "$TEST_DIR/storage/index/source/auth_service" << EOF
log_001
log_005
EOF

# Source index: db_service
cat > "$TEST_DIR/storage/index/source/db_service" << EOF
log_002
EOF

# Source index: monitor_service
cat > "$TEST_DIR/storage/index/source/monitor_service" << EOF
log_003
EOF

# Source index: api_service
cat > "$TEST_DIR/storage/index/source/api_service" << EOF
log_004
EOF

# ==========================================================
# Test 1: Pattern Search Functionality
# ==========================================================
echo -e "\n=== Test 1: Pattern Search Functionality ==="
echo "Testing pattern search..."

# Search for logs containing 'login'
SEARCH_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --pattern "login")

# Count results
RESULT_COUNT=$(echo "$SEARCH_RESULT" | grep -c "log_00")

if [ "$RESULT_COUNT" -ne 2 ]; then
    echo "FAILURE: Expected 2 logs matching 'login', found $RESULT_COUNT"
    echo "$SEARCH_RESULT"
    exit 1
fi

# Verify specific log IDs
if ! echo "$SEARCH_RESULT" | grep -q "log_001" || ! echo "$SEARCH_RESULT" | grep -q "log_005"; then
    echo "FAILURE: Expected logs 001 and 005 in results"
    echo "$SEARCH_RESULT"
    exit 1
fi

echo "✓ Pattern search test passed."

# ==========================================================
# Test 2: Index Search Functionality
# ==========================================================
echo -e "\n=== Test 2: Index Search Functionality ==="
echo "Testing index search..."

# Search by level: ERROR
LEVEL_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --index-type level --index-value ERROR)

# Count results
LEVEL_COUNT=$(echo "$LEVEL_RESULT" | grep -c "log_00")

if [ "$LEVEL_COUNT" -ne 2 ]; then
    echo "FAILURE: Expected 2 ERROR logs, found $LEVEL_COUNT"
    echo "$LEVEL_RESULT"
    exit 1
fi

# Verify specific log IDs
if ! echo "$LEVEL_RESULT" | grep -q "log_002" || ! echo "$LEVEL_RESULT" | grep -q "log_005"; then
    echo "FAILURE: Expected logs 002 and 005 in ERROR results"
    echo "$LEVEL_RESULT"
    exit 1
fi

# Search by source: auth_service
SOURCE_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --index-type source --index-value auth_service)

# Count results
SOURCE_COUNT=$(echo "$SOURCE_RESULT" | grep -c "log_00")

if [ "$SOURCE_COUNT" -ne 2 ]; then
    echo "FAILURE: Expected 2 auth_service logs, found $SOURCE_COUNT"
    echo "$SOURCE_RESULT"
    exit 1
fi

# Verify specific log IDs
if ! echo "$SOURCE_RESULT" | grep -q "log_001" || ! echo "$SOURCE_RESULT" | grep -q "log_005"; then
    echo "FAILURE: Expected logs 001 and 005 in auth_service results"
    echo "$SOURCE_RESULT"
    exit 1
fi

echo "✓ Index search test passed."

# ==========================================================
# Test 3: Time Range Search Functionality
# ==========================================================
echo -e "\n=== Test 3: Time Range Search Functionality ==="
echo "Testing time range search..."

# Search by time range
TIME_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --start-time "2023-09-25T14:24:00" --end-time "2023-09-25T14:26:00")

# Count results
TIME_COUNT=$(echo "$TIME_RESULT" | grep -c "log_00")

if [ "$TIME_COUNT" -ne 2 ]; then
    echo "FAILURE: Expected 2 logs in time range, found $TIME_COUNT"
    echo "$TIME_RESULT"
    exit 1
fi

# Verify specific log IDs
if ! echo "$TIME_RESULT" | grep -q "log_002" || ! echo "$TIME_RESULT" | grep -q "log_003"; then
    echo "FAILURE: Expected logs 002 and 003 in time range results"
    echo "$TIME_RESULT"
    exit 1
fi

echo "✓ Time range search test passed."

# ==========================================================
# Test 4: Combined Search Functionality
# ==========================================================
echo -e "\n=== Test 4: Combined Search Functionality ==="
echo "Testing combined search criteria..."

# Combined search: ERROR logs from auth_service
COMBINED_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --index-type level --index-value ERROR --pattern "auth_service")

# Count results
COMBINED_COUNT=$(echo "$COMBINED_RESULT" | grep -c "log_00")

if [ "$COMBINED_COUNT" -ne 1 ]; then
    echo "FAILURE: Expected 1 log matching combined criteria, found $COMBINED_COUNT"
    echo "$COMBINED_RESULT"
    exit 1
fi

# Verify specific log ID
if ! echo "$COMBINED_RESULT" | grep -q "log_005"; then
    echo "FAILURE: Expected log 005 in combined search results"
    echo "$COMBINED_RESULT"
    exit 1
fi

echo "✓ Combined search test passed."

# ==========================================================
# Test 5: Output Format Functionality
# ==========================================================
echo -e "\n=== Test 5: Output Format Functionality ==="
echo "Testing output formats..."

# Test JSON format
JSON_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --pattern "login" --format json)

# Verify JSON is valid
echo "$JSON_RESULT" > "$TEST_DIR/result.json"
if ! jq '.' "$TEST_DIR/result.json" > /dev/null 2>&1; then
    echo "FAILURE: Invalid JSON output"
    cat "$TEST_DIR/result.json"
    exit 1
fi

# Test CSV format
CSV_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --pattern "login" --format csv)

# Verify CSV structure
if ! echo "$CSV_RESULT" | grep -q "^log_id,timestamp,"; then
    echo "FAILURE: CSV output doesn't have expected headers"
    echo "$CSV_RESULT"
    exit 1
fi

# Count CSV rows (headers + 2 data rows)
CSV_LINES=$(echo "$CSV_RESULT" | wc -l)
if [ "$CSV_LINES" -ne 3 ]; then
    echo "FAILURE: Expected 3 lines in CSV output (header + 2 data rows), found $CSV_LINES"
    echo "$CSV_RESULT"
    exit 1
fi

echo "✓ Output format test passed."

# ==========================================================
# Test 6: Aggregation Functionality
# ==========================================================
echo -e "\n=== Test 6: Aggregation Functionality ==="
echo "Testing log aggregation..."

# Aggregate by level
LEVEL_AGG_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --aggregate level)

# Verify counts
if ! echo "$LEVEL_AGG_RESULT" | grep -q "INFO: 2" || \
   ! echo "$LEVEL_AGG_RESULT" | grep -q "ERROR: 2" || \
   ! echo "$LEVEL_AGG_RESULT" | grep -q "WARN: 1"; then
    echo "FAILURE: Level aggregation doesn't show expected counts"
    echo "$LEVEL_AGG_RESULT"
    exit 1
fi

# Aggregate by source
SOURCE_AGG_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --aggregate source)

# Verify counts
if ! echo "$SOURCE_AGG_RESULT" | grep -q "auth_service: 2" || \
   ! echo "$SOURCE_AGG_RESULT" | grep -q "db_service: 1" || \
   ! echo "$SOURCE_AGG_RESULT" | grep -q "monitor_service: 1" || \
   ! echo "$SOURCE_AGG_RESULT" | grep -q "api_service: 1"; then
    echo "FAILURE: Source aggregation doesn't show expected counts"
    echo "$SOURCE_AGG_RESULT"
    exit 1
fi

echo "✓ Aggregation test passed."

# ==========================================================
# Test 7: Error Handling
# ==========================================================
echo -e "\n=== Test 7: Error Handling ==="
echo "Testing error handling..."

# Test case 1: Non-existent storage directory
NON_EXISTENT_RESULT=$(python query.py --storage-dir "$TEST_DIR/non_existent" --pattern "login" 2>&1 || true)

if ! echo "$NON_EXISTENT_RESULT" | grep -q "Error"; then
    echo "FAILURE: Expected error message for non-existent storage directory"
    echo "$NON_EXISTENT_RESULT"
    exit 1
fi

# Test case 2: Invalid index type
INVALID_INDEX_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --index-type invalid_index --index-value test 2>&1 || true)

if ! echo "$INVALID_INDEX_RESULT" | grep -q "No logs found" || \
   ! echo "$INVALID_INDEX_RESULT" | grep -q "invalid_index"; then
    echo "FAILURE: Expected proper handling of invalid index type"
    echo "$INVALID_INDEX_RESULT"
    exit 1
fi

# Test case 3: Invalid time format
INVALID_TIME_RESULT=$(python query.py --storage-dir "$TEST_DIR/storage" --start-time "invalid-time" --end-time "2023-09-25T14:26:00" 2>&1 || true)

if ! echo "$INVALID_TIME_RESULT" | grep -q "Error"; then
    echo "FAILURE: Expected error message for invalid time format"
    echo "$INVALID_TIME_RESULT"
    exit 1
fi

echo "✓ Error handling test passed."

# ==========================================================
# Test 8: Performance Test
# ==========================================================
echo -e "\n=== Test 8: Performance Test ==="
echo "Setting up performance test..."

# Create many logs for performance testing
mkdir -p "$TEST_DIR/perf_storage/active"
mkdir -p "$TEST_DIR/perf_storage/index/level"

for i in {1..1000}; do
    # Every 100th log contains "FINDME"
    if [ $((i % 100)) -eq 0 ]; then
        MESSAGE="Performance test log $i FINDME"
    else
        MESSAGE="Performance test log $i"
    fi
    
    # Create log with random level
    LEVEL=("INFO" "ERROR" "WARN" "DEBUG")
    RANDOM_LEVEL=${LEVEL[$((RANDOM % 4))]}
    
    cat > "$TEST_DIR/perf_storage/active/perf_log_$i.json" << EOF
{
    "log_id": "perf_log_$i",
    "timestamp": "2023-09-25T$(printf "%02d" $((i / 60))):$(printf "%02d" $((i % 60))):00",
    "level": "$RANDOM_LEVEL",
    "message": "$MESSAGE",
    "source": "perf_service_$(( i % 10 ))",
    "storage_timestamp": $(date +%s)
}
EOF
done

# Create level indexes
for LEVEL in "INFO" "ERROR" "WARN" "DEBUG"; do
    # Find all logs with this level
    grep -l "\"level\": \"$LEVEL\"" "$TEST_DIR/perf_storage/active"/*.json | sed 's|.*/\(.*\)\.json|\1|' > "$TEST_DIR/perf_storage/index/level/$LEVEL"
done

echo "Running performance test..."

# Measure time for pattern search
START_TIME=$(date +%s.%N)
PERF_RESULT=$(python query.py --storage-dir "$TEST_DIR/perf_storage" --pattern "FINDME")
END_TIME=$(date +%s.%N)

# Calculate execution time
EXECUTION_TIME=$(echo "$END_TIME - $START_TIME" | bc)

echo "Pattern search on 1000 logs took $EXECUTION_TIME seconds"

# Count results
PERF_COUNT=$(echo "$PERF_RESULT" | grep -c "perf_log_")

if [ "$PERF_COUNT" -ne 10 ]; then
    echo "FAILURE: Expected 10 logs containing 'FINDME', found $PERF_COUNT"
    exit 1
fi

# Check if performance is reasonable (under 2 seconds)
if (( $(echo "$EXECUTION_TIME > 2.0" | bc -l) )); then
    echo "WARNING: Performance may be suboptimal - took $EXECUTION_TIME seconds"
else
    echo "✓ Performance test passed."
fi

# ==========================================================
# Final Result
# ==========================================================
echo -e "\n=== ALL QUERY COMPONENT TESTS PASSED ==="
echo "Query component functionality verified successfully."