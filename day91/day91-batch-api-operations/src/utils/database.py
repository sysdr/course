import asyncpg
from typing import Optional

_db_pool: Optional[asyncpg.Pool] = None

async def get_db_pool():
    """Get database connection pool"""
    global _db_pool
    if _db_pool is None:
        try:
            _db_pool = await asyncpg.create_pool(
                host='localhost',
                port=5432,
                user='postgres',
                password='postgres',
                database='logdb',
                min_size=2,
                max_size=10
            )
        except Exception:
            _db_pool = None
    return _db_pool

async def get_db_session():
    """Get database session (dependency)"""
    pool = await get_db_pool()
    if pool:
        async with pool.acquire() as conn:
            yield conn
    else:
        yield None  # In-memory fallback
