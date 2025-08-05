import pytest
import asyncio
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture
def client():
    return TestClient(app)

def test_health_endpoint(client):
    """Test health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_graphql_query_logs(client):
    """Test GraphQL logs query"""
    query = """
    query {
        logs {
            id
            service
            level
            message
        }
    }
    """
    response = client.post("/graphql", json={"query": query})
    assert response.status_code == 200
    data = response.json()
    assert "data" in data
    assert "logs" in data["data"]

def test_graphql_query_stats(client):
    """Test GraphQL stats query"""
    query = """
    query {
        logStats {
            totalLogs
            errorCount
            services
        }
    }
    """
    response = client.post("/graphql", json={"query": query})
    assert response.status_code == 200
    data = response.json()
    assert "data" in data
    assert "logStats" in data["data"]

def test_graphql_create_log_mutation(client):
    """Test GraphQL create log mutation"""
    mutation = """
    mutation {
        createLog(logData: {
            service: "test-service"
            level: "INFO"
            message: "Test log message"
        }) {
            id
            service
            level
            message
        }
    }
    """
    response = client.post("/graphql", json={"query": mutation})
    assert response.status_code == 200
    data = response.json()
    assert "data" in data
    assert "createLog" in data["data"]
    assert data["data"]["createLog"]["service"] == "test-service"

def test_graphql_services_query(client):
    """Test GraphQL services query"""
    query = """
    query {
        services
    }
    """
    response = client.post("/graphql", json={"query": query})
    assert response.status_code == 200
    data = response.json()
    assert "data" in data
    assert "services" in data["data"]
    assert isinstance(data["data"]["services"], list)
