import json
from typing import Dict, Type, Optional
from .handlers.base import BaseHandler
from .handlers.json_handler import JsonHandler
from .handlers.text_handler import TextHandler
from .handlers.protobuf_handler import ProtobufHandler
from .handlers.avro_handler import AvroHandler
from .models.log_entry import LogEntry

class LogNormalizer:
    """Core log normalization engine"""
    
    def __init__(self):
        self.handlers: Dict[str, BaseHandler] = {}
        self._register_default_handlers()
    
    def _register_default_handlers(self):
        """Register built-in format handlers"""
        self.register_handler('json', JsonHandler())
        self.register_handler('text', TextHandler())
        self.register_handler('protobuf', ProtobufHandler())
        self.register_handler('avro', AvroHandler())
    
    def register_handler(self, name: str, handler: BaseHandler):
        """Register a new format handler"""
        self.handlers[name] = handler
    
    def detect_format(self, raw_data: bytes) -> str:
        """Auto-detect the format of incoming log data"""
        best_handler = None
        best_score = 0.0
        
        for name, handler in self.handlers.items():
            score = handler.can_handle(raw_data)
            if score > best_score:
                best_score = score
                best_handler = name
        
        return best_handler or 'text'
    
    def normalize(self, raw_data: bytes, format_hint: Optional[str] = None) -> LogEntry:
        """Transform raw log data into standardized format"""
        format_name = format_hint or self.detect_format(raw_data)
        handler = self.handlers.get(format_name)
        
        if not handler:
            raise ValueError(f"No handler registered for format: {format_name}")
        
        return handler.parse(raw_data)
    
    def transform(self, raw_data: bytes, target_format: str) -> bytes:
        """Normalize and convert to target format"""
        entry = self.normalize(raw_data)
        
        if target_format == 'json':
            return entry.json().encode('utf-8')
        elif target_format == 'text':
            return f"{entry.timestamp} {entry.level} {entry.message}".encode('utf-8')
        else:
            raise ValueError(f"Unsupported target format: {target_format}")
