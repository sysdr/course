import pytest
import asyncio
import json
from datetime import datetime, timedelta
from fastapi.testclient import TestClient
from main import app, init_database, SearchRequest

@pytest.fixture
def client():
    return TestClient(app)

@pytest.fixture
async def setup_database():
    """Setup test database with sample data"""
    await init_database()
    
    # Add test data
    import aiosqlite
    import os
    db_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data", "logs.db")
    async with aiosqlite.connect(db_path) as db:
        test_logs = [
            ("ERROR", "payment", "Payment processing failed", "192.168.1.100", "user_123", "req_001", '{"amount": 100}'),
            ("INFO", "auth", "User login successful", "192.168.1.101", "user_456", "req_002", '{"browser": "chrome"}'),
            ("WARN", "inventory", "Low stock warning", "192.168.1.102", "system", "req_003", '{"item_id": "abc123"}'),
            ("DEBUG", "payment", "Payment validation started", "192.168.1.100", "user_123", "req_004", '{"step": "validation"}'),
            ("ERROR", "auth", "Invalid credentials", "192.168.1.103", "user_789", "req_005", '{"attempts": 3}'),
        ]
        
        for level, service, message, source_ip, user_id, request_id, metadata in test_logs:
            await db.execute("""
                INSERT INTO logs (level, service, message, source_ip, user_id, request_id, metadata)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (level, service, message, source_ip, user_id, request_id, metadata))
        
        await db.commit()

@pytest.mark.asyncio
async def test_basic_search(client):
    """Test basic text search functionality"""
    search_request = {
        "query": "payment",
        "filters": {},
        "limit": 10,
        "offset": 0
    }
    
    response = client.post("/api/search", json=search_request)
    assert response.status_code == 200
    
    data = response.json()
    assert "logs" in data
    assert "total_count" in data
    assert "execution_time_ms" in data

@pytest.mark.asyncio
async def test_level_filter(client):
    """Test filtering by log level"""
    search_request = {
        "query": "",
        "filters": {
            "levels": ["ERROR"]
        },
        "limit": 10,
        "offset": 0
    }
    
    response = client.post("/api/search", json=search_request)
    assert response.status_code == 200
    
    data = response.json()
    for log in data["logs"]:
        assert log["level"] == "ERROR"

@pytest.mark.asyncio
async def test_service_filter(client):
    """Test filtering by service"""
    search_request = {
        "query": "",
        "filters": {
            "services": ["payment", "auth"]
        },
        "limit": 10,
        "offset": 0
    }
    
    response = client.post("/api/search", json=search_request)
    assert response.status_code == 200
    
    data = response.json()
    for log in data["logs"]:
        assert log["service"] in ["payment", "auth"]

@pytest.mark.asyncio
async def test_time_range_filter(client):
    """Test filtering by time range"""
    now = datetime.now()
    start_time = (now - timedelta(hours=1)).isoformat()
    end_time = now.isoformat()
    
    search_request = {
        "query": "",
        "filters": {
            "time_range": {
                "start": start_time,
                "end": end_time
            }
        },
        "limit": 10,
        "offset": 0
    }
    
    response = client.post("/api/search", json=search_request)
    assert response.status_code == 200

@pytest.mark.asyncio
async def test_combined_filters(client):
    """Test multiple filters combined"""
    search_request = {
        "query": "payment",
        "filters": {
            "levels": ["ERROR", "DEBUG"],
            "services": ["payment"],
            "user_id": "user_123"
        },
        "limit": 10,
        "offset": 0
    }
    
    response = client.post("/api/search", json=search_request)
    assert response.status_code == 200
    
    data = response.json()
    for log in data["logs"]:
        assert log["level"] in ["ERROR", "DEBUG"]
        assert log["service"] == "payment"
        assert log["user_id"] == "user_123"

@pytest.mark.asyncio
async def test_pagination(client):
    """Test pagination functionality"""
    # First page
    search_request = {
        "query": "",
        "filters": {},
        "limit": 2,
        "offset": 0
    }
    
    response = client.post("/api/search", json=search_request)
    assert response.status_code == 200
    
    first_page = response.json()
    assert len(first_page["logs"]) <= 2
    
    # Second page
    search_request["offset"] = 2
    
    response = client.post("/api/search", json=search_request)
    assert response.status_code == 200
    
    second_page = response.json()
    
    # Ensure different results (if there are enough logs)
    if len(first_page["logs"]) == 2 and len(second_page["logs"]) > 0:
        assert first_page["logs"][0]["id"] != second_page["logs"][0]["id"]

@pytest.mark.asyncio
async def test_sorting(client):
    """Test sorting functionality"""
    search_request = {
        "query": "",
        "filters": {},
        "limit": 10,
        "offset": 0,
        "sort_by": "level",
        "sort_order": "asc"
    }
    
    response = client.post("/api/search", json=search_request)
    assert response.status_code == 200
    
    data = response.json()
    if len(data["logs"]) > 1:
        # Check if results are sorted by level
        levels = [log["level"] for log in data["logs"]]
        assert levels == sorted(levels)

def test_filter_options(client):
    """Test getting available filter options"""
    response = client.get("/api/filters")
    assert response.status_code == 200
    
    data = response.json()
    assert "services" in data
    assert "levels" in data
    assert "user_ids" in data
    assert isinstance(data["services"], list)
    assert isinstance(data["levels"], list)
    assert isinstance(data["user_ids"], list)

def test_invalid_search_request(client):
    """Test handling of invalid search requests"""
    # Test with invalid JSON
    response = client.post("/api/search", data="invalid json")
    assert response.status_code == 422

@pytest.mark.asyncio
async def test_performance(client):
    """Test search performance"""
    search_request = {
        "query": "test",
        "filters": {},
        "limit": 100,
        "offset": 0
    }
    
    response = client.post("/api/search", json=search_request)
    assert response.status_code == 200
    
    data = response.json()
    # Execution time should be reasonable (less than 1 second)
    assert data["execution_time_ms"] < 1000

if __name__ == "__main__":
    pytest.main([__file__])
