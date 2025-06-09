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
