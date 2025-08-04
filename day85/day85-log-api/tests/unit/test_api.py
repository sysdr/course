import pytest
from api.models import LogQuery

class TestLogAPI:
    def test_root_endpoint(self, client):
        """Test root endpoint"""
        response = client.get("/")
        assert response.status_code == 200
        assert "Distributed Log Platform API" in response.json()["message"]
    
    def test_health_check(self, client):
        """Test health check endpoint"""
        response = client.get("/api/v1/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
    
    def test_get_logs_without_auth(self, client):
        """Test getting logs without authentication"""
        response = client.get("/api/v1/logs")
        assert response.status_code == 200  # Anonymous access allowed
        data = response.json()
        assert data["success"] is True
        assert "data" in data
    
    def test_get_logs_with_filters(self, client):
        """Test getting logs with filters"""
        response = client.get("/api/v1/logs?level=ERROR&page=1&size=10")
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["metadata"]["page"] == 1
        assert data["metadata"]["size"] == 10
    
    def test_login_endpoint(self, client):
        """Test authentication endpoint"""
        response = client.post(
            "/api/v1/auth/login",
            json={"username": "developer", "password": "dev123"}
        )
        assert response.status_code == 200
        assert "access_token" in response.json()
    
    def test_invalid_login(self, client):
        """Test invalid login credentials"""
        response = client.post(
            "/api/v1/auth/login",
            json={"username": "invalid", "password": "wrong"}
        )
        assert response.status_code == 401
    
    def test_search_logs(self, client):
        """Test log search endpoint"""
        search_data = {
            "query_text": "error",
            "page": 1,
            "size": 10,
            "filters": {"level": "ERROR"}
        }
        response = client.post("/api/v1/logs/search", json=search_data)
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "query_time_ms" in data["metadata"]
    
    def test_get_stats(self, client):
        """Test statistics endpoint"""
        response = client.get("/api/v1/logs/stats?time_range=24h")
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "total_logs" in data["data"]
        assert "logs_by_level" in data["data"]
        assert "error_rate" in data["data"]

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
