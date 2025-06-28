from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import json
import asyncio
import time
from typing import List
import structlog
from pathlib import Path

from ..engine.sessionizer import DistributedSessionizer, UserEvent
from ..analytics.analyzer import SessionAnalyzer
from config.settings import config

logger = structlog.get_logger()

app = FastAPI(title="Sessionization Analytics Dashboard")

# Setup templates and static files
templates = Jinja2Templates(directory="src/web/templates")

# Global instances
sessionizer = DistributedSessionizer(config)
analyzer = SessionAnalyzer()

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except:
                pass

manager = ConnectionManager()

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    await sessionizer.initialize()
    # Start the analytics broadcaster
    asyncio.create_task(broadcast_analytics())

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Main dashboard page"""
    return templates.TemplateResponse("dashboard.html", {"request": request})

@app.get("/api/analytics")
async def get_analytics():
    """Get current analytics data"""
    session_analytics = await sessionizer.get_session_analytics()
    dashboard_data = await analyzer.get_analytics_dashboard_data()
    
    return {
        "session_data": session_analytics,
        "analytics": dashboard_data,
        "timestamp": time.time()
    }

@app.post("/api/events")
async def process_event(event_data: dict):
    """Process a new user event"""
    try:
        # Create UserEvent object
        event = UserEvent(
            user_id=event_data.get('user_id'),
            event_type=event_data.get('event_type'),
            timestamp=event_data.get('timestamp', time.time()),
            page_url=event_data.get('page_url', ''),
            referrer=event_data.get('referrer', ''),
            device_type=event_data.get('device_type', 'web'),
            metadata=event_data.get('metadata', {})
        )
        
        # Process through sessionizer
        session = await sessionizer.process_event(event)
        
        if session:
            # Analyze session
            analysis = await analyzer.analyze_session(session.to_dict())
            
            return {
                "success": True,
                "session_id": session.session_id,
                "analysis": analysis
            }
        else:
            return {"success": False, "error": "Failed to process event"}
            
    except Exception as e:
        logger.error("Error processing event", error=str(e))
        return {"success": False, "error": str(e)}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)

async def broadcast_analytics():
    """Background task to broadcast analytics updates"""
    while True:
        try:
            analytics_data = await get_analytics()
            await manager.broadcast({
                "type": "analytics_update",
                "data": analytics_data
            })
        except Exception as e:
            logger.error("Error broadcasting analytics", error=str(e))
        
        await asyncio.sleep(5)  # Broadcast every 5 seconds

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    await sessionizer.close()
