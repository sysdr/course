#!/usr/bin/env bash
# storage_component_verification.sh - Command-line tests for the Storage component

# Set error handling
set -e
set -o pipefail

# Setup test environment
echo "Setting up test environment for Storage component verification..."
TEST_DIR="./storage_test_$(date +%s)"
mkdir -p "$TEST_DIR"
mkdir -p "$TEST_DIR/input"
mkdir -p "$TEST_DIR/logs"

# Cleanup function
cleanup() {
    echo "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
}

# Register cleanup on exit
trap cleanup EXIT

# Create sample parsed log data
echo "Creating sample parsed log data..."
cat > "$TEST_DIR/input/sample1.json" << EOF
{"timestamp": "2023-09-25T14:23:11", "level": "INFO", "message": "Server started", "source": "app_server"}
EOF

cat > "$TEST_DIR/input/sample2.json" << EOF
{"timestamp": "2023-09-25T14:24:11", "level": "ERROR", "message": "Connection refused", "source": "app_server"}
EOF

cat > "$TEST_DIR/input/sample3.json" << EOF
{"timestamp": "2023-09-25T14:25:11", "level": "WARN", "message": "High CPU usage", "source": "monitoring"}
EOF

# ==========================================================
# Test 1: Basic Storage Functionality
# ==========================================================
echo -e "\n=== Test 1: Basic Storage Functionality ==="
echo "Running storage component with sample log data..."

# Run storage component
python storage.py --input-dir "$TEST_DIR/input" --storage-dir "$TEST_DIR/storage"

# Verify logs are stored
echo "Verifying logs are stored properly..."
if [ ! -d "$TEST_DIR/storage/active" ]; then
    echo "FAILURE: Active storage directory not created"
    exit 1
fi

# Count stored logs
LOG_COUNT=$(ls -1 "$TEST_DIR/storage/active" | wc -l)
if [ "$LOG_COUNT" -ne 3 ]; then
    echo "FAILURE: Expected 3 stored logs, found $LOG_COUNT"
    exit 1
fi

echo "✓ Basic storage functionality test passed."

# ==========================================================
# Test 2: Log Indexing Functionality
# ==========================================================
echo -e "\n=== Test 2: Log Indexing Functionality ==="
echo "Verifying indexes are created..."

# Check if index directory exists
if [ ! -d "$TEST_DIR/storage/index" ]; then
    echo "FAILURE: Index directory not created"
    exit 1
fi

# Check level index
if [ ! -d "$TEST_DIR/storage/index/level" ]; then
    echo "FAILURE: Level index not created"
    exit 1
fi

# Check that level index files exist
if [ ! -f "$TEST_DIR/storage/index/level/INFO" ] || [ ! -f "$TEST_DIR/storage/index/level/ERROR" ] || [ ! -f "$TEST_DIR/storage/index/level/WARN" ]; then
    echo "FAILURE: Missing level index files"
    exit 1
fi

# Check source index
if [ ! -d "$TEST_DIR/storage/index/source" ]; then
    echo "FAILURE: Source index not created"
    exit 1
fi

# Check that source index files exist
if [ ! -f "$TEST_DIR/storage/index/source/app_server" ] || [ ! -f "$TEST_DIR/storage/index/source/monitoring" ]; then
    echo "FAILURE: Missing source index files"
    exit 1
fi

echo "✓ Log indexing functionality test passed."

# ==========================================================
# Test 3: Log Rotation Functionality
# ==========================================================
echo -e "\n=== Test 3: Log Rotation Functionality ==="
echo "Testing log rotation..."

# Create many more logs to trigger rotation
echo "Creating additional logs to trigger rotation..."
for i in {1..50}; do
    cat > "$TEST_DIR/input/large_$i.json" << EOF
{"timestamp": "2023-09-25T15:${i}:00", "level": "INFO", "message": "$(head -c 1000 /dev/urandom | base64)", "source": "bulk_generator"}
EOF
done

# Run storage with small rotation threshold
echo "Running storage with small rotation threshold..."
python storage.py --input-dir "$TEST_DIR/input" --storage-dir "$TEST_DIR/storage" --rotation-size 0.01

# Check if archive directory contains rotated logs
if [ ! -d "$TEST_DIR/storage/archive" ]; then
    echo "FAILURE: Archive directory not created during rotation"
    exit 1
fi

# Count archived files
ARCHIVE_COUNT=$(ls -1 "$TEST_DIR/storage/archive" | wc -l)
if [ "$ARCHIVE_COUNT" -eq 0 ]; then
    echo "FAILURE: No log files were rotated"
    exit 1
fi

echo "✓ Log rotation functionality test passed. Found $ARCHIVE_COUNT archived file(s)."

# ==========================================================
# Test 4: Storage Metadata Integrity
# ==========================================================
echo -e "\n=== Test 4: Storage Metadata Integrity ==="
echo "Verifying log metadata integrity..."

# Get a sample log file
SAMPLE_LOG=$(ls -1 "$TEST_DIR/storage/active" | head -1)

# Check for required metadata fields
echo "Checking metadata fields in $SAMPLE_LOG..."
jq '.' "$TEST_DIR/storage/active/$SAMPLE_LOG" > "$TEST_DIR/log_content.json"

MISSING_FIELDS=0
for field in "log_id" "storage_timestamp"; do
    if ! grep -q "$field" "$TEST_DIR/log_content.json"; then
        echo "FAILURE: Missing required metadata field: $field"
        MISSING_FIELDS=$((MISSING_FIELDS + 1))
    fi
done

if [ "$MISSING_FIELDS" -ne 0 ]; then
    echo "FAILURE: Log metadata is incomplete"
    exit 1
fi

echo "✓ Storage metadata integrity test passed."

# ==========================================================
# Test 5: Edge Cases
# ==========================================================
echo -e "\n=== Test 5: Edge Cases ==="

# Test case 1: Empty input
echo "Testing storage with empty input..."
mkdir -p "$TEST_DIR/empty_input"
python storage.py --input-dir "$TEST_DIR/empty_input" --storage-dir "$TEST_DIR/storage_empty"

# Should create storage structure even with no input
if [ ! -d "$TEST_DIR/storage_empty/active" ] || [ ! -d "$TEST_DIR/storage_empty/index" ]; then
    echo "FAILURE: Storage structure not created with empty input"
    exit 1
fi

# Test case 2: Malformed logs
echo "Testing storage with malformed logs..."
cat > "$TEST_DIR/input/malformed.json" << EOF
{"incomplete_data": "missing required fields"}
EOF

# Run storage on malformed log
python storage.py --input-dir "$TEST_DIR/input" --storage-dir "$TEST_DIR/storage" --file malformed.json

# Verify storage handled malformed log
MALFORMED_COUNT=$(grep -l "incomplete_data" "$TEST_DIR/storage/active"/* | wc -l)
if [ "$MALFORMED_COUNT" -eq 0 ]; then
    echo "FAILURE: Malformed log not stored properly"
    exit 1
fi

echo "✓ Edge cases test passed."

# ==========================================================
# Final Result
# ==========================================================
echo -e "\n=== ALL STORAGE COMPONENT TESTS PASSED ==="
echo "Storage component functionality verified successfully."