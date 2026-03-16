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
