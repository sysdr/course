"""
Day 83: Root Cause Analysis Engine
Main FastAPI application entry point
"""

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Dict, Any, List
from collections import deque
from datetime import datetime, timedelta

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import uvicorn

from analyzers.root_cause_analyzer import RootCauseAnalyzer
from analyzers.causal_graph import CausalGraphBuilder
from models.log_event import LogEvent, IncidentReport
from api.websocket_manager import WebSocketManager

# Global instances
analyzer = None
ws_manager = None

# Store metrics history
metrics_history = deque(maxlen=100)  # Keep last 100 metrics points
alerts_history = deque(maxlen=50)    # Keep last 50 alerts

@asynccontextmanager
async def lifespan(app: FastAPI):
    global analyzer, ws_manager
    
    # Startup
    print("🚀 Starting Root Cause Analysis Engine...")
    analyzer = RootCauseAnalyzer()
    ws_manager = WebSocketManager()
    
    # Initialize with sample data
    await analyzer.initialize_sample_data()
    print("✅ Engine initialized with sample incident data")
    
    yield
    
    # Shutdown
    print("🛑 Shutting down Root Cause Analysis Engine...")

app = FastAPI(
    title="Root Cause Analysis Engine",
    description="Day 83: Advanced Analytics for Distributed Log Processing",
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

@app.get("/")
async def root():
    return {"message": "Root Cause Analysis Engine", "status": "running"}

@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "analyzer_ready": analyzer is not None,
        "active_incidents": len(analyzer.active_incidents) if analyzer else 0
    }

@app.post("/api/analyze-incident")
async def analyze_incident(events: list[Dict[str, Any]]):
    """Analyze a new incident from log events"""
    if not analyzer:
        raise HTTPException(status_code=503, detail="Analyzer not initialized")
    
    try:
        # Add events to alerts history
        for event in events:
            alerts_history.append(event)

        # Convert to LogEvent objects
        log_events = [LogEvent(**event) for event in events]
        
        # Perform root cause analysis
        incident_report = await analyzer.analyze_incident(log_events)
        
        # Broadcast to connected WebSocket clients
        # Use model_dump with datetime serialization
        incident_data = incident_report.model_dump(mode="json")
        await ws_manager.broadcast_incident_update(incident_data)
        
        return incident_data
    
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/incidents")
async def get_incidents():
    """Get all analyzed incidents"""
    if not analyzer:
        raise HTTPException(status_code=503, detail="Analyzer not initialized")
    
    return [incident.model_dump(mode="json") for incident in analyzer.incident_history]

@app.get("/api/causal-graph/{incident_id}")
async def get_causal_graph(incident_id: str):
    """Get causal graph for specific incident"""
    if not analyzer:
        raise HTTPException(status_code=503, detail="Analyzer not initialized")
    
    graph_data = analyzer.get_causal_graph(incident_id)
    if not graph_data:
        raise HTTPException(status_code=404, detail="Incident not found")
    
    return graph_data

@app.post("/api/metrics")
async def update_metrics(metrics: Dict[str, Any]):
    """Update system metrics"""
    metrics_history.append(metrics)
    return {"status": "success", "message": "Metrics updated"}

@app.get("/api/metrics")
async def get_metrics():
    """Get historical metrics data"""
    timestamps = []
    performance_data = {
        "cpu_utilization": [],
        "memory_usage": [],
        "network": {
            "bytes_sent": [],
            "bytes_recv": []
        }
    }
    resources_data = {
        "disk_io": {
            "write_bytes": [],
            "read_bytes": []
        }
    }

    for metric in metrics_history:
        timestamps.append(metric["timestamp"])
        performance_data["cpu_utilization"].append(metric["performance"]["cpu_utilization"])
        performance_data["memory_usage"].append(metric["performance"]["memory_usage"])
        performance_data["network"]["bytes_sent"].append(metric["performance"]["network"]["bytes_sent"])
        performance_data["network"]["bytes_recv"].append(metric["performance"]["network"]["bytes_recv"])
        resources_data["disk_io"]["write_bytes"].append(metric["resources"]["disk_io"]["write_bytes"])
        resources_data["disk_io"]["read_bytes"].append(metric["resources"]["disk_io"]["read_bytes"])

    return {
        "timestamps": timestamps,
        "performance": performance_data,
        "resources": resources_data
    }

@app.get("/api/alerts")
async def get_alerts():
    """Get historical alerts"""
    return list(alerts_history)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await ws_manager.connect(websocket)
    try:
        while True:
            # Keep connection alive
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)

# Mount static files (frontend)
app.mount("/static", StaticFiles(directory="../../frontend/src"), name="static")

@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard():
    """Serve the main dashboard"""
    with open("../../frontend/src/index.html", "r") as f:
        return HTMLResponse(content=f.read())

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
