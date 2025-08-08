import pytest
import asyncio
from fastapi.testclient import TestClient
import json

from src.api.main import app

client = TestClient(app)

def test_health_endpoint():
    """Test health check endpoint"""
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert "status" in data
    assert "timestamp" in data

def test_batch_insert_endpoint():
    """Test batch insert API endpoint"""
    logs = [
        {
            "timestamp": "2025-06-01T10:00:00Z",
            "level": "INFO",
            "service": "test-service",
            "message": f"Test message {i}",
            "metadata": {"test": True}
        }
        for i in range(10)
    ]
    
    response = client.post("/api/v1/logs/batch", json={
        "logs": logs,
        "chunk_size": 5
    })
    
    assert response.status_code == 200
    data = response.json()
    assert data["success"] == True
    assert data["total_processed"] == 10
    assert data["success_count"] == 10
    assert data["error_count"] == 0

def test_batch_insert_validation():
    """Test batch insert input validation"""
    # Test empty batch
    response = client.post("/api/v1/logs/batch", json={"logs": []})
    assert response.status_code == 200  # Empty batch should succeed
    
    # Test oversized batch
    large_logs = [
        {
            "level": "INFO",
            "service": "test",
            "message": f"message {i}"
        }
        for i in range(15000)  # Exceeds 10000 limit
    ]
    
    response = client.post("/api/v1/logs/batch", json={"logs": large_logs})
    assert response.status_code == 400

def test_batch_query_endpoint():
    """Test batch query API endpoint"""
    query_request = {
        "filters": {
            "level": "ERROR",
            "service": "payment-service"
        },
        "limit": 50
    }
    
    response = client.post("/api/v1/logs/batch/query", json=query_request)
    assert response.status_code == 200
    
    data = response.json()
    assert data["success"] == True
    assert "total_results" in data
    assert "logs" in data
    assert "processing_time" in data

def test_metrics_endpoint():
    """Test metrics API endpoint"""
    response = client.get("/api/v1/metrics/batch")
    assert response.status_code == 200
    
    data = response.json()
    assert "total_batches_processed" in data
    assert "total_logs_processed" in data
    assert "average_batch_size" in data
    assert "success_rate" in data
