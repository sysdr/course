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
