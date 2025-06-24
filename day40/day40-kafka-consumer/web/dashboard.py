from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
import json
import asyncio
import time
import uvicorn
from typing import List
import structlog

logger = structlog.get_logger()

class ConsumerDashboard:
    def __init__(self, consumer):
        self.app = FastAPI(title="Kafka Consumer Dashboard")
        self.consumer = consumer
        import os
        template_dir = os.path.join(os.path.dirname(__file__), "templates")
        self.templates = Jinja2Templates(directory=template_dir)
        self.active_connections: List[WebSocket] = []
        
        self.setup_routes()
        
    def setup_routes(self):
        @self.app.get("/", response_class=HTMLResponse)
        async def dashboard(request: Request):
            return self.templates.TemplateResponse("dashboard.html", {"request": request})
            
        @self.app.get("/api/stats")
        async def get_stats():
            return self.consumer.get_stats()
            
        @self.app.get("/api/analytics")  
        async def get_analytics():
            return self.consumer.processor.get_analytics()
            
        @self.app.get("/api/metrics")
        async def get_metrics():
            return self.consumer.metrics.get_current_metrics()
            
        @self.app.websocket("/ws")
        async def websocket_endpoint(websocket: WebSocket):
            await websocket.accept()
            self.active_connections.append(websocket)
            
            try:
                while True:
                    # Send real-time updates every 2 seconds
                    data = {
                        'stats': self.consumer.get_stats(),
                        'analytics': self.consumer.processor.get_analytics(),
                        'metrics': self.consumer.metrics.get_current_metrics(),
                        'timestamp': time.time()
                    }
                    await websocket.send_text(json.dumps(data))
                    await asyncio.sleep(2)
                    
            except WebSocketDisconnect:
                self.active_connections.remove(websocket)
                
    async def broadcast_update(self, data: dict):
        """Broadcast update to all connected clients"""
        if self.active_connections:
            message = json.dumps(data)
            for connection in self.active_connections[:]:  # Copy list to avoid modification during iteration
                try:
                    await connection.send_text(message)
                except:
                    self.active_connections.remove(connection)
                    
    def start_server(self, host: str = "0.0.0.0", port: int = 8080):
        """Start the dashboard server"""
        uvicorn.run(self.app, host=host, port=port, log_level="info")
