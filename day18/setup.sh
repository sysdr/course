#!/bin/bash

# Log Normalizer Setup Script - Day 18
# Creates complete project structure and runs all tests

echo "🚀 Setting up Log Normalizer Project..."

# Create project structure
mkdir -p log_normalizer/{src/{handlers,models},tests,sample_logs}
cd log_normalizer

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Create requirements.txt
cat > requirements.txt << 'EOF'
protobuf>=4.21.0
avro-python3>=1.10.0
pytest>=7.0.0
pytest-cov>=4.0.0
structlog>=22.0.0
pydantic>=1.10.0
EOF

# Install dependencies
pip install -r requirements.txt

# Create base handler interface
cat > src/handlers/base.py << 'EOF'
from abc import ABC, abstractmethod
from typing import Dict, Any
from ..models.log_entry import LogEntry

class BaseHandler(ABC):
    @abstractmethod
    def can_handle(self, raw_data: bytes) -> float:
        """Return confidence score (0-1) for handling this data format"""
        pass
    
    @abstractmethod
    def parse(self, raw_data: bytes) -> LogEntry:
        """Parse raw data into standardized LogEntry"""
        pass
EOF

# Create standardized log model
cat > src/models/log_entry.py << 'EOF'
from datetime import datetime
from typing import Dict, Any, Optional
from pydantic import BaseModel

class LogEntry(BaseModel):
    timestamp: datetime
    level: str
    message: str
    source: str
    metadata: Dict[str, Any] = {}
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
EOF

# Create core normalizer
cat > src/normalizer.py << 'EOF'
import json
from typing import Dict, Type, Optional
from .handlers.base import BaseHandler
from .handlers.json_handler import JsonHandler
from .handlers.text_handler import TextHandler
from .models.log_entry import LogEntry

class LogNormalizer:
    def __init__(self):
        self.handlers: Dict[str, BaseHandler] = {}
        self._register_default_handlers()
    
    def _register_default_handlers(self):
        """Register built-in format handlers"""
        self.register_handler('json', JsonHandler())
        self.register_handler('text', TextHandler())
    
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
        
        return best_handler or 'text'  # Default to text
    
    def normalize(self, raw_data: bytes, format_hint: Optional[str] = None) -> LogEntry:
        """Transform raw log data into standardized format"""
        format_name = format_hint or self.detect_format(raw_data)
        handler = self.handlers.get(format_name)
        
        if not handler:
            raise ValueError(f"No handler registered for format: {format_name}")
        
        return handler.parse(raw_data)
EOF

# Create JSON handler
cat > src/handlers/json_handler.py << 'EOF'
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
EOF

# Create text handler
cat > src/handlers/text_handler.py << 'EOF'
import re
from datetime import datetime
from .base import BaseHandler
from ..models.log_entry import LogEntry

class TextHandler(BaseHandler):
    # Common log patterns
    PATTERNS = [
        # Apache/Nginx style: [timestamp] level: message
        r'^\[([^\]]+)\]\s+(\w+):\s+(.+)$',
        # Syslog style: timestamp host service[pid]: message
        r'^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\w+)\s+([^:]+):\s*(.+)$',
        # Simple: timestamp level message
        r'^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(\w+)\s+(.+)$'
    ]
    
    def can_handle(self, raw_data: bytes) -> float:
        """Check if data looks like structured text log"""
        try:
            text = raw_data.decode('utf-8').strip()
            for pattern in self.PATTERNS:
                if re.match(pattern, text):
                    return 0.8
            return 0.3  # Fallback for any text
        except UnicodeDecodeError:
            return 0.0
    
    def parse(self, raw_data: bytes) -> LogEntry:
        """Parse text log using pattern matching"""
        text = raw_data.decode('utf-8').strip()
        
        for pattern in self.PATTERNS:
            match = re.match(pattern, text)
            if match:
                groups = match.groups()
                if len(groups) >= 3:
                    timestamp = self._parse_timestamp(groups[0])
                    level = groups[1].upper()
                    message = groups[2] if len(groups) == 3 else groups[3]
                    source = groups[2] if len(groups) == 4 else 'unknown'
                    
                    return LogEntry(
                        timestamp=timestamp,
                        level=level,
                        message=message,
                        source=source
                    )
        
        # Fallback for unstructured text
        return LogEntry(
            timestamp=datetime.now(),
            level='INFO',
            message=text,
            source='text-parser'
        )
    
    def _parse_timestamp(self, timestamp_str: str) -> datetime:
        """Parse common timestamp formats"""
        patterns = [
            '%Y-%m-%d %H:%M:%S',
            '%Y-%m-%dT%H:%M:%S',
            '%b %d %H:%M:%S'
        ]
        
        for pattern in patterns:
            try:
                return datetime.strptime(timestamp_str, pattern)
            except ValueError:
                continue
        
        return datetime.now()  # Fallback
EOF

# Create comprehensive tests
cat > tests/test_normalizer.py << 'EOF'
import json
import pytest
from datetime import datetime
from src.normalizer import LogNormalizer
from src.models.log_entry import LogEntry

class TestLogNormalizer:
    def setup_method(self):
        self.normalizer = LogNormalizer()
    
    def test_json_format_detection(self):
        json_log = b'{"timestamp": "2024-01-15T10:30:00", "level": "ERROR", "message": "Database connection failed"}'
        assert self.normalizer.detect_format(json_log) == 'json'
    
    def test_text_format_detection(self):
        text_log = b'2024-01-15 10:30:00 ERROR Database connection failed'
        assert self.normalizer.detect_format(text_log) == 'text'
    
    def test_json_normalization(self):
        json_log = b'{"timestamp": "2024-01-15T10:30:00", "level": "ERROR", "message": "Test error", "service": "api-gateway"}'
        result = self.normalizer.normalize(json_log)
        
        assert isinstance(result, LogEntry)
        assert result.level == 'ERROR'
        assert result.message == 'Test error'
        assert result.source == 'api-gateway'
    
    def test_text_normalization(self):
        text_log = b'2024-01-15 10:30:00 WARN Connection timeout detected'
        result = self.normalizer.normalize(text_log)
        
        assert isinstance(result, LogEntry)
        assert result.level == 'WARN'
        assert 'Connection timeout detected' in result.message
    
    def test_invalid_json_handling(self):
        invalid_json = b'{"incomplete": json data'
        # Should fall back to text handler
        result = self.normalizer.normalize(invalid_json)
        assert isinstance(result, LogEntry)
    
    def test_format_hint_override(self):
        data = b'Plain text that could be anything'
        result = self.normalizer.normalize(data, format_hint='text')
        assert isinstance(result, LogEntry)
        assert result.message == 'Plain text that could be anything'

if __name__ == '__main__':
    pytest.main([__file__, '-v'])
EOF

# Create sample log files for testing
cat > sample_logs/sample.json << 'EOF'
{"timestamp": "2024-01-15T10:30:00Z", "level": "ERROR", "message": "Database connection timeout", "service": "user-auth", "request_id": "req-123", "duration_ms": 5000}
{"timestamp": "2024-01-15T10:30:01Z", "level": "INFO", "message": "User login successful", "service": "user-auth", "user_id": "user-456"}
{"timestamp": "2024-01-15T10:30:02Z", "level": "WARN", "message": "High memory usage detected", "service": "data-processor", "memory_pct": 85}
EOF

cat > sample_logs/sample.txt << 'EOF'
2024-01-15 10:30:00 ERROR Database connection timeout
2024-01-15 10:30:01 INFO User login successful
[2024-01-15T10:30:02] WARN: High memory usage detected
EOF

# Create integration test script
cat > test_integration.py << 'EOF'
#!/usr/bin/env python3
"""Integration test for log normalizer"""

import json
from src.normalizer import LogNormalizer

def test_real_logs():
    normalizer = LogNormalizer()
    
    print("🧪 Testing JSON log normalization...")
    with open('sample_logs/sample.json', 'rb') as f:
        for line in f:
            if line.strip():
                result = normalizer.normalize(line.strip())
                print(f"✅ Normalized: {result.level} - {result.message[:50]}...")
    
    print("\n🧪 Testing text log normalization...")
    with open('sample_logs/sample.txt', 'rb') as f:
        for line in f:
            if line.strip():
                result = normalizer.normalize(line.strip())
                print(f"✅ Normalized: {result.level} - {result.message[:50]}...")
    
    print("\n🎉 All integration tests passed!")

if __name__ == '__main__':
    test_real_logs()
EOF

# Make integration test executable
chmod +x test_integration.py

# Run all tests
echo "🧪 Running unit tests..."
python -m pytest tests/ -v

echo "🧪 Running integration tests..."
python test_integration.py

echo "📊 Generating test coverage report..."
python -m pytest tests/ --cov=src --cov-report=html

echo "✅ Setup complete! Your log normalizer is ready."
echo "📁 Project structure created in: $(pwd)"
echo "🔍 View coverage report: open htmlcov/index.html"
echo "🚀 Next steps: Add Protobuf and Avro handlers for complete format support"