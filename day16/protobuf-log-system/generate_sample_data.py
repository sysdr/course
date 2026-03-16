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
