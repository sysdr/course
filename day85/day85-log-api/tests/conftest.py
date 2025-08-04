import pytest
import asyncio
import sys
import os
import tempfile
import shutil
from pathlib import Path

# Add src to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))

from fastapi.testclient import TestClient
from api.main import app
from api.services import LogService, AuthService

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="session")
def test_db():
    """Create a temporary database for testing"""
    temp_dir = tempfile.mkdtemp()
    db_path = os.path.join(temp_dir, "test_logs.db")
    
    # Initialize services with test database
    async def setup_db():
        log_service = LogService(db_path)
        auth_service = AuthService()
        
        await log_service.initialize()
        await auth_service.initialize()
        
        return db_path
    
    # Run the async setup in the event loop
    import asyncio
    loop = asyncio.get_event_loop()
    loop.run_until_complete(setup_db())
    
    yield db_path
    
    # Cleanup
    shutil.rmtree(temp_dir)

@pytest.fixture
def client(test_db):
    """Create a test client with initialized services"""
    # Create a synchronous wrapper for the async setup
    async def setup_client():
        # Override the services in the app with test instances
        log_service = LogService(test_db)
        auth_service = AuthService()
        
        await log_service.initialize()
        await auth_service.initialize()
        
        # Replace the services in the app
        app.state.log_service = log_service
        app.state.auth_service = auth_service
        
        return TestClient(app)
    
    # Run the async setup in the event loop
    import asyncio
    loop = asyncio.get_event_loop()
    test_client = loop.run_until_complete(setup_client())
    
    yield test_client

@pytest.fixture
def auth_headers():
    """Provide authentication headers for tests"""
    def _get_headers(token=None):
        if token:
            return {"Authorization": f"Bearer {token}"}
        return {}
    return _get_headers 