import asyncpg
import asyncio
import logging

logger = logging.getLogger(__name__)

async def create_database_schema():
    """Create database schema for log storage"""
    try:
        # Try to connect to PostgreSQL
        conn = await asyncpg.connect(
            host='localhost',
            port=5432,
            user='postgres',
            password='postgres',
            database='postgres'
        )
        
        # Create database if it doesn't exist
        await conn.execute("CREATE DATABASE logdb")
        await conn.close()
        
        # Connect to the new database
        conn = await asyncpg.connect(
            host='localhost',
            port=5432,
            user='postgres',
            password='postgres',
            database='logdb'
        )
        
        # Create logs table
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS logs (
                id UUID PRIMARY KEY,
                timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                level VARCHAR(10) NOT NULL,
                service VARCHAR(255) NOT NULL,
                message TEXT NOT NULL,
                metadata JSONB DEFAULT '{}',
                batch_id VARCHAR(255),
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                INDEX BTREE (timestamp),
                INDEX BTREE (level),
                INDEX BTREE (service),
                INDEX BTREE (batch_id)
            )
        """)
        
        await conn.close()
        logger.info("✅ Database schema created successfully")
        
    except Exception as e:
        logger.warning(f"⚠️ PostgreSQL setup failed: {e}")
        logger.info("📝 System will use in-memory storage for demonstration")

if __name__ == "__main__":
    asyncio.run(create_database_schema())
