"""
Protocol Buffers Log Processor
High-performance binary serialization for distributed log processing
"""

import time
import json
import gzip
from datetime import datetime
from typing import List, Dict, Any
import sys
import os

# Add proto directory to path for generated modules
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'proto'))

try:
    import log_entry_pb2
except ImportError:
    print("❌ Protocol Buffer modules not found. Run: python -m grpc_tools.protoc first")
    sys.exit(1)

class ProtobufLogProcessor:
    """Enhanced log processor with Protocol Buffers support"""
    
    def __init__(self):
        self.performance_metrics = []
    
    def create_log_entry_protobuf(self, timestamp: str, level: str, service: str, 
                                 message: str, metadata: Dict[str, str] = None,
                                 request_id: str = "", processing_time_ms: int = 0) -> log_entry_pb2.LogEntry:
        """Create a Protocol Buffer log entry"""
        entry = log_entry_pb2.LogEntry()
        entry.timestamp = timestamp
        entry.level = level
        entry.service = service
        entry.message = message
        entry.request_id = request_id
        entry.processing_time_ms = processing_time_ms
        
        if metadata:
            for key, value in metadata.items():
                entry.metadata[key] = str(value)
        
        return entry
    
    def create_log_batch(self, entries: List[log_entry_pb2.LogEntry], 
                        batch_id: str = None) -> log_entry_pb2.LogBatch:
        """Create a batch of log entries for efficient processing"""
        batch = log_entry_pb2.LogBatch()
        batch.batch_id = batch_id or f"batch_{int(time.time())}"
        batch.batch_timestamp = int(time.time() * 1000)
        
        for entry in entries:
            batch.entries.append(entry)
        
        return batch
    
    def serialize_protobuf(self, batch: log_entry_pb2.LogBatch) -> bytes:
        """Serialize log batch to Protocol Buffer binary format"""
        start_time = time.time()
        serialized_data = batch.SerializeToString()
        serialization_time = (time.time() - start_time) * 1000
        
        # Record performance metrics
        metrics = log_entry_pb2.PerformanceMetrics()
        metrics.serialization_format = "protobuf"
        metrics.serialization_time_ms = serialization_time
        metrics.data_size_bytes = len(serialized_data)
        metrics.entries_count = len(batch.entries)
        
        return serialized_data
    
    def deserialize_protobuf(self, data: bytes) -> log_entry_pb2.LogBatch:
        """Deserialize Protocol Buffer binary data to log batch"""
        start_time = time.time()
        batch = log_entry_pb2.LogBatch()
        batch.ParseFromString(data)
        deserialization_time = (time.time() - start_time) * 1000
        
        return batch
    
    def serialize_json(self, entries: List[Dict[str, Any]]) -> str:
        """Serialize log entries to JSON for comparison"""
        start_time = time.time()
        json_data = json.dumps(entries, indent=2)
        serialization_time = (time.time() - start_time) * 1000
        
        return json_data
    
    def performance_comparison(self, entry_count: int = 1000):
        """Compare Protocol Buffers vs JSON performance"""
        print(f"\n🏁 Performance Comparison ({entry_count} log entries)")
        print("=" * 60)
        
        # Generate sample log entries
        sample_entries_dict = []
        sample_entries_protobuf = []
        
        for i in range(entry_count):
            timestamp = datetime.now().isoformat()
            entry_dict = {
                "timestamp": timestamp,
                "level": "INFO" if i % 3 == 0 else "ERROR",
                "service": f"service-{i % 5}",
                "message": f"Processing request {i} with detailed information",
                "request_id": f"req-{i:06d}",
                "processing_time_ms": (i % 100) + 10,
                "metadata": {
                    "user_id": f"user_{i % 100}",
                    "session_id": f"session_{i % 50}",
                    "version": "1.2.3"
                }
            }
            sample_entries_dict.append(entry_dict)
            
            # Create protobuf entry
            pb_entry = self.create_log_entry_protobuf(
                timestamp=timestamp,
                level=entry_dict["level"],
                service=entry_dict["service"],
                message=entry_dict["message"],
                request_id=entry_dict["request_id"],
                processing_time_ms=entry_dict["processing_time_ms"],
                metadata=entry_dict["metadata"]
            )
            sample_entries_protobuf.append(pb_entry)
        
        # Test JSON serialization
        json_start = time.time()
        json_data = self.serialize_json(sample_entries_dict)
        json_serialize_time = (time.time() - json_start) * 1000
        json_size = len(json_data.encode('utf-8'))
        
        # Test Protocol Buffers serialization
        pb_batch = self.create_log_batch(sample_entries_protobuf)
        pb_start = time.time()
        pb_data = self.serialize_protobuf(pb_batch)
        pb_serialize_time = (time.time() - pb_start) * 1000
        pb_size = len(pb_data)
        
        # Test deserialization
        json_deserialize_start = time.time()
        json.loads(json_data)
        json_deserialize_time = (time.time() - json_deserialize_start) * 1000
        
        pb_deserialize_start = time.time()
        self.deserialize_protobuf(pb_data)
        pb_deserialize_time = (time.time() - pb_deserialize_start) * 1000
        
        # Display results
        print(f"📊 JSON Results:")
        print(f"   Serialization:   {json_serialize_time:.2f} ms")
        print(f"   Deserialization: {json_deserialize_time:.2f} ms")
        print(f"   Data Size:       {json_size:,} bytes")
        
        print(f"\n📊 Protocol Buffers Results:")
        print(f"   Serialization:   {pb_serialize_time:.2f} ms")
        print(f"   Deserialization: {pb_deserialize_time:.2f} ms")
        print(f"   Data Size:       {pb_size:,} bytes")
        
        # Calculate improvements
        size_reduction = ((json_size - pb_size) / json_size) * 100
        serialize_improvement = ((json_serialize_time - pb_serialize_time) / json_serialize_time) * 100
        deserialize_improvement = ((json_deserialize_time - pb_deserialize_time) / json_deserialize_time) * 100
        
        print(f"\n🎯 Performance Gains:")
        print(f"   Size Reduction:    {size_reduction:.1f}%")
        print(f"   Serialize Faster:  {serialize_improvement:.1f}%")
        print(f"   Deserialize Faster: {deserialize_improvement:.1f}%")
        
        return {
            "json": {"serialize_ms": json_serialize_time, "deserialize_ms": json_deserialize_time, "size_bytes": json_size},
            "protobuf": {"serialize_ms": pb_serialize_time, "deserialize_ms": pb_deserialize_time, "size_bytes": pb_size}
        }

def main():
    """Demonstrate Protocol Buffers log processing"""
    processor = ProtobufLogProcessor()
    
    print("🎯 Protocol Buffers Log Processing Demo")
    print("=====================================")
    
    # Create sample log entries
    entries = []
    for i in range(5):
        entry = processor.create_log_entry_protobuf(
            timestamp=datetime.now().isoformat(),
            level="INFO" if i % 2 == 0 else "ERROR",
            service=f"web-service-{i}",
            message=f"Processing user request #{i + 1}",
            request_id=f"req-{i + 1:03d}",
            processing_time_ms=(i + 1) * 50,
            metadata={"user_id": f"user_{i + 1}", "endpoint": "/api/data"}
        )
        entries.append(entry)
    
    # Create and serialize batch
    batch = processor.create_log_batch(entries, "demo-batch")
    serialized_data = processor.serialize_protobuf(batch)
    
    print(f"✅ Created batch with {len(batch.entries)} entries")
    print(f"📦 Serialized size: {len(serialized_data)} bytes")
    
    # Deserialize and display
    deserialized_batch = processor.deserialize_protobuf(serialized_data)
    print(f"\n📋 Deserialized Log Entries:")
    for i, entry in enumerate(deserialized_batch.entries):
        print(f"   {i+1}. [{entry.level}] {entry.service}: {entry.message}")
        print(f"       Request ID: {entry.request_id}, Time: {entry.processing_time_ms}ms")
    
    # Run performance comparison
    processor.performance_comparison(1000)

if __name__ == "__main__":
    main()
