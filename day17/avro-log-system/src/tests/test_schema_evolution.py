"""
Comprehensive test suite for Avro schema evolution
Tests backward/forward compatibility and real-world scenarios
"""

import pytest
import sys
import os
from pathlib import Path

# Add src to Python path
sys.path.append(str(Path(__file__).parent.parent.parent))

from src.serializers.avro_handler import AvroSchemaManager, LogEventProcessor
from src.models.log_event import LogEventV1, LogEventV2, LogEventV3, create_log_event


class TestSchemaEvolution:
    """Test schema evolution capabilities"""
    
    def setup_method(self):
        """Setup for each test method"""
        self.schema_manager = AvroSchemaManager()
        self.processor = LogEventProcessor()
    
    def test_schema_loading(self):
        """Test that all schema versions load correctly"""
        assert "v1" in self.schema_manager.schemas
        assert "v2" in self.schema_manager.schemas  
        assert "v3" in self.schema_manager.schemas
        
        # Verify each schema has expected field count
        v1_fields = len(self.schema_manager.schemas["v1"].fields)
        v2_fields = len(self.schema_manager.schemas["v2"].fields)
        v3_fields = len(self.schema_manager.schemas["v3"].fields)
        
        assert v1_fields == 4  # timestamp, level, message, service_name
        assert v2_fields == 6  # v1 + request_id, user_id
        assert v3_fields == 8  # v2 + duration_ms, memory_usage_mb
    
    def test_backward_compatibility_v1_to_v2(self):
        """Test that v2 schema can read v1 data"""
        # Create v1 event
        v1_event = LogEventV1.create_sample(
            message="User authentication successful",
            level="INFO"
        )
        
        # Serialize with v1 schema
        serialized = self.schema_manager.serialize(v1_event.to_dict(), "v1")
        
        # Deserialize with v2 schema (should work with defaults)
        deserialized = self.schema_manager.deserialize(serialized, "v1", "v2")
        
        # Verify core fields preserved
        assert deserialized["timestamp"] == v1_event.timestamp
        assert deserialized["level"] == v1_event.level
        assert deserialized["message"] == v1_event.message
        assert deserialized["service_name"] == v1_event.service_name
        
        # Verify new fields have default values
        assert deserialized["request_id"] is None
        assert deserialized["user_id"] is None
    
    def test_backward_compatibility_v2_to_v3(self):
        """Test that v3 schema can read v2 data"""
        v2_event = LogEventV2.create_sample(
            message="API request processed",
            level="INFO"
        )
        
        serialized = self.schema_manager.serialize(v2_event.to_dict(), "v2")
        deserialized = self.schema_manager.deserialize(serialized, "v2", "v3")
        
        # Verify all v2 fields preserved
        assert deserialized["request_id"] == v2_event.request_id
        assert deserialized["user_id"] == v2_event.user_id
        
        # Verify v3 fields have defaults
        assert deserialized["duration_ms"] is None
        assert deserialized["memory_usage_mb"] is None
    
    def test_forward_compatibility_v3_to_v1(self):
        """Test that v1 schema can read v3 data (ignoring new fields)"""
        v3_event = LogEventV3.create_sample(
            message="Performance metrics collected",
            duration_ms=45.7,
            memory_usage_mb=23.4
        )
        
        serialized = self.schema_manager.serialize(v3_event.to_dict(), "v3")
        deserialized = self.schema_manager.deserialize(serialized, "v3", "v1")
        
        # Verify only v1 fields are present
        expected_fields = {"timestamp", "level", "message", "service_name"}
        assert set(deserialized.keys()) == expected_fields
        
        # Verify values are correct
        assert deserialized["message"] == v3_event.message
        assert deserialized["level"] == v3_event.level
    
    def test_full_compatibility_chain(self):
        """Test complete compatibility chain across all versions"""
        # Test data that works across all versions
        base_data = {
            "timestamp": "2025-05-27T10:30:00Z",
            "level": "WARN", 
            "message": "Rate limit approaching",
            "service_name": "rate-limiter"
        }
        
        # Test serialization with each version
        for writer_version in ["v1", "v2", "v3"]:
            serialized = self.schema_manager.serialize(base_data, writer_version)
            
            # Test deserialization with each compatible reader version  
            for reader_version in ["v1", "v2", "v3"]:
                if self.schema_manager._are_compatible(writer_version, reader_version):
                    deserialized = self.schema_manager.deserialize(
                        serialized, writer_version, reader_version
                    )
                    # Basic fields should always be preserved
                    assert deserialized["message"] == base_data["message"]
                    assert deserialized["level"] == base_data["level"]
    
    def test_incompatible_schemas(self):
        """Test handling of incompatible schema combinations"""
        # For our current setup, all combinations are compatible
        # But let's test the compatibility checking logic
        
        # This would fail if we had a breaking change
        # For example, if v4 removed a required field
        base_data = {
            "timestamp": "2025-05-27T10:30:00Z",
            "level": "ERROR",
            "message": "System failure",
            "service_name": "critical-service"
        }
        
        serialized = self.schema_manager.serialize(base_data, "v1")
        
        # This should work (v1 -> v1)
        result = self.schema_manager.deserialize(serialized, "v1", "v1")
        assert result["message"] == base_data["message"]
    
    def test_event_processor_integration(self):
        """Test the LogEventProcessor with different schema versions"""
        # Test processing events with different versions
        events = [
            (create_log_event("v1", level="DEBUG"), "v1"),
            (create_log_event("v2", level="INFO"), "v2"), 
            (create_log_event("v3", level="ERROR"), "v3")
        ]
        
        for event, version in events:
            result = self.processor.process_event(event.to_dict(), version)
            assert "Event processed" in result
            assert version in result
        
        # Verify processing summary
        summary = self.processor.get_processing_summary()
        assert summary["total_events"] == 3
        assert summary["compatibility_stats"]["total_successes"] > 0
    
    def test_serialization_size_efficiency(self):
        """Test that Avro provides good compression"""
        import json
        
        # Create a complex v3 event
        v3_event = LogEventV3.create_sample(
            message="Complex operation with detailed logging and performance metrics",
            duration_ms=123.45,
            memory_usage_mb=67.89
        )
        
        # Compare Avro serialization vs JSON
        avro_serialized = self.schema_manager.serialize(v3_event.to_dict(), "v3")
        json_serialized = json.dumps(v3_event.to_dict()).encode('utf-8')
        
        # Avro should be more compact (though exact ratio depends on data)
        print(f"Avro size: {len(avro_serialized)} bytes")
        print(f"JSON size: {len(json_serialized)} bytes")
        print(f"Compression ratio: {len(avro_serialized)/len(json_serialized):.2f}")
        
        # At minimum, Avro shouldn't be dramatically larger
        assert len(avro_serialized) <= len(json_serialized) * 1.5
    
    def test_schema_compatibility_matrix(self):
        """Test the compatibility matrix functionality"""
        info = self.schema_manager.get_compatibility_info()
        
        # Verify structure
        assert "available_schemas" in info
        assert "compatibility_matrix" in info
        assert "schema_details" in info
        
        # Verify backward compatibility rules
        matrix = info["compatibility_matrix"]
        assert "v1" in matrix["v2"]  # v2 can read v1
        assert "v1" in matrix["v3"]  # v3 can read v1  
        assert "v2" in matrix["v3"]  # v3 can read v2


class TestRealWorldScenarios:
    """Test real-world scenarios that might occur in production"""
    
    def setup_method(self):
        self.schema_manager = AvroSchemaManager()
    
    def test_gradual_rollout_scenario(self):
        """
        Simulate gradual rollout where producers and consumers
        are updated at different times
        """
        # Old producer (v1) sending to new consumer (v3)
        old_producer_data = {
            "timestamp": "2025-05-27T12:00:00Z",
            "level": "INFO",
            "message": "Legacy system event", 
            "service_name": "legacy-service"
        }
        
        serialized = self.schema_manager.serialize(old_producer_data, "v1")
        
        # New consumer should handle this gracefully
        deserialized = self.schema_manager.deserialize(serialized, "v1", "v3")
        
        assert deserialized["message"] == old_producer_data["message"]
        assert deserialized["request_id"] is None  # New field gets default
        assert deserialized["duration_ms"] is None  # New field gets default
    
    def test_mixed_version_environment(self):
        """Test environment with multiple service versions running simultaneously"""
        # Simulate different services using different schema versions
        services = [
            ("auth-service", "v1", {"level": "INFO", "message": "User login"}),
            ("api-gateway", "v2", {"level": "WARN", "message": "Rate limit hit"}),
            ("metrics-collector", "v3", {"level": "DEBUG", "message": "Metrics gathered"})
        ]
        
        serialized_events = []
        
        # Each service serializes with its schema version
        for service_name, version, extra_data in services:
            base_data = {
                "timestamp": "2025-05-27T12:00:00Z",
                "service_name": service_name,
                **extra_data
            }
            serialized = self.schema_manager.serialize(base_data, version) 
            serialized_events.append((serialized, version))
        
        # Central log processor using v3 schema should handle all
        for serialized, writer_version in serialized_events:
            deserialized = self.schema_manager.deserialize(serialized, writer_version, "v3")
            assert "timestamp" in deserialized
            assert "service_name" in deserialized
            assert "message" in deserialized


if __name__ == "__main__":
    # Run tests with verbose output
    pytest.main([__file__, "-v", "--tb=short"])
