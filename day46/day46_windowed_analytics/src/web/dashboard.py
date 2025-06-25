from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import json
import asyncio
from typing import List
import structlog
import os

logger = structlog.get_logger()

class WindowingDashboard:
    def __init__(self, window_manager, aggregation_coordinator):
        self.app = FastAPI(title="Windowed Analytics Dashboard")
        self.window_manager = window_manager
        self.aggregation_coordinator = aggregation_coordinator
        self.templates = Jinja2Templates(directory="src/web/templates")
        self.active_connections: List[WebSocket] = []
        
        # Setup routes
        self._setup_routes()
        
    def _setup_routes(self):
        @self.app.get("/", response_class=HTMLResponse)
        async def dashboard(request: Request):
            return self.templates.TemplateResponse("dashboard.html", {"request": request})
            
        @self.app.get("/test", response_class=HTMLResponse)
        async def test_dashboard(request: Request):
            logger.info("Test dashboard route accessed")
            return self.templates.TemplateResponse("test_dashboard.html", {"request": request})
            
        @self.app.get("/api/metrics/{window_type}")
        async def get_metrics(window_type: str, limit: int = 20):
            metrics = await self.aggregation_coordinator.get_windowed_metrics(window_type, limit)
            return {"metrics": metrics, "window_type": window_type}
            
        @self.app.get("/api/active_windows")
        async def get_active_windows():
            return {
                "active_windows": list(self.window_manager.active_windows.keys()),
                "count": len(self.window_manager.active_windows)
            }
            
        @self.app.websocket("/ws")
        async def websocket_endpoint(websocket: WebSocket):
            await self._handle_websocket(websocket)
            
    async def _handle_websocket(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info("WebSocket connection opened", connection_count=len(self.active_connections))
        
        try:
            while True:
                # Send updates more frequently
                await asyncio.sleep(1)  # Changed from 2 to 1 second for more responsive updates
                
                # Get current metrics
                try:
                    metrics_5min = await self.aggregation_coordinator.get_windowed_metrics("5min", 10)
                    metrics_1hour = await self.aggregation_coordinator.get_windowed_metrics("1hour", 5)
                    
                    update = {
                        "type": "metrics_update",
                        "data": {
                            "5min": metrics_5min,
                            "1hour": metrics_1hour,
                            "active_windows": len(self.window_manager.active_windows)
                        }
                    }
                    
                    logger.debug("Sending WebSocket update", 
                              metrics_count=len(metrics_5min), 
                              active_windows=len(self.window_manager.active_windows))
                    
                    await websocket.send_text(json.dumps(update))
                    
                except Exception as e:
                    logger.error("Error preparing WebSocket update", error=str(e))
                    # Send error update to client
                    error_update = {
                        "type": "error",
                        "message": "Failed to get metrics"
                    }
                    await websocket.send_text(json.dumps(error_update))
                    await asyncio.sleep(5)  # Wait before retrying
                
        except WebSocketDisconnect:
            logger.info("WebSocket connection closed normally")
        except Exception as e:
            logger.error("WebSocket error", error=str(e))
        finally:
            if websocket in self.active_connections:
                self.active_connections.remove(websocket)
            logger.info("WebSocket connection removed", connection_count=len(self.active_connections))
            
    async def broadcast_update(self, data: dict):
        """Broadcast update to all connected clients"""
        if self.active_connections:
            message = json.dumps(data)
            disconnected = []
            for connection in self.active_connections:
                try:
                    await connection.send_text(message)
                except Exception as e:
                    logger.error("Failed to send to WebSocket", error=str(e))
                    disconnected.append(connection)
            
            # Remove disconnected connections
            for conn in disconnected:
                if conn in self.active_connections:
                    self.active_connections.remove(conn)
