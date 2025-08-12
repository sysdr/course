import asyncio
import json
import logging
from datetime import datetime
from typing import Dict, List, Set
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn
from .services.log_streamer import LogStreamer
from .services.connection_manager import ConnectionManager
from .models.log_entry import LogEntry
import structlog

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan event handler for startup and shutdown"""
    # Startup
    await log_streamer.start()
    logger.info("Log streaming service started")
    
    yield
    
    # Shutdown
    await log_streamer.stop()
    logger.info("Log streaming service stopped")

# Initialize services
connection_manager = ConnectionManager()
log_streamer = LogStreamer()

app = FastAPI(
    title="Real-time Log Streaming API",
    description="Live log streaming with WebSocket support",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "message": "Real-time Log Streaming API",
        "status": "running",
        "timestamp": datetime.now().isoformat(),
        "active_connections": len(connection_manager.active_connections)
    }

@app.get("/api/streams")
async def get_available_streams():
    """Get list of available log streams"""
    streams = await log_streamer.get_available_streams()
    return {"streams": streams}

@app.websocket("/ws/logs/{stream_id}")
async def websocket_logs(websocket: WebSocket, stream_id: str):
    """WebSocket endpoint for real-time log streaming"""
    await connection_manager.connect(websocket, stream_id)
    logger.info("Client connected", stream_id=stream_id)
    
    try:
        # Start streaming logs for this connection
        async for log_entry in log_streamer.stream_logs(stream_id):
            if websocket in connection_manager.active_connections.get(stream_id, set()):
                try:
                    await websocket.send_json(log_entry.dict())
                except Exception as e:
                    logger.error("Failed to send log", error=str(e))
                    break
            else:
                break
                
    except WebSocketDisconnect:
        logger.info("Client disconnected", stream_id=stream_id)
    except Exception as e:
        logger.error("WebSocket error", error=str(e))
    finally:
        connection_manager.disconnect(websocket, stream_id)

@app.websocket("/ws/logs")
async def websocket_logs_multi():
    """WebSocket endpoint for multiple stream subscription"""
    websocket = await connection_manager.connect_multi()
    logger.info("Multi-stream client connected")
    
    try:
        while True:
            # Wait for subscription messages
            data = await websocket.receive_json()
            
            if data.get("action") == "subscribe":
                stream_id = data.get("stream_id")
                await connection_manager.subscribe(websocket, stream_id)
                logger.info("Client subscribed", stream_id=stream_id)
                
            elif data.get("action") == "unsubscribe":
                stream_id = data.get("stream_id")
                await connection_manager.unsubscribe(websocket, stream_id)
                logger.info("Client unsubscribed", stream_id=stream_id)
                
    except WebSocketDisconnect:
        logger.info("Multi-stream client disconnected")
    except Exception as e:
        logger.error("Multi-stream WebSocket error", error=str(e))
    finally:
        await connection_manager.disconnect_multi(websocket)

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_config={
            "version": 1,
            "disable_existing_loggers": False,
            "formatters": {
                "default": {
                    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
                },
            },
            "handlers": {
                "default": {
                    "formatter": "default",
                    "class": "logging.StreamHandler",
                    "stream": "ext://sys.stdout",
                },
            },
            "root": {
                "level": "INFO",
                "handlers": ["default"],
            },
        }
    )
