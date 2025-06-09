"""
Integration tests for the complete Protocol Buffers log system
"""

import pytest
import sys
import os
import time
from datetime import datetime

# Add paths
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'proto'))

from protobuf_log_processor import ProtobufLogProcessor
import log_entry_pb2

class TestIntegration:
    
    def setup_method(self):
        """Setup test environment"""
        self.processor = ProtobufLogProcessor()
    
    def test_end_to_end_log_processing(self):
        """Test complete end-to-end log processing workflow"""
        # Step 1: Create multiple log entries
        log_entries = []
        test_data = [
            ("INFO", "user-service", "User login successful", {"user_id": "12345"}),
            ("ERROR", "payment-service", "Payment processing failed", {"error_code": "PAY_001"}),
            ("WARN", "cache-service", "Cache miss detected", {"cache_key": "user_profile_12345"}),
            ("INFO", "notification-service", "Email sent successfully", {"recipient": "user@example.com"}),
            ("ERROR", "database-service", "Connection timeout", {"timeout_ms": "5000"})
        ]
        
        for i, (level, service, message, metadata) in enumerate(test_data):
            entry = self.processor.create_log_entry_protobuf(
                timestamp=datetime.now().isoformat(),
                level=level,
                service=service,
                message=message,
                request_id=f"req-{i+1:03d}",
                processing_time_ms=(i + 1) * 25,
                metadata=metadata
            )
            log_entries.append(entry)
        
        # Step 2: Create batch
        batch = self.processor.create_log_batch(log_entries, "integration-test-batch")
        assert len(batch.entries) == 5
        assert batch.batch_id == "integration-test-batch"
        
        # Step 3: Serialize batch
        serialized_data = self.processor.serialize_protobuf(batch)
        assert isinstance(serialized_data, bytes)
        assert len(serialized_data) > 0
        
        # Step 4: Deserialize batch
        deserialized_batch = self.processor.deserialize_protobuf(serialized_data)
        assert len(deserialized_batch.entries) == 5
        
        # Step 5: Verify data integrity
        for i, original_data in enumerate(test_data):
            restored_entry = deserialized_batch.entries[i]
            level, service, message, metadata = original_data
            
            assert restored_entry.level == level
            assert restored_entry.service == service
            assert restored_entry.message == message
            assert restored_entry.request_id == f"req-{i+1:03d}"
            assert restored_entry.processing_time_ms == (i + 1) * 25
            
            # Verify metadata
            for key, value in metadata.items():
                assert restored_entry.metadata[key] == value
    
    def test_performance_under_load(self):
        """Test system performance under load"""
        entry_counts = [100, 500, 1000]
        results = []
        
        for count in entry_counts:
            start_time = time.time()
            
            # Create entries
            entries = []
            for i in range(count):
                entry = self.processor.create_log_entry_protobuf(
                    timestamp=datetime.now().isoformat(),
                    level="INFO" if i % 2 == 0 else "ERROR",
                    service=f"service-{i % 10}",
                    message=f"Load test message {i}",
                    request_id=f"load-{i:06d}",
                    processing_time_ms=i % 100,
                    metadata={"test": "load", "iteration": str(i)}
                )
                entries.append(entry)
            
            # Create and serialize batch
            batch = self.processor.create_log_batch(entries, f"load-test-{count}")
            serialized_data = self.processor.serialize_protobuf(batch)
            
            # Deserialize
            deserialized_batch = self.processor.deserialize_protobuf(serialized_data)
            
            end_time = time.time()
            processing_time = end_time - start_time
            
            results.append({
                "entry_count": count,
                "processing_time_seconds": processing_time,
                "serialized_size_bytes": len(serialized_data),
                "entries_per_second": count / processing_time
            })
            
            # Verify all entries were processed correctly
            assert len(deserialized_batch.entries) == count
        
        # Verify performance scaling
        for result in results:
            # Should process at least 1000 entries per second
            assert result["entries_per_second"] > 1000, f"Performance too slow: {result['entries_per_second']} entries/sec"
        
        print(f"\n📊 Performance Results:")
        for result in results:
            print(f"   {result['entry_count']:,} entries: {result['entries_per_second']:,.0f} entries/sec, {result['serialized_size_bytes']:,} bytes")
    
    def test_error_handling_and_recovery(self):
        """Test error handling and recovery scenarios"""
        # Test with invalid data
        with pytest.raises(Exception):
            self.processor.deserialize_protobuf(b"invalid_protobuf_data")
        
        # Test with empty batch
        empty_batch = self.processor.create_log_batch([])
        serialized_empty = self.processor.serialize_protobuf(empty_batch)
        deserialized_empty = self.processor.deserialize_protobuf(serialized_empty)
        assert len(deserialized_empty.entries) == 0
        
        # Test with large metadata
        large_metadata = {f"key_{i}": f"value_{i}" * 100 for i in range(50)}
        entry_with_large_metadata = self.processor.create_log_entry_protobuf(
            timestamp=datetime.now().isoformat(),
            level="INFO",
            service="test-service",
            message="Testing large metadata",
            metadata=large_metadata
        )
        
        batch = self.processor.create_log_batch([entry_with_large_metadata])
        serialized_data = self.processor.serialize_protobuf(batch)
        deserialized_batch = self.processor.deserialize_protobuf(serialized_data)
        
        # Verify large metadata was preserved
        assert len(deserialized_batch.entries) == 1
        restored_entry = deserialized_batch.entries[0]
        assert len(restored_entry.metadata) == 50
        for key, value in large_metadata.items():
            assert restored_entry.metadata[key] == value

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
