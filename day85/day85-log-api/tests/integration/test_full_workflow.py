import pytest

class TestFullWorkflow:
    def test_complete_api_workflow(self, client):
        """Test complete API workflow from login to data retrieval"""
        
        # Step 1: Login
        login_response = client.post(
            "/api/v1/auth/login",
            json={"username": "operator", "password": "ops123"}
        )
        assert login_response.status_code == 200
        token = login_response.json()["access_token"]
        
        headers = {"Authorization": f"Bearer {token}"}
        
        # Step 2: Get basic logs
        logs_response = client.get("/api/v1/logs?page=1&size=5", headers=headers)
        assert logs_response.status_code == 200
        logs_data = logs_response.json()
        assert len(logs_data["data"]) <= 5
        
        # Step 3: Search logs
        search_response = client.post(
            "/api/v1/logs/search",
            json={
                "query_text": "service", 
                "page": 1, 
                "size": 10,
                "aggregations": {"count_by_level": True}
            },
            headers=headers
        )
        assert search_response.status_code == 200
        search_data = search_response.json()
        assert "aggregations" in search_data["metadata"]
        
        # Step 4: Get statistics
        stats_response = client.get("/api/v1/logs/stats?time_range=24h", headers=headers)
        assert stats_response.status_code == 200
        stats_data = stats_response.json()
        assert stats_data["data"]["total_logs"] > 0
        
        # Step 5: Health check
        health_response = client.get("/api/v1/health")
        assert health_response.status_code == 200
        assert health_response.json()["status"] == "healthy"
    
    def test_error_handling(self, client):
        """Test API error handling"""
        
        # Test invalid pagination
        response = client.get("/api/v1/logs?page=0&size=10")
        assert response.status_code == 422  # Validation error
        
        # Test invalid time range
        response = client.get("/api/v1/logs/stats?time_range=invalid")
        assert response.status_code == 422  # Validation error
        
        # Test invalid search query
        response = client.post("/api/v1/logs/search", json={"query_text": ""})
        assert response.status_code == 422  # Validation error

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
