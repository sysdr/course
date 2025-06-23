import asyncio
import json
from typing import Dict, Any
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from contextlib import asynccontextmanager

from src.config.kafka_config import KafkaConfig
from src.config.app_config import AppConfig
from src.consumer.state_consumer import AsyncStateConsumer
from src.monitor.compaction_monitor import AsyncCompactionMonitor
import structlog

logger = structlog.get_logger(__name__)


class DashboardManager:
    """Manages dashboard data and WebSocket connections"""
    
    def __init__(self):
        self.kafka_config = KafkaConfig.from_yaml()
        self.app_config = AppConfig.from_yaml()
        self.consumer = AsyncStateConsumer(self.kafka_config)
        self.monitor = AsyncCompactionMonitor(self.kafka_config, self.app_config)
        self.connections: list[WebSocket] = []
        
    async def start(self):
        """Start dashboard services"""
        await self.consumer.start_consuming()
        await self.monitor.start_monitoring()
        
        # Start update broadcast task
        asyncio.create_task(self._broadcast_updates())
        
        logger.info("Dashboard manager started")
    
    async def stop(self):
        """Stop dashboard services"""
        self.consumer.stop()
        self.monitor.stop()
        logger.info("Dashboard manager stopped")
    
    async def add_connection(self, websocket: WebSocket):
        """Add WebSocket connection"""
        self.connections.append(websocket)
        logger.info(f"WebSocket connected, total: {len(self.connections)}")
    
    async def remove_connection(self, websocket: WebSocket):
        """Remove WebSocket connection"""
        if websocket in self.connections:
            self.connections.remove(websocket)
        logger.info(f"WebSocket disconnected, total: {len(self.connections)}")
    
    async def get_dashboard_data(self) -> Dict[str, Any]:
        """Get current dashboard data"""
        state_stats = self.consumer.get_state_stats()
        compaction_metrics = self.monitor.get_compaction_effectiveness()
        current_state = self.consumer.get_current_state()
        
        # Recent updates (simulate for demo)
        recent_updates = []
        for user_id, profile in list(current_state.items())[-10:]:
            recent_updates.append({
                'userId': user_id,
                'updateType': 'UPDATE',
                'timestamp': profile.last_updated.isoformat(),
                'version': profile.version
            })
        
        return {
            'total_messages': int(compaction_metrics['total_messages']),
            'unique_keys': int(compaction_metrics['unique_keys']),
            'compaction_ratio': compaction_metrics['compaction_ratio'],
            'storage_saved_percent': compaction_metrics['storage_saved_percent'],
            'state_stats': state_stats,
            'recent_updates': recent_updates
        }
    
    async def _broadcast_updates(self):
        """Broadcast updates to all connected clients"""
        while True:
            try:
                if self.connections:
                    data = await self.get_dashboard_data()
                    message = json.dumps(data)
                    
                    # Send to all connections
                    for connection in self.connections.copy():
                        try:
                            await connection.send_text(message)
                        except Exception as e:
                            logger.error(f"Error sending to WebSocket: {e}")
                            await self.remove_connection(connection)
                
                await asyncio.sleep(3)  # Update every 3 seconds
                
            except Exception as e:
                logger.error(f"Error in broadcast loop: {e}")
                await asyncio.sleep(3)


# Global dashboard manager
dashboard_manager = DashboardManager()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    await dashboard_manager.start()
    yield
    # Shutdown
    await dashboard_manager.stop()


def create_app() -> FastAPI:
    """Create FastAPI application"""
    app = FastAPI(
        title="Kafka Log Compaction Dashboard",
        description="Real-time monitoring of log compaction effectiveness",
        version="1.0.0",
        lifespan=lifespan
    )
    
    # Templates
    templates = Jinja2Templates(directory="src/web/templates")
    
    @app.get("/", response_class=HTMLResponse)
    async def dashboard(request: Request):
        """Main dashboard page"""
        return templates.TemplateResponse(
            "dashboard.html", 
            {"request": request}
        )
    
    @app.get("/api/metrics")
    async def get_metrics():
        """Get current metrics"""
        return await dashboard_manager.get_dashboard_data()
    
    @app.websocket("/ws")
    async def websocket_endpoint(websocket: WebSocket):
        """WebSocket endpoint for real-time updates"""
        await websocket.accept()
        await dashboard_manager.add_connection(websocket)
        
        try:
            while True:
                # Keep connection alive
                await websocket.receive_text()
        except WebSocketDisconnect:
            await dashboard_manager.remove_connection(websocket)
    
    return app
