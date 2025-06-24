import json
import time
from datetime import datetime
from typing import Dict, Any, Optional

class LogEntry:
    def __init__(self, level: str, message: str, source: str, 
                 timestamp: Optional[float] = None, **kwargs):
        self.level = level.upper()
        self.message = message
        self.source = source
        self.timestamp = timestamp or time.time()
        self.metadata = kwargs
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'LogEntry':
        """Create LogEntry from dictionary"""
        level = data.get('level', 'INFO')
        message = data.get('message', '')
        source = data.get('source', 'unknown')
        timestamp = data.get('timestamp')
        
        # Extract metadata (any additional fields)
        metadata = {k: v for k, v in data.items() 
                   if k not in ['level', 'message', 'source', 'timestamp']}
        
        return cls(level, message, source, timestamp, **metadata)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            'level': self.level,
            'message': self.message,
            'source': self.source,
            'timestamp': self.timestamp,
            'formatted_time': datetime.fromtimestamp(self.timestamp).isoformat(),
            **self.metadata
        }
    
    def to_json(self) -> str:
        """Convert to JSON string"""
        return json.dumps(self.to_dict())
