from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import json
import uuid
from datetime import datetime, timedelta
import random
from typing import Dict, List
from .models.dashboard import Dashboard, Widget
from .services.data_generator import LogDataGenerator
from .api.dashboards import router as dashboard_router

app = FastAPI(title="Log Dashboard System")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# WebSocket connections
connections: Dict[str, WebSocket] = {}
data_generator = LogDataGenerator()

@app.get("/")
async def root():
    return {"message": "Log Dashboard System API"}

@app.get("/api/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

app.include_router(dashboard_router, prefix="/api")

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    connections[client_id] = websocket
    
    try:
        while True:
            # Generate and send live log data
            log_data = data_generator.generate_log_batch(10)
            metrics = data_generator.generate_metrics()
            
            message = {
                "type": "live_data",
                "logs": log_data,
                "metrics": metrics,
                "timestamp": datetime.now().isoformat()
            }
            
            await websocket.send_text(json.dumps(message))
            await asyncio.sleep(2)  # Update every 2 seconds
            
    except WebSocketDisconnect:
        del connections[client_id]

# Background task to simulate log processing
@app.on_event("startup")
async def startup_event():
    asyncio.create_task(broadcast_system_status())

async def broadcast_system_status():
    while True:
        if connections:
            status = {
                "type": "system_status",
                "active_connections": len(connections),
                "system_load": random.uniform(0.1, 0.9),
                "timestamp": datetime.now().isoformat()
            }
            
            disconnected = []
            for client_id, websocket in connections.items():
                try:
                    await websocket.send_text(json.dumps(status))
                except:
                    disconnected.append(client_id)
            
            for client_id in disconnected:
                del connections[client_id]
        
        await asyncio.sleep(5)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
