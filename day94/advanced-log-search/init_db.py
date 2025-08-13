#!/usr/bin/env python3
"""
Database initialization script for Advanced Log Search System
Run this from the project root directory
"""

import asyncio
import sys
import os
import aiosqlite
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def init_database():
    """Initialize SQLite database with FTS5 for full-text search"""
    # Create data directory if it doesn't exist
    os.makedirs("data", exist_ok=True)
    
    db_path = os.path.join("data", "logs.db")
    async with aiosqlite.connect(db_path) as db:
        # Create main logs table
        await db.execute("""
            CREATE TABLE IF NOT EXISTS logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                level TEXT NOT NULL,
                service TEXT NOT NULL,
                message TEXT NOT NULL,
                source_ip TEXT,
                user_id TEXT,
                request_id TEXT,
                metadata TEXT
            )
        """)
        
        # Create FTS5 virtual table for full-text search
        await db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS logs_fts USING fts5(
                message, service, level, 
                content='logs',
                content_rowid='id'
            )
        """)
        
        # Create indexes for performance
        await db.execute("CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs(timestamp)")
        await db.execute("CREATE INDEX IF NOT EXISTS idx_logs_level ON logs(level)")
        await db.execute("CREATE INDEX IF NOT EXISTS idx_logs_service ON logs(service)")
        
        await db.commit()
        logger.info("Database initialized successfully")

async def main():
    """Initialize the database"""
    try:
        await init_database()
        print("✅ Database initialized successfully")
    except Exception as e:
        print(f"❌ Database initialization failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
