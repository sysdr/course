import asyncio
from typing import Optional

# Simulated database connection
_db_connection = None

async def init_db():
    """Initialize database connection"""
    global _db_connection
    # Simulate database initialization
    await asyncio.sleep(0.1)
    _db_connection = {"status": "connected", "host": "localhost", "db": "logs"}
    print("✅ Database initialized")

async def get_db_connection():
    """Get database connection"""
    return _db_connection

async def close_db():
    """Close database connection"""
    global _db_connection
    _db_connection = None
    print("✅ Database connection closed")
