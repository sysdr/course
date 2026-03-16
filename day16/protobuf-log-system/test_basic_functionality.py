#!/usr/bin/env python3
"""
Step 8: Test Basic Functionality

Run from project root: python test_basic_functionality.py

Expected output:
  🧪 Testing basic Protocol Buffers functionality...
  🚀 Initialized with Protocol Buffers version X.X.X
  📤 Testing serialization...
  ✅ Serialized 1 log entries to N bytes
  📥 Testing deserialization...
  ✅ Deserialized 1 log entries from protobuf
  ✅ Basic functionality test PASSED

This test confirms that your Protocol Buffers setup is working correctly.
The serialization and deserialization cycle proves that the generated code
is functioning properly and your environment is configured correctly.
"""
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
    # Processor prints: ✅ Serialized 1 log entries to N bytes

    print("📥 Testing deserialization...")
    restored_logs = processor.deserialize_from_protobuf(binary_data)
    # Processor prints: ✅ Deserialized 1 log entries from protobuf

    if restored_logs[0]['message'] == sample_log['message']:
        print("✅ Basic functionality test PASSED")
        return True
    else:
        print("❌ Basic functionality test FAILED")
        return False

if __name__ == "__main__":
    success = test_basic_functionality()
    sys.exit(0 if success else 1)
