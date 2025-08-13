import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field
import sqlite3
import aiosqlite
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Models
class LogEntry(BaseModel):
    id: int
    timestamp: datetime
    level: str
    service: str
    message: str
    source_ip: Optional[str] = None
    user_id: Optional[str] = None
    request_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

class SearchRequest(BaseModel):
    query: str = ""
    filters: Dict[str, Any] = Field(default_factory=dict)
    limit: int = 100
    offset: int = 0
    sort_by: str = "timestamp"
    sort_order: str = "desc"

class SearchResponse(BaseModel):
    logs: List[LogEntry]
    total_count: int
    execution_time_ms: float
    filters_applied: Dict[str, Any]

# Database initialization
async def init_database():
    """Initialize SQLite database with FTS5 for full-text search"""
    # Get the project root directory (parent of backend directory)
    import os
    db_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "logs.db")
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

# Search Service
class SearchService:
    def __init__(self):
        # Get the project root directory (parent of backend directory)
        import os
        self.db_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "logs.db")
    
    async def search_logs(self, search_request: SearchRequest) -> SearchResponse:
        """Execute advanced search with multiple filters"""
        start_time = datetime.now()
        
        # Build dynamic query based on filters
        query_parts = ["SELECT * FROM logs WHERE 1=1"]
        params = []
        
        # Text search using FTS
        if search_request.query.strip():
            query_parts.append("""
                AND id IN (
                    SELECT rowid FROM logs_fts 
                    WHERE logs_fts MATCH ?
                )
            """)
            params.append(search_request.query)
        
        # Apply filters
        filters = search_request.filters
        
        # Level filter
        if filters.get('levels'):
            levels = filters['levels']
            placeholders = ','.join(['?' for _ in levels])
            query_parts.append(f"AND level IN ({placeholders})")
            params.extend(levels)
        
        # Service filter
        if filters.get('services'):
            services = filters['services']
            placeholders = ','.join(['?' for _ in services])
            query_parts.append(f"AND service IN ({placeholders})")
            params.extend(services)
        
        # Time range filter
        if filters.get('time_range'):
            time_range = filters['time_range']
            if time_range.get('start'):
                query_parts.append("AND timestamp >= ?")
                params.append(time_range['start'])
            if time_range.get('end'):
                query_parts.append("AND timestamp <= ?")
                params.append(time_range['end'])
        
        # User ID filter
        if filters.get('user_id'):
            query_parts.append("AND user_id = ?")
            params.append(filters['user_id'])
        
        # Source IP filter
        if filters.get('source_ip'):
            query_parts.append("AND source_ip LIKE ?")
            params.append(f"%{filters['source_ip']}%")
        
        # Add sorting
        query_parts.append(f"ORDER BY {search_request.sort_by} {search_request.sort_order}")
        
        # Add pagination
        query_parts.append("LIMIT ? OFFSET ?")
        params.extend([search_request.limit, search_request.offset])
        
        # Execute query
        query = " ".join(query_parts)
        
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            
            # Get results
            async with db.execute(query, params) as cursor:
                rows = await cursor.fetchall()
            
            # Get total count (without pagination)
            count_query = query.replace("SELECT *", "SELECT COUNT(*)").split("ORDER BY")[0]
            count_params = params[:-2]  # Remove LIMIT and OFFSET params
            
            async with db.execute(count_query, count_params) as cursor:
                total_count = (await cursor.fetchone())[0]
        
        # Convert to LogEntry objects
        logs = []
        for row in rows:
            metadata = json.loads(row['metadata']) if row['metadata'] else None
            log_entry = LogEntry(
                id=row['id'],
                timestamp=datetime.fromisoformat(row['timestamp']),
                level=row['level'],
                service=row['service'],
                message=row['message'],
                source_ip=row['source_ip'],
                user_id=row['user_id'],
                request_id=row['request_id'],
                metadata=metadata
            )
            logs.append(log_entry)
        
        execution_time = (datetime.now() - start_time).total_seconds() * 1000
        
        return SearchResponse(
            logs=logs,
            total_count=total_count,
            execution_time_ms=execution_time,
            filters_applied=search_request.filters
        )
    
    async def get_filter_options(self) -> Dict[str, List[str]]:
        """Get available filter options"""
        async with aiosqlite.connect(self.db_path) as db:
            # Get unique services
            async with db.execute("SELECT DISTINCT service FROM logs ORDER BY service") as cursor:
                services = [row[0] for row in await cursor.fetchall()]
            
            # Get unique levels
            async with db.execute("SELECT DISTINCT level FROM logs ORDER BY level") as cursor:
                levels = [row[0] for row in await cursor.fetchall()]
            
            # Get unique user IDs (limit to prevent large lists)
            async with db.execute("SELECT DISTINCT user_id FROM logs WHERE user_id IS NOT NULL ORDER BY user_id LIMIT 100") as cursor:
                user_ids = [row[0] for row in await cursor.fetchall()]
            
            return {
                "services": services,
                "levels": levels,
                "user_ids": user_ids
            }

# WebSocket Manager
class WebSocketManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []
    
    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"Client connected. Total connections: {len(self.active_connections)}")
    
    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        logger.info(f"Client disconnected. Total connections: {len(self.active_connections)}")
    
    async def broadcast_new_log(self, log_entry: LogEntry):
        """Broadcast new log entries to connected clients"""
        if self.active_connections:
            message = {
                "type": "new_log",
                "data": log_entry.model_dump(mode='json')
            }
            disconnected = []
            for connection in self.active_connections:
                try:
                    await connection.send_text(json.dumps(message, default=str))
                except WebSocketDisconnect:
                    disconnected.append(connection)
                except Exception as e:
                    logger.error(f"Error broadcasting to client: {e}")
                    disconnected.append(connection)
            
            # Clean up disconnected clients
            for connection in disconnected:
                if connection in self.active_connections:
                    self.active_connections.remove(connection)

# Global instances
search_service = SearchService()
websocket_manager = WebSocketManager()

# Application lifecycle
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await init_database()
    yield
    # Shutdown
    pass

# FastAPI app
app = FastAPI(
    title="Advanced Log Search API",
    description="High-performance log search with intelligent filters",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Endpoints
@app.post("/api/search", response_model=SearchResponse)
async def search_logs(search_request: SearchRequest):
    """Advanced log search with multiple filters"""
    try:
        return await search_service.search_logs(search_request)
    except Exception as e:
        logger.error(f"Search error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/filters")
async def get_filter_options():
    """Get available filter options"""
    try:
        return await search_service.get_filter_options()
    except Exception as e:
        logger.error(f"Filter options error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await websocket_manager.connect(websocket)
    try:
        while True:
            # Keep connection alive and handle client messages
            data = await websocket.receive_text()
            message = json.loads(data)
            
            if message.get("type") == "ping":
                await websocket.send_text(json.dumps({"type": "pong"}))
    except WebSocketDisconnect:
        websocket_manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        websocket_manager.disconnect(websocket)

@app.post("/api/logs")
async def add_log(log_data: Dict[str, Any]):
    """Add a new log entry (for demo purposes)"""
    try:
        # Get the project root directory (parent of backend directory)
        import os
        db_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "logs.db")
        async with aiosqlite.connect(db_path) as db:
            metadata_json = json.dumps(log_data.get('metadata', {}))
            await db.execute("""
                INSERT INTO logs (level, service, message, source_ip, user_id, request_id, metadata)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                log_data.get('level', 'INFO'),
                log_data.get('service', 'unknown'),
                log_data.get('message', ''),
                log_data.get('source_ip'),
                log_data.get('user_id'),
                log_data.get('request_id'),
                metadata_json
            ))
            
            # Update FTS index
            await db.execute("""
                INSERT INTO logs_fts(logs_fts) VALUES('rebuild')
            """)
            
            await db.commit()
            
            # Broadcast to connected clients
            log_entry = LogEntry(
                id=0,  # Will be updated with actual ID
                timestamp=datetime.now(),
                level=log_data.get('level', 'INFO'),
                service=log_data.get('service', 'unknown'),
                message=log_data.get('message', ''),
                source_ip=log_data.get('source_ip'),
                user_id=log_data.get('user_id'),
                request_id=log_data.get('request_id'),
                metadata=log_data.get('metadata', {})
            )
            
            await websocket_manager.broadcast_new_log(log_entry)
            
        return {"status": "success", "message": "Log added successfully"}
    except Exception as e:
        logger.error(f"Add log error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Serve static files
app.mount("/", StaticFiles(directory="../frontend", html=True), name="static")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
