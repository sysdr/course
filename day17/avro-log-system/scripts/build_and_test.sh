#!/bin/bash

# Avro Log System - Build and Test Script
set -e

echo "🏗️  Building Avro Schema Evolution Log System..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Step 1: Install dependencies
print_step "Installing Python dependencies..."
pip install -r requirements.txt
print_success "Dependencies installed"

# Step 2: Validate schemas
print_step "Validating Avro schemas..."
python -c "
from src.serializers.avro_handler import AvroSchemaManager
manager = AvroSchemaManager()
print(f'✓ Loaded {len(manager.schemas)} schema versions')
print('✓ All schemas validated successfully')
"
print_success "Schema validation passed"

# Step 3: Run unit tests
print_step "Running unit tests..."
python -m pytest src/tests/ -v --tb=short
print_success "Unit tests passed"

# Step 4: Run integration tests
print_step "Running integration tests..."
python -m pytest src/tests/test_integration.py -v
print_success "Integration tests passed"

# Step 5: Test schema compatibility
print_step "Testing schema compatibility..."
python -c "
from src.serializers.avro_handler import LogEventProcessor
from src.models.log_event import create_log_event

processor = LogEventProcessor()
for version in ['v1', 'v2', 'v3']:
    event = create_log_event(version)
    result = processor.process_event(event.to_dict(), version)
    print(f'✓ {version}: {result}')

summary = processor.get_processing_summary()
print(f'✓ Processed {summary[\"total_events\"]} events successfully')
"
print_success "Compatibility tests passed"

# Step 6: Start web dashboard
print_step "Starting web dashboard..."
echo "🌐 Dashboard will be available at: http://localhost:5000"
echo "📊 Press Ctrl+C to stop the server"
python -m src.web.app
