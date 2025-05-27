"""
Avro Schema Evolution Handler
Demonstrates backward and forward compatibility in distributed log processing
"""

import json
import io
from typing import Dict, Any, Optional, List, Union
from pathlib import Path
import avro.schema
import avro.io
from avro.datafile import DataFileWriter, DataFileReader


class AvroSchemaManager:
    """
    Manages schema evolution for the distributed log processing system.
    
    This class demonstrates how real-world systems like LinkedIn's Kafka
    handle schema changes without breaking existing producers/consumers.
    """
    
    def __init__(self, schema_dir: str = "src/schemas"):
        self.schema_dir = Path(schema_dir)
        self.schemas: Dict[str, avro.schema.Schema] = {}
        self.compatibility_matrix: Dict[str, List[str]] = {}
        self._load_all_schemas()
        self._build_compatibility_matrix()
    
    def _load_all_schemas(self) -> None:
        """Load all available schema versions from disk"""
        schema_files = {
            "v1": "log_event_v1.avsc",
            "v2": "log_event_v2.avsc", 
            "v3": "log_event_v3.avsc"
        }
        
        for version, filename in schema_files.items():
            schema_path = self.schema_dir / filename
            if schema_path.exists():
                with open(schema_path, 'r') as f:
                    schema_dict = json.load(f)
                    # Parse the schema - this validates it's syntactically correct
                    self.schemas[version] = avro.schema.parse(json.dumps(schema_dict))
                    print(f"✓ Loaded schema {version}")
            else:
                print(f"⚠ Schema file not found: {schema_path}")
    
    def _build_compatibility_matrix(self) -> None:
        """
        Build compatibility matrix showing which schema versions can read others.
        In real systems, this would be managed by Schema Registry (Confluent/Red Hat)
        """
        # For our educational example, we know the compatibility rules
        self.compatibility_matrix = {
            "v1": ["v1"],           # v1 can only read v1
            "v2": ["v1", "v2"],     # v2 can read v1 and v2 (backward compatible)
            "v3": ["v1", "v2", "v3"]  # v3 can read all (fully backward compatible)
        }
    
    def serialize(self, data: Dict[str, Any], writer_schema_version: str) -> bytes:
        """
        Serialize data using specified schema version.
        
        Args:
            data: Dictionary containing the log event data
            writer_schema_version: Schema version to use for serialization
            
        Returns:
            Serialized bytes that include schema fingerprint
        """
        if writer_schema_version not in self.schemas:
            raise ValueError(f"Unknown schema version: {writer_schema_version}")
        
        writer_schema = self.schemas[writer_schema_version]
        
        # Create binary encoder
        bytes_writer = io.BytesIO()
        encoder = avro.io.BinaryEncoder(bytes_writer)
        datum_writer = avro.io.DatumWriter(writer_schema)
        
        # Write the data - Avro handles type validation automatically
        datum_writer.write(data, encoder)
        
        return bytes_writer.getvalue()
    
    def deserialize(self, serialized_data: bytes, writer_schema_version: str, 
                   reader_schema_version: str) -> Dict[str, Any]:
        """
        Deserialize data with schema evolution support.
        
        This is where the magic happens - demonstrating how newer consumers
        can read older data formats and vice versa.
        
        Args:
            serialized_data: The binary data to deserialize
            writer_schema_version: Schema used when data was written
            reader_schema_version: Schema the consumer expects
            
        Returns:
            Deserialized data as dictionary
        """
        writer_schema = self.schemas[writer_schema_version]
        reader_schema = self.schemas[reader_schema_version]
        
        # Check compatibility - in production this would be cached
        if not self._are_compatible(writer_schema_version, reader_schema_version):
            raise ValueError(f"Incompatible schemas: writer={writer_schema_version}, reader={reader_schema_version}")
        
        # Create decoder with schema evolution support
        bytes_reader = io.BytesIO(serialized_data)
        decoder = avro.io.BinaryDecoder(bytes_reader)
        datum_reader = avro.io.DatumReader(writer_schema, reader_schema)
        
        # Avro automatically handles field mapping, defaults, and compatibility
        return datum_reader.read(decoder)
    
    def _are_compatible(self, writer_version: str, reader_version: str) -> bool:
        """Check if reader schema can understand writer schema"""
        return writer_version in self.compatibility_matrix.get(reader_version, [])
    
    def get_compatibility_info(self) -> Dict[str, Any]:
        """Return detailed compatibility information for monitoring"""
        return {
            "available_schemas": list(self.schemas.keys()),
            "compatibility_matrix": self.compatibility_matrix,
            "schema_details": {
                version: {
                    "fields": [field.name for field in schema.fields],
                    "field_count": len(schema.fields)
                }
                for version, schema in self.schemas.items()
            }
        }


class LogEventProcessor:
    """
    Processes log events with different schema versions.
    Simulates a real distributed system where different services use different versions.
    """
    
    def __init__(self):
        self.schema_manager = AvroSchemaManager()
        self.processed_events = []
    
    def process_event(self, event_data: Dict[str, Any], schema_version: str) -> str:
        """Process a log event and demonstrate schema evolution"""
        try:
            # Serialize the event (what a producer would do)
            serialized = self.schema_manager.serialize(event_data, schema_version)
            
            # Simulate different consumers reading with different schema versions
            results = {}
            for consumer_version in ["v1", "v2", "v3"]:
                try:
                    deserialized = self.schema_manager.deserialize(
                        serialized, schema_version, consumer_version
                    )
                    results[f"consumer_{consumer_version}"] = "✓ SUCCESS"
                except ValueError as e:
                    results[f"consumer_{consumer_version}"] = f"✗ FAILED: {str(e)}"
            
            self.processed_events.append({
                "original_data": event_data,
                "writer_schema": schema_version,
                "consumer_results": results,
                "serialized_size": len(serialized)
            })
            
            return f"Event processed with schema {schema_version}. Size: {len(serialized)} bytes"
            
        except Exception as e:
            return f"Error processing event: {str(e)}"
    
    def get_processing_summary(self) -> Dict[str, Any]:
        """Get summary of all processed events for analysis"""
        if not self.processed_events:
            return {"message": "No events processed yet"}
        
        return {
            "total_events": len(self.processed_events),
            "events": self.processed_events,
            "compatibility_stats": self._calculate_compatibility_stats()
        }
    
    def _calculate_compatibility_stats(self) -> Dict[str, int]:
        """Calculate compatibility statistics across all processed events"""
        stats = {"total_successes": 0, "total_failures": 0}
        
        for event in self.processed_events:
            for result in event["consumer_results"].values():
                if "SUCCESS" in result:
                    stats["total_successes"] += 1
                else:
                    stats["total_failures"] += 1
        
        return stats
