#!/bin/bash

# Create project structure
echo "📁 Creating project structure..."
mkdir -p schema_registry/src schema_registry/tests schema_registry/scripts

# Create storage backend
echo "📝 Creating storage backend (src/storage.py)..."
cat > schema_registry/src/storage.py << 'EOF'
from typing import Dict, Any, Optional
import json
import os
from datetime import datetime, UTC

class Storage:
    def __init__(self, storage_dir: str = "data"):
        self.storage_dir = storage_dir
        os.makedirs(storage_dir, exist_ok=True)
        
    def save_schema(self, subject: str, version: int, schema: Dict[str, Any]) -> None:
        """Save a schema version to storage."""
        schema_data = {
            'subject': subject,
            'version': version,
            'schema': schema,
            'registered_at': datetime.now(UTC).isoformat()
        }
        
        file_path = os.path.join(self.storage_dir, f"{subject}_v{version}.json")
        with open(file_path, 'w') as f:
            json.dump(schema_data, f, indent=2)
            
    def get_schema(self, subject: str, version: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """Retrieve a schema version from storage."""
        if version is None:
            # Get latest version
            versions = [f for f in os.listdir(self.storage_dir) if f.startswith(f"{subject}_v")]
            if not versions:
                return None
            version = max(int(v.split('_v')[1].split('.')[0]) for v in versions)
            
        file_path = os.path.join(self.storage_dir, f"{subject}_v{version}.json")
        if not os.path.exists(file_path):
            return None
            
        with open(file_path, 'r') as f:
            return json.load(f)
            
    def list_subjects(self) -> list:
        """List all registered subjects."""
        subjects = set()
        for filename in os.listdir(self.storage_dir):
            if filename.endswith('.json'):
                subject = filename.split('_v')[0]
                subjects.add(subject)
        return sorted(list(subjects))
        
    def get_versions(self, subject: str) -> list:
        """Get all versions for a subject."""
        versions = []
        for filename in os.listdir(self.storage_dir):
            if filename.startswith(f"{subject}_v") and filename.endswith('.json'):
                version = int(filename.split('_v')[1].split('.')[0])
                versions.append(version)
        return sorted(versions)
EOF

# Create validator
echo "📝 Creating validator (src/validator.py)..."
cat > schema_registry/src/validator.py << 'EOF'
from typing import Dict, Any, Tuple, Optional, List
import jsonschema
from jsonschema import validate

class LogValidator:
    def __init__(self):
        self.schemas: Dict[str, Dict[str, Any]] = {}
        
    def register_schema(self, subject: str, schema: Dict[str, Any]) -> Tuple[int, str]:
        """Register a new schema version for a subject."""
        if subject not in self.schemas:
            self.schemas[subject] = {}
            
        # Generate version number
        version = len(self.schemas[subject]) + 1
        
        # Store schema
        self.schemas[subject][version] = schema
        
        return version, f"{subject}_v{version}"
        
    def get_schema(self, subject: str, version: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """Get a schema version for a subject."""
        if subject not in self.schemas:
            return None
            
        if version is None:
            # Get latest version
            version = max(self.schemas[subject].keys())
            
        return self.schemas[subject].get(version)
        
    def validate_log(self, subject: str, log: Dict[str, Any], version: Optional[int] = None) -> bool:
        """Validate a log against a schema version."""
        schema = self.get_schema(subject, version)
        if not schema:
            return False
            
        try:
            validate(instance=log, schema=schema)
            return True
        except jsonschema.exceptions.ValidationError:
            return False
            
    def validate_batch(self, subject: str, logs: List[Dict[str, Any]], version: Optional[int] = None) -> Tuple[int, int]:
        """Validate a batch of logs against a schema version."""
        schema = self.get_schema(subject, version)
        if not schema:
            return 0, len(logs)
            
        valid_count = 0
        for log in logs:
            try:
                validate(instance=log, schema=schema)
                valid_count += 1
            except jsonschema.exceptions.ValidationError:
                continue
                
        return valid_count, len(logs)
EOF

# Create registry service
echo "📝 Creating registry service (src/registry.py)..."
cat > schema_registry/src/registry.py << 'EOF'
from flask import Flask, request, jsonify
from datetime import datetime, UTC
from .validator import LogValidator
from .storage import Storage

app = Flask(__name__)
validator = LogValidator()
storage = Storage()

@app.route('/health')
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'schemas_count': len(validator.schemas),
        'subjects_count': len(storage.list_subjects()),
        'timestamp': datetime.now(UTC).isoformat()
    })

@app.route('/schemas/<subject>', methods=['POST'])
def register_schema(subject):
    """Register a new schema version."""
    try:
        schema = request.get_json()
        version, schema_id = validator.register_schema(subject, schema)
        storage.save_schema(subject, version, schema)
        
        return jsonify({
            'message': 'Schema registered successfully',
            'version': version,
            'id': schema_id
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/schemas/<subject>', methods=['GET'])
def get_schema(subject):
    """Get the latest schema version."""
    schema = validator.get_schema(subject)
    if not schema:
        return jsonify({'error': 'Schema not found'}), 404
        
    return jsonify(schema)

@app.route('/subjects')
def list_subjects():
    """List all registered subjects."""
    return jsonify({
        'subjects': storage.list_subjects()
    })

@app.route('/subjects/<subject>/versions')
def get_versions(subject):
    """Get all versions for a subject."""
    versions = storage.get_versions(subject)
    if not versions:
        return jsonify({'error': 'Subject not found'}), 404
        
    return jsonify({
        'subject': subject,
        'versions': versions
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

# Create test suite
echo "📝 Creating test suite (tests/test_registry.py)..."
cat > schema_registry/tests/test_registry.py << 'EOF'
import pytest
import requests
import time
import threading
from src.validator import LogValidator
from src.storage import Storage

def test_schema_registration():
    validator = LogValidator()
    schema = {
        "type": "object",
        "properties": {
            "user_id": {"type": "string"},
            "event_type": {"type": "string"},
            "timestamp": {"type": "string"}
        },
        "required": ["user_id", "event_type", "timestamp"]
    }
    
    version, schema_id = validator.register_schema("test-events", schema)
    assert version == 1
    assert schema_id == "test-events_v1"
    
    stored_schema = validator.get_schema("test-events")
    assert stored_schema == schema

def test_log_validation():
    validator = LogValidator()
    schema = {
        "type": "object",
        "properties": {
            "user_id": {"type": "string"},
            "event_type": {"type": "string"},
            "timestamp": {"type": "string"}
        },
        "required": ["user_id", "event_type", "timestamp"]
    }
    
    validator.register_schema("test-events", schema)
    
    # Valid log
    valid_log = {
        "user_id": "123",
        "event_type": "login",
        "timestamp": "2024-03-19T12:00:00Z"
    }
    assert validator.validate_log("test-events", valid_log)
    
    # Invalid log
    invalid_log = {
        "user_id": "123",
        "event_type": "login"
        # Missing timestamp
    }
    assert not validator.validate_log("test-events", invalid_log)

def test_batch_validation():
    validator = LogValidator()
    schema = {
        "type": "object",
        "properties": {
            "user_id": {"type": "string"},
            "event_type": {"type": "string"},
            "timestamp": {"type": "string"}
        },
        "required": ["user_id", "event_type", "timestamp"]
    }
    
    validator.register_schema("test-events", schema)
    
    logs = [
        {
            "user_id": "123",
            "event_type": "login",
            "timestamp": "2024-03-19T12:00:00Z"
        },
        {
            "user_id": "456",
            "event_type": "logout"
            # Missing timestamp
        }
    ]
    
    valid_count, total = validator.validate_batch("test-events", logs)
    assert valid_count == 1
    assert total == 2

def test_storage():
    storage = Storage("test_data")
    
    schema = {
        "type": "object",
        "properties": {
            "user_id": {"type": "string"}
        }
    }
    
    # Save schema
    storage.save_schema("test-subject", 1, schema)
    
    # Retrieve schema
    retrieved = storage.get_schema("test-subject", 1)
    assert retrieved["schema"] == schema
    
    # List subjects
    subjects = storage.list_subjects()
    assert "test-subject" in subjects
    
    # Get versions
    versions = storage.get_versions("test-subject")
    assert versions == [1]

def test_concurrent_registration():
    validator = LogValidator()
    schema = {
        "type": "object",
        "properties": {
            "user_id": {"type": "string"}
        }
    }
    
    def register_schema(thread_id):
        subject = f"test-subject-{thread_id}"
        validator.register_schema(subject, schema)
    
    threads = []
    for i in range(5):
        thread = threading.Thread(target=register_schema, args=(i,))
        threads.append(thread)
        thread.start()
    
    for thread in threads:
        thread.join()
    
    assert len(validator.schemas) == 5

def test_api_health():
    response = requests.get("http://localhost:8080/health")
    assert response.status_code == 200
    data = response.json()
    assert "status" in data
    assert "schemas_count" in data
    assert "subjects_count" in data

def test_api_schema_registration():
    schema = {
        "type": "object",
        "properties": {
            "user_id": {"type": "string"},
            "event_type": {"type": "string"},
            "timestamp": {"type": "string"}
        },
        "required": ["user_id", "event_type", "timestamp"]
    }
    
    response = requests.post(
        "http://localhost:8080/schemas/test-events",
        json=schema
    )
    assert response.status_code == 200
    data = response.json()
    assert "version" in data
    assert "id" in data

def test_api_schema_retrieval():
    response = requests.get("http://localhost:8080/schemas/test-events")
    assert response.status_code == 200
    data = response.json()
    assert "type" in data
    assert "properties" in data

def test_api_subjects():
    response = requests.get("http://localhost:8080/subjects")
    assert response.status_code == 200
    data = response.json()
    assert "subjects" in data
    assert isinstance(data["subjects"], list)

def test_api_versions():
    response = requests.get("http://localhost:8080/subjects/test-events/versions")
    assert response.status_code == 200
    data = response.json()
    assert "subject" in data
    assert "versions" in data
    assert isinstance(data["versions"], list)
EOF

# Create demo script
echo "📝 Creating demo script (scripts/demo.py)..."
cat > schema_registry/scripts/demo.py << 'EOF'
import requests
import time
from src.validator import LogValidator

def demo_schema_registry():
    print("🚀 Schema Registry Demo")
    print("======================\n")
    
    base_url = "http://localhost:8080"
    
    # 1. Health Check
    print("1. Health Check")
    response = requests.get(f"{base_url}/health")
    print(f"Status: {response.json()}\n")
    
    # 2. Register Schema
    print("2. Register Schema")
    schema = {
        "type": "object",
        "properties": {
            "user_id": {"type": "string"},
            "event_type": {"type": "string", "enum": ["login", "logout", "signup"]},
            "timestamp": {"type": "string", "format": "date-time"},
            "metadata": {
                "type": "object",
                "properties": {
                    "ip_address": {"type": "string"},
                    "user_agent": {"type": "string"}
                }
            }
        },
        "required": ["user_id", "event_type", "timestamp"]
    }
    
    response = requests.post(
        f"{base_url}/schemas/user-events",
        json=schema
    )
    print(f"Response: {response.json()}\n")
    
    # 3. List Subjects
    print("3. List Subjects")
    response = requests.get(f"{base_url}/subjects")
    print(f"Subjects: {response.json()}\n")
    
    # 4. Get Schema
    print("4. Get Schema")
    response = requests.get(f"{base_url}/schemas/user-events")
    print(f"Schema: {response.json()}\n")
    
    # 5. Validate Logs
    print("5. Validate Logs")
    validator = LogValidator()
    validator.register_schema("user-events", schema)
    
    # Valid log
    valid_log = {
        "user_id": "123",
        "event_type": "login",
        "timestamp": "2024-03-19T12:00:00Z",
        "metadata": {
            "ip_address": "192.168.1.1",
            "user_agent": "Mozilla/5.0"
        }
    }
    
    # Invalid log
    invalid_log = {
        "user_id": "123",
        "event_type": "invalid_event",
        "timestamp": "2024-03-19T12:00:00Z"
    }
    
    print("Valid log validation:", validator.validate_log("user-events", valid_log))
    print("Invalid log validation:", validator.validate_log("user-events", invalid_log))
    print()
    
    # 6. Performance Test
    print("6. Performance Test")
    logs = [valid_log.copy() for _ in range(100)]
    start_time = time.time()
    valid_count, total = validator.validate_batch("user-events", logs)
    end_time = time.time()
    
    print(f"Validated {total} logs in {end_time - start_time:.3f} seconds")
    print(f"Valid logs: {valid_count}/{total}")
    print(f"Average time per log: {(end_time - start_time) * 1000 / total:.1f}ms")

if __name__ == "__main__":
    demo_schema_registry()
EOF

# Create requirements.txt
echo "📝 Creating requirements.txt..."
cat > schema_registry/requirements.txt << 'EOF'
Flask==3.0.2
jsonschema==4.21.1
requests==2.31.0
pytest==8.0.2
EOF

# Create Dockerfile
echo "📝 Creating Dockerfile..."
cat > schema_registry/Dockerfile << 'EOF'
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["python", "-m", "src.registry"]
EOF

# Create docker-compose.yml
echo "📝 Creating docker-compose.yml..."
cat > schema_registry/docker-compose.yml << 'EOF'
version: '3.8'

services:
  registry:
    build: .
    ports:
      - "8080:8080"
    volumes:
      - ./data:/app/data
    environment:
      - FLASK_ENV=development
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

# Create test script
echo "📝 Creating test script (scripts/test_full.sh)..."
cat > schema_registry/scripts/test_full.sh << 'EOF'
#!/bin/bash

echo "🔍 Running full test suite..."

# Install dependencies
pip install -r requirements.txt

# Start registry server
python -m src.registry &
SERVER_PID=$!

# Wait for server to start
sleep 2

# Run tests
pytest tests/test_registry.py -v

# Stop server
kill $SERVER_PID
EOF

# Make scripts executable
chmod +x schema_registry/scripts/test_full.sh

echo "✨ Setup complete! Project structure created in schema_registry/"
echo "Next steps:"
echo "1. cd schema_registry"
echo "2. pip install -r requirements.txt"
echo "3. python -m src.registry"
echo "4. In another terminal: python scripts/demo.py"

