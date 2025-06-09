"""
Comprehensive tests for Protocol Buffers log processor
"""

import pytest
import sys
import os
from datetime import datetime

# Add src to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'proto'))

from protobuf_log_processor import ProtobufLogProcessor
import log_entry_pb2

class TestProtobufLogProcessor:
    
    def setup_method(self):
        """Setup test instance"""
        self.processor = ProtobufLogProcessor()
    
    def test_create_log_entry_protobuf(self):
        """Test Protocol Buffer log entry creation"""
        entry = self.processor.create_log_entry_protobuf(
            timestamp="2024-01-01T10:00:00",
            level="INFO",
            service="test-service",
            message="Test message",
            request_id="req-001",
            processing_time_ms=100,
            metadata={"user": "test_user"}
        )
        
        assert entry.timestamp == "2024-01-01T10:00:00"
        assert entry.level == "INFO"
        assert entry.service == "test-service"
        assert entry.message == "Test message"
        assert entry.request_id == "req-001"
        assert entry.processing_time_ms == 100
        assert entry.metadata["user"] == "test_user"
    
    def test_create_log_batch(self):
        """Test log batch creation"""
        entries = []
        for i in range(3):
            entry = self.processor.create_log_entry_protobuf(
                timestamp=datetime.now().isoformat(),
                level="INFO",
                service=f"service-{i}",
                message=f"Message {i}"
            )
            entries.append(entry)
        
        batch = self.processor.create_log_batch(entries, "test-batch")
        
        assert batch.batch_id == "test-batch"
        assert len(batch.entries) == 3
        assert batch.batch_timestamp > 0
    
    def test_serialization_deserialization(self):
        """Test Protocol Buffer serialization and deserialization"""
        # Create test entry
        entry = self.processor.create_log_entry_protobuf(
            timestamp="2024-01-01T10:00:00",
            level="ERROR",
            service="api-service",
            message="Database connection failed",
            metadata={"error_code": "DB_001", "retry_count": "3"}
        )
        
        # Create batch and serialize
        batch = self.processor.create_log_batch([entry])
        serialized_data = self.processor.serialize_protobuf(batch)
        
        # Verify serialization produces bytes
        assert isinstance(serialized_data, bytes)
        assert len(serialized_data) > 0
        
        # Deserialize and verify
        deserialized_batch = self.processor.deserialize_protobuf(serialized_data)
        
        assert len(deserialized_batch.entries) == 1
        restored_entry = deserialized_batch.entries[0]
        
        assert restored_entry.timestamp == "2024-01-01T10:00:00"
        assert restored_entry.level == "ERROR"
        assert restored_entry.service == "api-service"
        assert restored_entry.message == "Database connection failed"
        assert restored_entry.metadata["error_code"] == "DB_001"
        assert restored_entry.metadata["retry_count"] == "3"
    
    def test_performance_comparison(self):
        """Test performance comparison functionality"""
        results = self.processor.performance_comparison(100)
        
        # Verify results structure
        assert "json" in results
        assert "protobuf" in results
        
        # Verify JSON results
        json_results = results["json"]
        assert "serialize_ms" in json_results
        assert "deserialize_ms" in json_results
        assert "size_bytes" in json_results
        
        # Verify Protocol Buffers results
        pb_results = results["protobuf"]
        assert "serialize_ms" in pb_results
        assert "deserialize_ms" in pb_results
        assert "size_bytes" in pb_results
        
        # Protocol Buffers should be smaller and faster
        assert pb_results["size_bytes"] < json_results["size_bytes"]
    
    def test_empty_batch_handling(self):
        """Test handling of empty batches"""
        batch = self.processor.create_log_batch([])
        serialized_data = self.processor.serialize_protobuf(batch)
        deserialized_batch = self.processor.deserialize_protobuf(serialized_data)
        
        assert len(deserialized_batch.entries) == 0
        assert deserialized_batch.batch_id is not None

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
