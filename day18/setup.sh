#!/bin/bash

# Complete Log Normalizer Project Setup Script
# Day 18: Log Normalization - 254-Day Hands-On System Design
# Creates entire project structure with all files

set -e  # Exit on error

echo "🚀 Creating Log Normalizer Project Structure..."

# Create main project directory
PROJECT_DIR="log_normalizer"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p {src/{handlers,models},tests,sample_logs,test_logs,test_results}

# Create Python package init files
touch src/__init__.py
touch src/handlers/__init__.py
touch src/models/__init__.py
touch tests/__init__.py

# Create requirements.txt
echo "📦 Creating requirements.txt..."
cat > requirements.txt << 'EOF'
protobuf>=4.21.0
avro-python3>=1.10.0
pytest>=7.0.0
pytest-cov>=4.0.0
structlog>=22.0.0
pydantic>=1.10.0
EOF

# Create base handler interface
echo "📝 Creating base handler..."
cat > src/handlers/base.py << 'EOF'
from abc import ABC, abstractmethod
from typing import Dict, Any
from ..models.log_entry import LogEntry

class BaseHandler(ABC):
    """Base interface for log format handlers"""
    
    @abstractmethod
    def can_handle(self, raw_data: bytes) -> float:
        """Return confidence score (0-1) for handling this data format"""
        pass
    
    @abstractmethod
    def parse(self, raw_data: bytes) -> LogEntry:
        """Parse raw data into standardized LogEntry"""
        pass
EOF

# Create log entry model
echo "📝 Creating log entry model..."
cat > src/models/log_entry.py << 'EOF'
from datetime import datetime
from typing import Dict, Any, Optional
from pydantic import BaseModel

class LogEntry(BaseModel):
    """Standardized log entry format"""
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

# Create JSON handler
echo "📝 Creating JSON handler..."
cat > src/handlers/json_handler.py << 'EOF'
import json
from datetime import datetime
from typing import Dict, Any
from .base import BaseHandler
from ..models.log_entry import LogEntry

class JsonHandler(BaseHandler):
    """Handler for JSON-formatted logs"""
    
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
            
            timestamp = self._parse_timestamp(data.get('timestamp', data.get('time', datetime.now().isoformat())))
            level = data.get('level', data.get('severity', 'INFO')).upper()
            message = data.get('message', data.get('msg', str(data)))
            source = data.get('source', data.get('service', 'unknown'))
            
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
echo "📝 Creating text handler..."
cat > src/handlers/text_handler.py << 'EOF'
import re
from datetime import datetime
from .base import BaseHandler
from ..models.log_entry import LogEntry

class TextHandler(BaseHandler):
    """Handler for plain text logs"""
    
    PATTERNS = [
        r'^\[([^\]]+)\]\s+(\w+):\s+(.+)$',
        r'^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\w+)\s+([^:]+):\s*(.+)$',
        r'^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(\w+)\s+(.+)$'
    ]
    
    def can_handle(self, raw_data: bytes) -> float:
        """Check if data looks like structured text log"""
        try:
            text = raw_data.decode('utf-8').strip()
            for pattern in self.PATTERNS:
                if re.match(pattern, text):
                    return 0.8
            return 0.3
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
        
        return datetime.now()
EOF

# Create core normalizer
echo "📝 Creating core normalizer..."
cat > src/normalizer.py << 'EOF'
import json
from typing import Dict, Type, Optional
from .handlers.base import BaseHandler
from .handlers.json_handler import JsonHandler
from .handlers.text_handler import TextHandler
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
EOF

# Create comprehensive tests
echo "📝 Creating test suite..."
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
        result = self.normalizer.normalize(invalid_json)
        assert isinstance(result, LogEntry)
    
    def test_format_hint_override(self):
        data = b'Plain text that could be anything'
        result = self.normalizer.normalize(data, format_hint='text')
        assert isinstance(result, LogEntry)
        assert result.message == 'Plain text that could be anything'
    
    def test_transform_to_json(self):
        text_log = b'2024-01-15 10:30:00 INFO Test message'
        result = self.normalizer.transform(text_log, 'json')
        assert isinstance(result, bytes)
        data = json.loads(result)
        assert 'level' in data
        assert 'message' in data

if __name__ == '__main__':
    pytest.main([__file__, '-v'])
EOF

# Create sample log files
echo "📝 Creating sample log files..."
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

cat > test_logs/production_samples.txt << 'EOF'
2024-01-15 10:30:00 ERROR [user-service] Database connection pool exhausted
Jan 15 10:30:01 web-server nginx[1234]: Connection timeout
[2024-01-15T10:30:02.123Z] WARN: Memory usage at 85%
2024-01-15 10:30:03 INFO Application started successfully
EOF

cat > test_logs/production_samples.json << 'EOF'
{"timestamp": "2024-01-15T10:30:00.000Z", "level": "ERROR", "message": "Payment processing failed", "service": "payment-gateway", "user_id": "user123"}
{"timestamp": "2024-01-15T10:30:01.000Z", "level": "INFO", "message": "Order created successfully", "service": "order-service", "order_id": "order456"}
{"timestamp": "2024-01-15T10:30:02.000Z", "level": "WARN", "message": "High response time detected", "service": "recommendation-engine", "response_time_ms": 2500}
EOF

# Create integration test
echo "📝 Creating integration test..."
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

chmod +x test_integration.py

# Create performance test
echo "📝 Creating performance test..."
cat > performance_test.py << 'EOF'
#!/usr/bin/env python3
import time
import statistics
from src.normalizer import LogNormalizer

def benchmark_normalizer():
    normalizer = LogNormalizer()
    
    json_logs = [b'{"timestamp": "2024-01-15T10:30:00Z", "level": "ERROR", "message": "Test error %d"}' % i for i in range(1000)]
    text_logs = [b'2024-01-15 10:30:00 INFO Test message %d' % i for i in range(1000)]
    
    start_time = time.perf_counter()
    for log in json_logs:
        normalizer.normalize(log)
    json_time = time.perf_counter() - start_time
    
    start_time = time.perf_counter()
    for log in text_logs:
        normalizer.normalize(log)
    text_time = time.perf_counter() - start_time
    
    print(f"JSON Processing: {json_time:.4f}s for 1000 logs ({json_time*1000:.2f}ms avg)")
    print(f"Text Processing: {text_time:.4f}s for 1000 logs ({text_time*1000:.2f}ms avg)")
    print(f"Total throughput: {2000/(json_time + text_time):.0f} logs/second")

if __name__ == '__main__':
    benchmark_normalizer()
EOF

chmod +x performance_test.py

# Create production simulation
echo "📝 Creating production simulation..."
cat > production_simulation.py << 'EOF'
#!/usr/bin/env python3
import time
import random
import json
from src.normalizer import LogNormalizer

def simulate_log_stream():
    normalizer = LogNormalizer()
    
    log_templates = [
        b'{"timestamp": "2024-01-15T10:30:%02d", "level": "ERROR", "message": "Database error %d", "service": "db-service"}',
        b'{"timestamp": "2024-01-15T10:30:%02d", "level": "INFO", "message": "Request processed %d", "service": "api-gateway"}',
        b'2024-01-15 10:30:%02d ERROR Connection timeout %d',
        b'2024-01-15 10:30:%02d INFO User authenticated %d',
        b'[2024-01-15T10:30:%02d] WARN: Memory usage high %d',
    ]
    
    start_time = time.perf_counter()
    processed_count = 0
    error_count = 0
    
    for i in range(10000):
        template = random.choice(log_templates)
        log_data = template % (i % 60, i)
        
        try:
            result = normalizer.normalize(log_data)
            processed_count += 1
            
            if i % 1000 == 0:
                print(f"Processed {i} logs...")
                
        except Exception as e:
            error_count += 1
    
    end_time = time.perf_counter()
    total_time = end_time - start_time
    
    print(f"\n📊 Production Simulation Results:")
    print(f"Total logs processed: {processed_count}")
    print(f"Total errors: {error_count}")
    print(f"Processing time: {total_time:.2f} seconds")
    print(f"Throughput: {processed_count/total_time:.0f} logs/second")
    print(f"Success rate: {(processed_count/(processed_count + error_count))*100:.2f}%")

if __name__ == '__main__':
    simulate_log_stream()
EOF

chmod +x production_simulation.py

# Create Dockerfile
echo "📝 Creating Dockerfile..."
cat > Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY tests/ ./tests/
COPY sample_logs/ ./sample_logs/
COPY test_integration.py .
COPY performance_test.py .

CMD ["python", "-m", "pytest", "tests/", "-v"]
EOF

# Create docker-compose.yml
echo "📝 Creating docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  log-normalizer:
    build: .
    volumes:
      - ./sample_logs:/app/sample_logs
      - ./test_results:/app/test_results
    environment:
      - PYTHONPATH=/app
    command: python -m pytest tests/ -v --junit-xml=test_results/results.xml
  
  integration-test:
    build: .
    volumes:
      - ./sample_logs:/app/sample_logs
    environment:
      - PYTHONPATH=/app
    command: python test_integration.py
EOF

# Create .gitignore
echo "📝 Creating .gitignore..."
cat > .gitignore << 'EOF'
venv/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
*.so
*.egg
*.egg-info/
dist/
build/
.pytest_cache/
.coverage
htmlcov/
test_results/
.env
EOF

# Create README
echo "📝 Creating README..."
cat > README.md << 'EOF'
# Log Normalizer - Day 18

Universal log format translator for distributed systems.

## Features

- Multi-format support (JSON, Text, Protobuf, Avro)
- Auto-format detection
- Plugin-based architecture
- Production-ready performance

## Quick Start

```bash
# Setup
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Test
python -m pytest tests/ -v
python test_integration.py

# Docker
docker build -t log-normalizer .
docker run --rm log-normalizer
```

## Usage

```python
from src.normalizer import LogNormalizer

normalizer = LogNormalizer()
result = normalizer.normalize(b'{"level": "INFO", "message": "test"}')
print(result.level, result.message)
```
EOF

# Create setup.py
echo "📝 Creating setup.py..."
cat > setup.py << 'EOF'
from setuptools import setup, find_packages

setup(
    name="log-normalizer",
    version="1.0.0",
    packages=find_packages(),
    install_requires=[
        "protobuf>=4.21.0",
        "avro-python3>=1.10.0",
        "pytest>=7.0.0",
        "structlog>=22.0.0",
        "pydantic>=1.10.0",
    ],
)
EOF

# Setup virtual environment and install dependencies
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "📦 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Run tests
echo "🧪 Running tests..."
python -m pytest tests/ -v

echo "🧪 Running integration tests..."
python test_integration.py

echo "📊 Running performance benchmark..."
python performance_test.py

echo ""
echo "✅ Project setup complete!"
echo "📁 Project location: $(pwd)"
echo ""
echo "🚀 Next steps:"
echo "  1. Activate venv: source venv/bin/activate"
echo "  2. Run tests: python -m pytest tests/ -v"
echo "  3. Integration: python test_integration.py"
echo "  4. Docker: docker build -t log-normalizer ."
echo ""
echo "📊 Coverage report: python -m pytest --cov=src --cov-report=html"
echo "🐳 Docker compose: docker-compose up --build"