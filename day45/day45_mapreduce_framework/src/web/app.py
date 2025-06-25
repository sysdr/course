from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import json
import asyncio
import os
from typing import List
import uvicorn
from pathlib import Path

from mapreduce.coordinator import JobCoordinator
from mapreduce.job import MapReduceConfig
from mapreduce.analyzers import (
    word_count_mapper, word_count_reducer,
    pattern_frequency_mapper, pattern_frequency_reducer,
    service_distribution_mapper, service_distribution_reducer,
    comprehensive_log_mapper, comprehensive_log_reducer
)

app = FastAPI(title="MapReduce Dashboard", version="1.0.0")

# Global job coordinator
coordinator = JobCoordinator()

# Templates
templates = Jinja2Templates(directory="src/web/templates")

# WebSocket connections for real-time updates
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
                await connection.send_text(json.dumps(message))
            except:
                pass

manager = ConnectionManager()

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Main dashboard page"""
    return templates.TemplateResponse("dashboard.html", {"request": request})

@app.get("/api/jobs")
async def list_jobs():
    """List all MapReduce jobs"""
    return {"jobs": coordinator.list_jobs()}

@app.get("/api/jobs/{job_id}")
async def get_job_status(job_id: str):
    """Get specific job status"""
    return coordinator.get_job_status(job_id)

@app.post("/api/jobs/submit")
async def submit_job(request: Request):
    """Submit new MapReduce job"""
    data = await request.json()
    
    analysis_type = data.get("analysis_type", "word_count")
    input_files = data.get("input_files", [])
    
    if not input_files:
        return JSONResponse({"error": "No input files specified"}, status_code=400)
    
    # Select appropriate mapper/reducer based on analysis type
    if analysis_type == "word_count":
        map_func = word_count_mapper
        reduce_func = word_count_reducer
    elif analysis_type == "pattern_frequency":
        map_func = pattern_frequency_mapper
        reduce_func = pattern_frequency_reducer
    elif analysis_type == "service_distribution":
        map_func = service_distribution_mapper
        reduce_func = service_distribution_reducer
    else:
        map_func = comprehensive_log_mapper
        reduce_func = comprehensive_log_reducer
    
    # Create job configuration
    config = MapReduceConfig(
        input_path="data/input",
        output_path="data/output",
        num_workers=data.get("num_workers", 4)
    )
    
    # Submit job
    job_id = coordinator.submit_job(config, map_func, reduce_func, input_files)
    
    return {"job_id": job_id, "status": "submitted"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await manager.connect(websocket)
    try:
        while True:
            # Send job updates every 2 seconds
            jobs = coordinator.list_jobs()
            await manager.broadcast({"type": "job_update", "jobs": jobs})
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
