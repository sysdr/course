"""
Comprehensive performance benchmark for Protocol Buffers vs JSON
"""

import time
import json
import statistics
from datetime import datetime
import sys
import os

# Add proto directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'proto'))

from protobuf_log_processor import ProtobufLogProcessor

def run_comprehensive_benchmark():
    """Run comprehensive performance benchmark"""
    processor = ProtobufLogProcessor()
    
    print("🏁 Comprehensive Performance Benchmark")
    print("=" * 50)
    
    test_sizes = [100, 500, 1000, 5000, 10000]
    results = []
    
    for size in test_sizes:
        print(f"\n📊 Testing with {size:,} log entries...")
        
        # Multiple runs for statistical accuracy
        json_serialize_times = []
        json_deserialize_times = []
        pb_serialize_times = []
        pb_deserialize_times = []
        json_sizes = []
        pb_sizes = []
        
        for run in range(5):  # 5 runs per test size
            # Generate test data
            entries_dict = []
            entries_pb = []
            
            for i in range(size):
                timestamp = datetime.now().isoformat()
                metadata = {
                    "user_id": f"user_{i % 1000}",
                    "session_id": f"session_{i % 100}",
                    "request_path": f"/api/endpoint/{i % 20}",
                    "user_agent": "Mozilla/5.0 (compatible benchmark)",
                    "ip_address": f"192.168.{(i % 255)}.{((i * 7) % 255)}",
                    "version": "1.2.3"
                }
                
                entry_dict = {
                    "timestamp": timestamp,
                    "level": ["INFO", "WARN", "ERROR"][i % 3],
                    "service": f"service-{i % 10}",
                    "message": f"Processing request {i} with detailed logging information that represents realistic log message length",
                    "request_id": f"req-{i:08d}",
                    "processing_time_ms": (i % 1000) + 1,
                    "metadata": metadata
                }
                entries_dict.append(entry_dict)
                
                pb_entry = processor.create_log_entry_protobuf(
                    timestamp=timestamp,
                    level=entry_dict["level"],
                    service=entry_dict["service"],
                    message=entry_dict["message"],
                    request_id=entry_dict["request_id"],
                    processing_time_ms=entry_dict["processing_time_ms"],
                    metadata=metadata
                )
                entries_pb.append(pb_entry)
            
            # Test JSON serialization
            start_time = time.time()
            json_data = json.dumps(entries_dict)
            json_serialize_time = (time.time() - start_time) * 1000
            json_serialize_times.append(json_serialize_time)
            json_sizes.append(len(json_data.encode('utf-8')))
            
            # Test JSON deserialization
            start_time = time.time()
            json.loads(json_data)
            json_deserialize_time = (time.time() - start_time) * 1000
            json_deserialize_times.append(json_deserialize_time)
            
            # Test Protocol Buffers serialization
            pb_batch = processor.create_log_batch(entries_pb)
            start_time = time.time()
            pb_data = processor.serialize_protobuf(pb_batch)
            pb_serialize_time = (time.time() - start_time) * 1000
            pb_serialize_times.append(pb_serialize_time)
            pb_sizes.append(len(pb_data))
            
            # Test Protocol Buffers deserialization
            start_time = time.time()
            processor.deserialize_protobuf(pb_data)
            pb_deserialize_time = (time.time() - start_time) * 1000
            pb_deserialize_times.append(pb_deserialize_time)
        
        # Calculate statistics
        result = {
            "entry_count": size,
            "json": {
                "serialize_ms_avg": statistics.mean(json_serialize_times),
                "serialize_ms_std": statistics.stdev(json_serialize_times) if len(json_serialize_times) > 1 else 0,
                "deserialize_ms_avg": statistics.mean(json_deserialize_times),
                "deserialize_ms_std": statistics.stdev(json_deserialize_times) if len(json_deserialize_times) > 1 else 0,
                "size_bytes_avg": statistics.mean(json_sizes),
                "throughput_entries_per_sec": size / (statistics.mean(json_serialize_times) / 1000)
            },
            "protobuf": {
                "serialize_ms_avg": statistics.mean(pb_serialize_times),
                "serialize_ms_std": statistics.stdev(pb_serialize_times) if len(pb_serialize_times) > 1 else 0,
                "deserialize_ms_avg": statistics.mean(pb_deserialize_times),
                "deserialize_ms_std": statistics.stdev(pb_deserialize_times) if len(pb_deserialize_times) > 1 else 0,
                "size_bytes_avg": statistics.mean(pb_sizes),
                "throughput_entries_per_sec": size / (statistics.mean(pb_serialize_times) / 1000)
            }
        }
        
        # Calculate improvements
        size_reduction = ((result["json"]["size_bytes_avg"] - result["protobuf"]["size_bytes_avg"]) / result["json"]["size_bytes_avg"]) * 100
        serialize_speedup = result["protobuf"]["throughput_entries_per_sec"] / result["json"]["throughput_entries_per_sec"]
        
        result["improvements"] = {
            "size_reduction_percent": size_reduction,
            "serialize_speedup_factor": serialize_speedup
        }
        
        results.append(result)
        
        # Display results for this test size
        print(f"   JSON:     {result['json']['serialize_ms_avg']:.2f}ms serialize, {result['json']['size_bytes_avg']:,.0f} bytes")
        print(f"   Protobuf: {result['protobuf']['serialize_ms_avg']:.2f}ms serialize, {result['protobuf']['size_bytes_avg']:,.0f} bytes")
        print(f"   Improvement: {size_reduction:.1f}% smaller, {serialize_speedup:.1f}x faster")
    
    # Summary report
    print(f"\n📈 Benchmark Summary")
    print("=" * 50)
    print(f"{'Entries':<10} {'JSON (ms)':<12} {'Protobuf (ms)':<15} {'Size Reduction':<15} {'Speed Improvement'}")
    print("-" * 70)
    
    for result in results:
        print(f"{result['entry_count']:<10,} "
              f"{result['json']['serialize_ms_avg']:<12.1f} "
              f"{result['protobuf']['serialize_ms_avg']:<15.1f} "
              f"{result['improvements']['size_reduction_percent']:<15.1f}% "
              f"{result['improvements']['serialize_speedup_factor']:<.1f}x")
    
    return results

if __name__ == "__main__":
    run_comprehensive_benchmark()
