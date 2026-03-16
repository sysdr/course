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
