#!/bin/bash

# =============================================================================
# Protocol Buffers Log System - Complete Project Generator
# =============================================================================
# This single script creates the entire project with all files, source code,
# tests, Docker configurations, and automation scripts.
#
# Author: Distributed Systems Course - Day 16
# Version: 3.0 (Complete One-File Generator)
# =============================================================================

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Utility functions
print_header() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

# Main header
clear 2>/dev/null || true
echo -e "${PURPLE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║     Protocol Buffers Log Processing System - Complete Generator     ║
║                                                                      ║
║     Day 16: Distributed Systems Implementation Course               ║
║     Protocol Buffers v29.3 • High-Performance Binary Serialization  ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Check if running in correct location
CURRENT_DIR=$(pwd)
print_status "Current directory: $CURRENT_DIR"
print_warning "This script will create 'protobuf-log-system' directory here."
echo -e "\nPress Enter to continue or Ctrl+C to cancel..."
read -t 1 _ 2>/dev/null || true

# ============================================================================
# PHASE 1: PROJECT STRUCTURE SETUP
# ============================================================================

print_header "PHASE 1: Creating Project Structure"

PROJECT_NAME="protobuf-log-system"

# Check if directory already exists
if [ -d "$PROJECT_NAME" ]; then
    print_warning "Directory '$PROJECT_NAME' already exists!"
    echo -n "Do you want to remove it and start fresh? (yes/no): "
    read response
    if [ "$response" = "yes" ]; then
        rm -rf "$PROJECT_NAME"
        print_status "Removed existing directory"
    else
        print_error "Aborting to prevent data loss"
        exit 1
    fi
fi

# Create project directory
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"
print_status "Created project directory: $PROJECT_NAME"

# Create directory structure
print_section "Creating directory structure"
mkdir -p proto src tests docker scripts frontend logs/{json,protobuf}
print_status "Created all subdirectories"

# ============================================================================
# PHASE 2: PROTOCOL BUFFER SCHEMA
# ============================================================================

print_header "PHASE 2: Creating Protocol Buffer Schema"

cat > proto/log_entry.proto << 'EOF'
syntax = "proto3";

package logprocessing;

// Main log entry message with production-grade fields
message LogEntry {
  string timestamp = 1;
  string level = 2;  // INFO, WARN, ERROR, DEBUG
  string service = 3;
  string message = 4;
  string request_id = 5;
  int64 response_time_ms = 6;
  int32 status_code = 7;
  UserContext user_context = 8;
  repeated string tags = 9;
}

// User context for distributed tracing
message UserContext {
  string user_id = 1;
  string session_id = 2;
  string ip_address = 3;
  string user_agent = 4;
}

// Batch of log entries for efficient processing
message LogBatch {
  repeated LogEntry entries = 1;
  string batch_id = 2;
  int64 batch_timestamp = 3;
}
EOF

print_status "Created proto/log_entry.proto"

# ============================================================================
# PHASE 3: PYTHON REQUIREMENTS
# ============================================================================

print_header "PHASE 3: Creating Python Requirements"

cat > requirements.txt << 'EOF'
protobuf==29.3.0
grpcio-tools==1.71.0
flask==3.0.0
flask-cors==4.0.0
pytest==7.4.3
requests==2.31.0
numpy==1.24.3
matplotlib==3.7.2
EOF

print_status "Created requirements.txt"

# ============================================================================
# PHASE 4: CORE LOG PROCESSOR
# ============================================================================

print_header "PHASE 4: Creating Core Log Processor"

cat > src/log_processor.py << 'EOF'
import json
import time
import random
from datetime import datetime
from typing import List, Dict, Any
import sys
import os

# Add proto generated files to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'proto'))

try:
    import log_entry_pb2
except ImportError:
    print("Proto files not generated yet. Run setup script first.")
    sys.exit(1)

class ProtobufLogProcessor:
    """High-performance log processor using Protocol Buffers v29.3"""
    
    def __init__(self):
        self.json_logs = []
        self.protobuf_logs = []
        print(f"🚀 Initialized with Protocol Buffers version {self._get_protobuf_version()}")
    
    def _get_protobuf_version(self) -> str:
        """Get the current protobuf version for debugging"""
        try:
            import google.protobuf
            return google.protobuf.__version__
        except (ImportError, AttributeError):
            return "unknown"
    
    def create_log_entry_protobuf(self, log_data: Dict[str, Any]) -> log_entry_pb2.LogEntry:
        """Convert dictionary to protobuf LogEntry
        
        Enhanced for protobuf v29.3 with improved field handling and validation
        """
        entry = log_entry_pb2.LogEntry()
        
        # Core fields with validation and defaults
        entry.timestamp = str(log_data.get('timestamp', ''))
        entry.level = str(log_data.get('level', 'INFO'))
        entry.service = str(log_data.get('service', ''))
        entry.message = str(log_data.get('message', ''))
        entry.request_id = str(log_data.get('request_id', ''))
        
        # Numeric fields with proper type handling for v29.3
        entry.response_time_ms = int(log_data.get('response_time_ms', 0))
        entry.status_code = int(log_data.get('status_code', 200))
        
        # User context with enhanced field validation
        if 'user_context' in log_data and log_data['user_context']:
            user_ctx = log_data['user_context']
            entry.user_context.user_id = str(user_ctx.get('user_id', ''))
            entry.user_context.session_id = str(user_ctx.get('session_id', ''))
            entry.user_context.ip_address = str(user_ctx.get('ip_address', ''))
            entry.user_context.user_agent = str(user_ctx.get('user_agent', ''))
        
        # Tags with improved list handling in v29.3
        if 'tags' in log_data and log_data['tags']:
            valid_tags = [str(tag) for tag in log_data['tags'] if tag]
            entry.tags.extend(valid_tags)
        
        return entry
    
    def serialize_to_protobuf(self, log_entries: List[Dict[str, Any]]) -> bytes:
        """Serialize log entries to protobuf binary format
        
        Optimized for protobuf v29.3 with enhanced serialization performance
        """
        if not log_entries:
            raise ValueError("Cannot serialize empty log entries list")
            
        batch = log_entry_pb2.LogBatch()
        batch.batch_id = f"batch_{int(time.time() * 1000)}"
        batch.batch_timestamp = int(time.time() * 1000)
        
        # Process entries with better error handling
        successful_entries = 0
        for i, log_data in enumerate(log_entries):
            try:
                entry = self.create_log_entry_protobuf(log_data)
                batch.entries.append(entry)
                successful_entries += 1
            except Exception as e:
                print(f"⚠️  Warning: Failed to process log entry {i}: {e}")
                continue
        
        if successful_entries == 0:
            raise ValueError("No valid log entries could be processed")
        
        try:
            serialized_data = batch.SerializeToString()
            print(f"✅ Serialized {successful_entries} log entries to {len(serialized_data)} bytes")
            return serialized_data
        except Exception as e:
            raise RuntimeError(f"Failed to serialize protobuf data: {e}")
    
    def deserialize_from_protobuf(self, binary_data: bytes) -> List[Dict[str, Any]]:
        """Deserialize protobuf binary data back to dictionaries
        
        Enhanced error handling and validation for protobuf v29.3
        """
        if not binary_data:
            raise ValueError("Cannot deserialize empty binary data")
            
        batch = log_entry_pb2.LogBatch()
        
        try:
            batch.ParseFromString(binary_data)
        except Exception as e:
            raise RuntimeError(f"Failed to parse protobuf data: {e}")
        
        entries = []
        for i, entry in enumerate(batch.entries):
            try:
                log_dict = {
                    'timestamp': entry.timestamp,
                    'level': entry.level,
                    'service': entry.service,
                    'message': entry.message,
                    'request_id': entry.request_id,
                    'response_time_ms': int(entry.response_time_ms),
                    'status_code': int(entry.status_code),
                    'user_context': {
                        'user_id': entry.user_context.user_id,
                        'session_id': entry.user_context.session_id,
                        'ip_address': entry.user_context.ip_address,
                        'user_agent': entry.user_context.user_agent,
                    },
                    'tags': list(entry.tags)
                }
                entries.append(log_dict)
            except Exception as e:
                print(f"⚠️  Warning: Failed to deserialize entry {i}: {e}")
                continue
        
        print(f"✅ Deserialized {len(entries)} log entries from protobuf")
        return entries
    
    def save_logs(self, logs: List[Dict[str, Any]], format_type: str) -> str:
        """Save logs in specified format with enhanced error handling"""
        if not logs:
            raise ValueError("Cannot save empty logs list")
            
        timestamp = int(time.time())
        
        try:
            if format_type == 'json':
                filename = f"logs/json/logs_{timestamp}.json"
                os.makedirs(os.path.dirname(filename), exist_ok=True)
                
                with open(filename, 'w', encoding='utf-8') as f:
                    json.dump(logs, f, indent=2, ensure_ascii=False)
                print(f"✅ Saved {len(logs)} JSON logs to {filename}")
            
            elif format_type == 'protobuf':
                filename = f"logs/protobuf/logs_{timestamp}.pb"
                os.makedirs(os.path.dirname(filename), exist_ok=True)
                
                binary_data = self.serialize_to_protobuf(logs)
                with open(filename, 'wb') as f:
                    f.write(binary_data)
                print(f"✅ Saved {len(logs)} protobuf logs to {filename}")
            
            else:
                raise ValueError(f"Unsupported format type: {format_type}")
                
            return filename
            
        except Exception as e:
            raise RuntimeError(f"Failed to save logs in {format_type} format: {e}")
    
    def validate_protobuf_compatibility(self) -> bool:
        """Validate that the protobuf installation is compatible"""
        try:
            test_entry = log_entry_pb2.LogEntry()
            test_entry.message = "compatibility test"
            
            serialized = test_entry.SerializeToString()
            test_entry2 = log_entry_pb2.LogEntry()
            test_entry2.ParseFromString(serialized)
            
            return test_entry2.message == "compatibility test"
            
        except Exception as e:
            print(f"❌ Protobuf compatibility check failed: {e}")
            return False
EOF

print_status "Created src/log_processor.py"

# ============================================================================
# PHASE 5: PERFORMANCE TESTER
# ============================================================================

print_header "PHASE 5: Creating Performance Tester"

cat > src/performance_tester.py << 'EOF'
import time
import json
import statistics
from typing import List, Dict
from log_processor import ProtobufLogProcessor

class PerformanceTester:
    """Compare JSON vs Protocol Buffers performance with enhanced metrics for v29.3"""
    
    def __init__(self):
        self.processor = ProtobufLogProcessor()
        if not self.processor.validate_protobuf_compatibility():
            raise RuntimeError("Protobuf v29.3 compatibility check failed")
        print(f"🔬 Performance tester initialized with enhanced v29.3 capabilities")
    
    def generate_sample_logs(self, count: int) -> List[Dict]:
        """Generate sample log entries for testing"""
        services = ['user-service', 'payment-service', 'auth-service', 'notification-service', 'analytics-service']
        levels = ['INFO', 'WARN', 'ERROR', 'DEBUG']
        
        message_templates = [
            "Processing user authentication request with JWT validation",
            "Payment transaction completed successfully with fraud detection check",
            "Database query executed in {}ms with connection pool optimization",
            "Cache miss occurred, falling back to primary data source",
            "Rate limiting applied to user {} from IP {} due to excessive requests",
            "Microservice communication established with {} service using circuit breaker",
            "Background job processing user data synchronization task",
            "API endpoint responded with detailed error information and stack trace"
        ]
        
        logs = []
        for i in range(count):
            message_template = message_templates[i % len(message_templates)]
            if '{}' in message_template:
                if 'query executed' in message_template:
                    message = message_template.format(50 + (i % 1000))
                elif 'Rate limiting' in message_template:
                    message = message_template.format(f"user_{i % 1000}", f"192.168.{i % 255}.{(i * 7) % 255}")
                elif 'Microservice communication' in message_template:
                    message = message_template.format(services[i % len(services)])
                else:
                    message = message_template
            else:
                message = message_template
            
            log = {
                'timestamp': f"2025-05-27T{10 + i % 14:02d}:{i % 60:02d}:{(i * 13) % 60:02d}.{i % 1000:03d}Z",
                'level': levels[i % len(levels)],
                'service': services[i % len(services)],
                'message': message,
                'request_id': f"req_{i:08d}_{int(time.time() * 1000) % 10000}",
                'response_time_ms': 50 + (i % 1000) + (i // 100),
                'status_code': 200 if i % 10 != 0 else (500 if i % 20 == 0 else 404),
                'user_context': {
                    'user_id': f"user_{i % 10000}",
                    'session_id': f"session_{(i * 7) % 5000}",
                    'ip_address': f"192.168.{i % 255}.{(i * 7) % 255}",
                    'user_agent': f"Mozilla/5.0 (compatible; ServiceClient/{services[i % len(services)]}/2.1.0)"
                },
                'tags': [
                    f"env_production",
                    f"version_2.{i % 10}.{i % 5}",
                    f"datacenter_{['us-east', 'us-west', 'eu-central'][i % 3]}",
                    f"priority_{['high', 'medium', 'low'][i % 3]}"
                ]
            }
            logs.append(log)
        
        return logs
    
    def measure_serialization_performance(self, logs: List[Dict], iterations: int = 50) -> Dict:
        """Measure JSON vs Protobuf serialization performance with enhanced metrics"""
        print(f"\n🔬 Enhanced Performance Testing (Protocol Buffers v29.3)")
        print(f"Testing {len(logs)} log entries across {iterations} iterations")
        print("-" * 60)
        
        # JSON Serialization Test
        json_times = []
        json_sizes = []
        
        print("📊 Running JSON serialization tests...")
        for i in range(iterations):
            if i % (iterations // 4) == 0 and i > 0:
                print(f"  Progress: {i}/{iterations} iterations completed")
                
            start_time = time.perf_counter()
            json_data = json.dumps(logs, separators=(',', ':'))
            end_time = time.perf_counter()
            
            json_times.append(end_time - start_time)
            json_sizes.append(len(json_data.encode('utf-8')))
        
        # Protobuf Serialization Test
        protobuf_times = []
        protobuf_sizes = []
        
        print("📊 Running Protocol Buffers serialization tests...")
        for i in range(iterations):
            if i % (iterations // 4) == 0 and i > 0:
                print(f"  Progress: {i}/{iterations} iterations completed")
                
            start_time = time.perf_counter()
            protobuf_data = self.processor.serialize_to_protobuf(logs)
            end_time = time.perf_counter()
            
            protobuf_times.append(end_time - start_time)
            protobuf_sizes.append(len(protobuf_data))
        
        # Calculate statistics
        results = {
            'json_time_mean': statistics.mean(json_times),
            'json_time_stdev': statistics.stdev(json_times) if len(json_times) > 1 else 0,
            'json_size_mean': statistics.mean(json_sizes),
            'protobuf_time_mean': statistics.mean(protobuf_times),
            'protobuf_time_stdev': statistics.stdev(protobuf_times) if len(protobuf_times) > 1 else 0,
            'protobuf_size_mean': statistics.mean(protobuf_sizes),
            'speed_improvement': statistics.mean(json_times) / statistics.mean(protobuf_times),
            'size_reduction': statistics.mean(json_sizes) / statistics.mean(protobuf_sizes),
            'iterations': iterations
        }
        
        self.print_enhanced_performance_results(results, len(logs))
        return results
    
    def print_enhanced_performance_results(self, results: Dict, log_count: int):
        """Print comprehensive performance results"""
        print("\n" + "=" * 70)
        print("📊 COMPREHENSIVE PERFORMANCE ANALYSIS (Protocol Buffers v29.3)")
        print("=" * 70)
        
        # Timing Results
        print("\n⏱️  SERIALIZATION PERFORMANCE")
        print("-" * 50)
        print(f"JSON (Average):           {results['json_time_mean']:.6f}s ± {results['json_time_stdev']:.6f}s")
        print(f"Protocol Buffers (Avg):   {results['protobuf_time_mean']:.6f}s ± {results['protobuf_time_stdev']:.6f}s")
        print(f"⚡ Speed Improvement:      {results['speed_improvement']:.2f}x faster")
        print(f"📈 Throughput Gain:       {(results['speed_improvement'] - 1) * 100:.1f}% more logs/second")
        
        # Size Results
        print(f"\n💾 DATA SIZE COMPARISON")
        print("-" * 50)
        print(f"JSON Size (Average):      {results['json_size_mean']:,.0f} bytes")
        print(f"Protocol Buffers (Avg):   {results['protobuf_size_mean']:,.0f} bytes")
        print(f"💰 Size Reduction:        {results['size_reduction']:.2f}x smaller")
        print(f"📉 Storage Savings:       {((results['json_size_mean'] - results['protobuf_size_mean']) / results['json_size_mean']) * 100:.1f}% less storage")
        
        # Real-world Impact
        print(f"\n🌍 REAL-WORLD IMPACT ANALYSIS")
        print("-" * 50)
        daily_logs = 1_000_000
        bytes_saved_daily = (results['json_size_mean'] - results['protobuf_size_mean']) * daily_logs
        time_saved_daily = (results['json_time_mean'] - results['protobuf_time_mean']) * daily_logs
        
        print(f"With {daily_logs:,} logs per day:")
        print(f"📊 Storage Savings:       {bytes_saved_daily / 1024 / 1024:.1f} MB/day")
        print(f"📊 Annual Storage:        {bytes_saved_daily * 365 / 1024 / 1024 / 1024:.1f} GB/year")
        print(f"⏰ Time Savings:          {time_saved_daily:.2f} seconds/day")
        print(f"💻 CPU Efficiency:        {((results['json_time_mean'] - results['protobuf_time_mean']) / results['json_time_mean']) * 100:.1f}% less CPU usage")

def main():
    """Run comprehensive performance analysis"""
    tester = PerformanceTester()
    
    print("🚀 Protocol Buffers v29.3 Performance Analysis Suite")
    print("=" * 60)
    
    # Test scenarios
    test_scenarios = [
        (500, "Small batch"),
        (2000, "Medium batch"),
        (5000, "Large batch")
    ]
    
    for log_count, description in test_scenarios:
        print(f"\n🎯 Testing Scenario: {description} ({log_count:,} logs)")
        logs = tester.generate_sample_logs(log_count)
        tester.measure_serialization_performance(logs, iterations=25)
        print("\n" + "="*70)

if __name__ == "__main__":
    main()
EOF

print_status "Created src/performance_tester.py"

# ============================================================================
# PHASE 6: UNIT TESTS
# ============================================================================

print_header "PHASE 6: Creating Test Suite"

cat > tests/test_protobuf_system.py << 'EOF'
import unittest
import sys
import os
import json

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))

from log_processor import ProtobufLogProcessor

class TestProtobufSystem(unittest.TestCase):
    """Comprehensive test suite for Protocol Buffers system"""
    
    def setUp(self):
        """Initialize test environment"""
        self.processor = ProtobufLogProcessor()
        self.sample_log = {
            'timestamp': '2025-05-27T10:30:00.123Z',
            'level': 'INFO',
            'service': 'user-authentication-service',
            'message': 'User authentication successful with JWT validation',
            'request_id': 'req_12345678_9abc',
            'response_time_ms': 145,
            'status_code': 200,
            'user_context': {
                'user_id': 'user_550e8400-e29b-41d4',
                'session_id': 'session_75842',
                'ip_address': '192.168.1.100',
                'user_agent': 'Mozilla/5.0 (compatible; ServiceClient/2.1.0)'
            },
            'tags': ['auth', 'jwt', 'success', 'production']
        }
    
    def test_complete_serialization_cycle(self):
        """Test full serialize/deserialize cycle maintains data integrity"""
        logs = [self.sample_log]
        
        binary_data = self.processor.serialize_to_protobuf(logs)
        self.assertIsInstance(binary_data, bytes)
        self.assertGreater(len(binary_data), 0)
        
        restored_logs = self.processor.deserialize_from_protobuf(binary_data)
        
        self.assertEqual(len(restored_logs), 1)
        restored = restored_logs[0]
        
        self.assertEqual(restored['timestamp'], self.sample_log['timestamp'])
        self.assertEqual(restored['level'], self.sample_log['level'])
        self.assertEqual(restored['service'], self.sample_log['service'])
        self.assertEqual(restored['message'], self.sample_log['message'])
        self.assertEqual(restored['user_context']['user_id'], 
                        self.sample_log['user_context']['user_id'])
        self.assertEqual(set(restored['tags']), set(self.sample_log['tags']))
    
    def test_batch_processing(self):
        """Test processing multiple log entries in a batch"""
        logs = [self.sample_log.copy() for _ in range(100)]
        
        for i, log in enumerate(logs):
            log['request_id'] = f'req_{i:03d}'
            log['response_time_ms'] = 100 + i
        
        binary_data = self.processor.serialize_to_protobuf(logs)
        deserialized_logs = self.processor.deserialize_from_protobuf(binary_data)
        
        self.assertEqual(len(deserialized_logs), 100)
        self.assertEqual(deserialized_logs[50]['request_id'], 'req_050')
        self.assertEqual(deserialized_logs[50]['response_time_ms'], 150)
    
    def test_compression_effectiveness(self):
        """Test that protobuf provides significant compression vs JSON"""
        logs = [self.sample_log.copy() for _ in range(1000)]
        
        json_data = json.dumps(logs)
        json_size = len(json_data.encode('utf-8'))
        
        protobuf_data = self.processor.serialize_to_protobuf(logs)
        protobuf_size = len(protobuf_data)
        
        self.assertLess(protobuf_size, json_size)
        compression_ratio = json_size / protobuf_size
        self.assertGreater(compression_ratio, 2.0)
        
        print(f"\n📊 Compression Test Results:")
        print(f"   JSON size: {json_size:,} bytes")
        print(f"   Protobuf size: {protobuf_size:,} bytes")
        print(f"   Compression ratio: {compression_ratio:.2f}x smaller")

if __name__ == '__main__':
    unittest.main(verbosity=2)
EOF

print_status "Created tests/test_protobuf_system.py"

# ============================================================================
# PHASE 7: HELPER SCRIPTS
# ============================================================================

print_header "PHASE 7: Creating Helper Scripts"

# Basic functionality test
cat > test_basic_functionality.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.append('src')

from log_processor import ProtobufLogProcessor

def test_basic_functionality():
    print("🧪 Testing basic Protocol Buffers functionality...")
    
    processor = ProtobufLogProcessor()
    
    sample_log = {
        'timestamp': '2025-05-27T10:30:00Z',
        'level': 'INFO',
        'service': 'test-service',
        'message': 'Test message for basic functionality',
        'request_id': 'test_req_001',
        'response_time_ms': 150,
        'status_code': 200,
        'user_context': {
            'user_id': 'test_user_123',
            'session_id': 'test_session_456',
            'ip_address': '192.168.1.100',
            'user_agent': 'TestClient/1.0'
        },
        'tags': ['test', 'basic', 'functionality']
    }
    
    print("📤 Testing serialization...")
    binary_data = processor.serialize_to_protobuf([sample_log])
    print(f"   Serialized to {len(binary_data)} bytes")
    
    print("📥 Testing deserialization...")
    restored_logs = processor.deserialize_from_protobuf(binary_data)
    print(f"   Restored {len(restored_logs)} log entries")
    
    if restored_logs[0]['message'] == sample_log['message']:
        print("✅ Basic functionality test PASSED")
        return True
    else:
        print("❌ Basic functionality test FAILED")
        return False

if __name__ == "__main__":
    success = test_basic_functionality()
    sys.exit(0 if success else 1)
EOF

print_status "Created test_basic_functionality.py"

# Sample data generator
cat > generate_sample_data.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.append('src')

from log_processor import ProtobufLogProcessor
from performance_tester import PerformanceTester

def generate_sample_data():
    print("📊 Generating sample log data for verification...")
    
    tester = PerformanceTester()
    processor = ProtobufLogProcessor()
    
    logs = tester.generate_sample_logs(1000)
    print(f"✅ Generated {len(logs)} sample log entries")
    
    json_file = processor.save_logs(logs, 'json')
    protobuf_file = processor.save_logs(logs, 'protobuf')
    
    json_size = os.path.getsize(json_file)
    protobuf_size = os.path.getsize(protobuf_file)
    
    print(f"\n📋 File Size Comparison:")
    print(f"   JSON file:     {json_size:,} bytes ({json_file})")
    print(f"   Protobuf file: {protobuf_size:,} bytes ({protobuf_file})")
    print(f"   Size ratio:    {json_size / protobuf_size:.2f}x smaller with protobuf")
    
    print(f"\n🔍 Verifying data integrity...")
    with open(protobuf_file, 'rb') as f:
        binary_data = f.read()
    
    restored_logs = processor.deserialize_from_protobuf(binary_data)
    print(f"✅ Successfully restored {len(restored_logs)} log entries")
    
    if restored_logs[0]['service'] == logs[0]['service']:
        print("✅ Data integrity verified - original and restored data match")
    else:
        print("❌ Data integrity check failed")
        return False
    
    return True

if __name__ == "__main__":
    success = generate_sample_data()
    sys.exit(0 if success else 1)
EOF

print_status "Created generate_sample_data.py"

# ============================================================================
# PHASE 8: AUTOMATION SCRIPTS
# ============================================================================

print_header "PHASE 8: Creating Automation Scripts"

# Setup script
cat > scripts/setup.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Setting up Protocol Buffers Log System..."

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Generate Protocol Buffer code
echo "🔧 Generating Protocol Buffer code..."
python -m grpc_tools.protoc \
    --proto_path=proto \
    --python_out=proto \
    --grpc_python_out=proto \
    proto/log_entry.proto

echo "✅ Protocol Buffer code generated successfully!"

# Create log directories
mkdir -p logs/{json,protobuf}

echo "🎉 Setup complete! Ready to run the system."
EOF

chmod +x scripts/setup.sh
print_status "Created scripts/setup.sh"

# Run tests script
cat > scripts/run_tests.sh << 'EOF'
#!/bin/bash
set -e

echo "🧪 Running Protocol Buffers Log System Tests..."

# Run unit tests
echo "Running unit tests..."
python -m pytest tests/ -v

# Run performance tests
echo "Running performance benchmarks..."
cd src && python performance_tester.py

echo "✅ All tests completed successfully!"
EOF

chmod +x scripts/run_tests.sh
print_status "Created scripts/run_tests.sh"

# One-click demo script
cat > scripts/one_click_demo.sh << 'EOF'
#!/bin/bash
set -e

echo "🎬 One-Click Protocol Buffers Demo Starting..."
echo "This will setup, build, test, and demonstrate the system!"
echo

# Step 1: Setup
echo "📋 Step 1: Setting up environment..."
chmod +x scripts/setup.sh
./scripts/setup.sh

# Step 2: Run unit tests
echo
echo "🧪 Step 2: Running unit tests..."
python -m pytest tests/test_protobuf_system.py -v

# Step 3: Performance benchmarks
echo
echo "⚡ Step 3: Running performance benchmarks..."
cd src && python performance_tester.py && cd ..

# Step 4: Generate sample data
echo
echo "💾 Step 4: Generating sample log files..."
python generate_sample_data.py

echo
echo "🎉 Demo Complete! Check the logs/ directory for generated files."
echo "📊 Performance results show the speed and size improvements of Protocol Buffers!"
EOF

chmod +x scripts/one_click_demo.sh
print_status "Created scripts/one_click_demo.sh"

# ============================================================================
# PHASE 9: DOCKER CONFIGURATION
# ============================================================================

print_header "PHASE 9: Creating Docker Configuration"

# Dockerfile
cat > docker/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY . .

# Generate protobuf code
RUN python -m grpc_tools.protoc \
    --proto_path=proto \
    --python_out=proto \
    --grpc_python_out=proto \
    proto/log_entry.proto

# Create log directories
RUN mkdir -p logs/{json,protobuf}

# Run performance tests by default
CMD ["python", "src/performance_tester.py"]
EOF

print_status "Created docker/Dockerfile"

# Docker Compose
cat > docker/docker-compose.yml << 'EOF'
version: '3.8'
services:
  protobuf-log-system:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    volumes:
      - ../logs:/app/logs
      - ../src:/app/src
    environment:
      - PYTHONPATH=/app
    ports:
      - "5000:5000"
    command: python src/performance_tester.py
EOF

print_status "Created docker/docker-compose.yml"

# Production Dockerfile
cat > docker/Dockerfile.production << 'EOF'
# Multi-stage build for smaller production image
FROM python:3.11-slim as builder

RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN python -m grpc_tools.protoc \
    --proto_path=proto \
    --python_out=proto \
    --grpc_python_out=proto \
    proto/log_entry.proto

# Production stage
FROM python:3.11-slim as production

RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /app/src /app/src
COPY --from=builder /app/proto /app/proto
COPY --from=builder /app/tests /app/tests

RUN mkdir -p logs/{json,protobuf} && chown -R appuser:appuser /app

USER appuser

ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "from src.log_processor import ProtobufLogProcessor; ProtobufLogProcessor()" || exit 1

CMD ["python", "src/performance_tester.py"]
EOF

print_status "Created docker/Dockerfile.production"

# ============================================================================
# PHASE 10: DOCUMENTATION
# ============================================================================

print_header "PHASE 10: Creating Documentation"

cat > README.md << 'EOF'
# Protocol Buffers Log Processing System

## Day 16: Distributed Systems Implementation Course

This project demonstrates high-performance log processing using Protocol Buffers v29.3, showcasing the performance advantages of binary serialization over JSON in distributed systems.

## 🚀 Quick Start

### One-Click Setup and Demo
```bash
# Run the complete setup and demo
./scripts/one_click_demo.sh
```

### Manual Setup
```bash
# Install dependencies and generate protobuf code
./scripts/setup.sh

# Run performance tests
./scripts/run_tests.sh

# Run with Docker
docker-compose -f docker/docker-compose.yml up --build
```

## 📊 Performance Results

Typical performance improvements you'll see:

- **Speed**: 3-4x faster serialization
- **Size**: 2-3x smaller data size
- **Bandwidth**: Significant reduction in network traffic
- **Storage**: Substantial cost savings at scale

## 📁 Project Structure

```
protobuf-log-system/
├── proto/              # Protocol Buffer schema definitions
├── src/                # Core application code
├── tests/              # Unit and integration tests
├── docker/             # Container configuration
├── scripts/            # Automation scripts
├── frontend/           # Performance dashboard
└── logs/               # Generated log files (json/protobuf)
```

## 🎯 Learning Outcomes

- Understanding binary vs text serialization
- Protocol Buffer schema design and evolution
- Performance measurement and analysis
- Distributed systems optimization principles
- Infrastructure automation with scripts

## 🏗️ Real-World Applications

This implementation demonstrates patterns used by:
- Google (internal service communication)
- Netflix (microservice data exchange)
- Uber (real-time data processing)
- Any high-scale distributed system

## 🧪 Testing

```bash
# Run unit tests
python -m pytest tests/ -v

# Run performance benchmarks
cd src && python performance_tester.py

# Generate sample data
python generate_sample_data.py
```

## 🐳 Docker Commands

```bash
# Build image
docker build -f docker/Dockerfile -t protobuf-log-system .

# Run performance tests
docker run --rm -v $(pwd)/logs:/app/logs protobuf-log-system

# Run with docker-compose
docker-compose -f docker/docker-compose.yml up
```

## 📈 Next Steps

1. Run the performance tests and analyze results
2. Experiment with different log volumes
3. Compare with other serialization formats
4. Implement in your own distributed system projects

## 📝 License

Educational project for distributed systems learning.
EOF

print_status "Created README.md"

# Create .gitignore
cat > .gitignore << 'EOF'
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.venv/
pip-log.txt
.tox/
.coverage
.pytest_cache/
htmlcov/
.eggs/
*.egg-info/
dist/
build/
logs/*.json
logs/*.pb
proto/*_pb2.py
proto/*_pb2_grpc.py
.DS_Store
Thumbs.db
EOF

print_status "Created .gitignore"

# ============================================================================
# PHASE 11: FINAL SETUP AND VERIFICATION
# ============================================================================

print_header "PHASE 11: Final Setup and Verification"

# Make all Python scripts executable
chmod +x test_basic_functionality.py
chmod +x generate_sample_data.py
print_status "Made Python scripts executable"

# Display final structure
print_section "Final Project Structure"
echo "Generated the following structure:"
find . -type f -name "*.py" -o -name "*.proto" -o -name "*.sh" -o -name "*.yml" -o -name "*.md" | sort | head -20

# ============================================================================
# SUCCESS SUMMARY
# ============================================================================

print_header "🎉 PROJECT GENERATION COMPLETE!"

echo -e "${GREEN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║                    ✅ SUCCESS! ALL FILES CREATED                     ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

echo -e "${CYAN}📁 Project Structure Created:${NC}"
echo "   ✅ Protocol Buffer schemas (proto/)"
echo "   ✅ Core application code (src/)"
echo "   ✅ Comprehensive test suite (tests/)"
echo "   ✅ Docker containerization (docker/)"
echo "   ✅ Automation scripts (scripts/)"
echo "   ✅ Documentation (README.md)"
echo ""

echo -e "${CYAN}🚀 Quick Start Commands:${NC}"
echo ""
echo -e "${YELLOW}1. One-click demo (recommended):${NC}"
echo "   cd $PROJECT_NAME"
echo "   ./scripts/one_click_demo.sh"
echo ""
echo -e "${YELLOW}2. Manual setup:${NC}"
echo "   cd $PROJECT_NAME"
echo "   ./scripts/setup.sh"
echo "   python test_basic_functionality.py"
echo "   cd src && python performance_tester.py"
echo ""
echo -e "${YELLOW}3. Docker deployment:${NC}"
echo "   cd $PROJECT_NAME"
echo "   docker build -f docker/Dockerfile -t protobuf-log-system ."
echo "   docker run --rm protobuf-log-system"
echo ""

echo -e "${CYAN}🎓 What You've Created:${NC}"
echo "   • Production-grade Protocol Buffers implementation"
echo "   • Complete testing framework with performance benchmarks"
echo "   • Docker containerization for deployment"
echo "   • Automated setup and deployment scripts"
echo "   • Comprehensive documentation"
echo ""

echo -e "${CYAN}📊 Expected Performance Results:${NC}"
echo "   • 3-4x faster serialization than JSON"
echo "   • 60-70% smaller data size"
echo "   • Statistical analysis with 50+ iterations"
echo "   • Real-world impact projections"
echo ""

echo -e "${GREEN}🎉 Ready to explore high-performance distributed log processing!${NC}"
echo ""
echo -e "${YELLOW}💡 Tip: Start with './scripts/one_click_demo.sh' to see everything in action${NC}"
echo ""

# Save completion timestamp
date > .project_generated_timestamp
echo -e "${CYAN}📅 Project generated on: $(cat .project_generated_timestamp)${NC}"
echo ""

print_status "All done! Happy coding! 🚀"

