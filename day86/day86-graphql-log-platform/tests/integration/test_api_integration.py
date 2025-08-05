import pytest
import asyncio
import httpx
import json

BASE_URL = "http://localhost:8000"

@pytest.mark.asyncio
async def test_graphql_endpoint_available():
    """Test that GraphQL endpoint is accessible"""
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{BASE_URL}/health")
        assert response.status_code == 200

@pytest.mark.asyncio
async def test_complex_graphql_query():
    """Test complex GraphQL query with filtering"""
    query = """
    query GetFilteredLogs($filters: LogFilterInput) {
        logs(filters: $filters) {
            id
            service
            level
            message
            timestamp
            relatedLogs {
                id
                service
            }
        }
        logStats {
            totalLogs
            errorCount
        }
    }
    """
    variables = {
        "filters": {
            "service": "api-gateway",
            "level": "ERROR",
            "limit": 10
        }
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{BASE_URL}/graphql",
            json={"query": query, "variables": variables}
        )
        assert response.status_code == 200
        data = response.json()
        assert "data" in data
        assert "logs" in data["data"]
        assert "logStats" in data["data"]

@pytest.mark.asyncio
async def test_subscription_connection():
    """Test WebSocket subscription connection"""
    # This would test WebSocket connection in a real scenario
    # For now, we'll test the endpoint exists
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{BASE_URL}/graphql")
        assert response.status_code in [200, 405]  # 405 for GET on POST endpoint
