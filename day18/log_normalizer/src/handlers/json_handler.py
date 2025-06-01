import json
from datetime import datetime
from typing import Dict, Any
from .base import BaseHandler
from ..models.log_entry import LogEntry

class JsonHandler(BaseHandler):
    def can_handle(self, raw_data: bytes) -> float:
        """Check if data is valid JSON"""
        try:
            json.loads(raw_data.decode('utf-8'))
            return 0.9
        except (json.JSONDecodeError, UnicodeDecodeError):
            return 0.0
    
    def parse(self, raw_data: bytes) -> LogEntry:
        """Parse JSON log entry"""
        try:
            data = json.loads(raw_data.decode('utf-8'))
            
            # Extract standard fields with fallbacks
            timestamp = self._parse_timestamp(data.get('timestamp', data.get('time', datetime.now().isoformat())))
            level = data.get('level', data.get('severity', 'INFO')).upper()
            message = data.get('message', data.get('msg', str(data)))
            source = data.get('source', data.get('service', 'unknown'))
            
            # Everything else goes to metadata
            metadata = {k: v for k, v in data.items() 
                       if k not in ['timestamp', 'time', 'level', 'severity', 'message', 'msg', 'source', 'service']}
            
            return LogEntry(
                timestamp=timestamp,
                level=level,
                message=message,
                source=source,
                metadata=metadata
            )
        except Exception as e:
            raise ValueError(f"Failed to parse JSON log: {e}")
    
    def _parse_timestamp(self, timestamp_str: str) -> datetime:
        """Parse various timestamp formats"""
        try:
            return datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
        except:
            return datetime.now()
