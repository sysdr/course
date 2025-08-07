#!/usr/bin/env python3

import json
import asyncio
import time
from datetime import datetime
from typing import List, Dict, Any
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="Log Platform API", version="1.0.0")

# Enable CORS for all origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory storage for demo
logs_storage: List[Dict] = []
connected_websockets: List[WebSocket] = []

class LogEntry(BaseModel):
    timestamp: datetime = None
    level: str
    message: str
    service: str
    metadata: Dict[str, Any] = {}

class BatchRequest(BaseModel):
    logs: List[LogEntry]

class StreamConfig(BaseModel):
    filters: Dict[str, Any] = {}
    buffer_size: int = 100
    real_time: bool = True

@app.get("/")
async def root():
    return HTMLResponse("""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Log Platform API Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .header { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 20px; margin-bottom: 30px; }
            .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
            .stat-card { background: #f8f9fa; padding: 20px; border-radius: 6px; border-left: 4px solid #3498db; }
            .stat-number { font-size: 24px; font-weight: bold; color: #2c3e50; }
            .stat-label { color: #7f8c8d; font-size: 14px; }
            .endpoints { margin-top: 30px; }
            .endpoint { background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 6px; border-left: 4px solid #27ae60; }
            .method { display: inline-block; padding: 4px 8px; border-radius: 4px; color: white; font-size: 12px; font-weight: bold; }
            .get { background: #27ae60; }
            .post { background: #3498db; }
            .recent-logs { margin-top: 30px; }
            .log-entry { background: #f8f9fa; padding: 10px; margin: 5px 0; border-radius: 4px; font-family: monospace; font-size: 12px; }
            .log-level { padding: 2px 6px; border-radius: 3px; color: white; font-weight: bold; }
            .info { background: #3498db; }
            .error { background: #e74c3c; }
            .warning { background: #f39c12; }
            .debug { background: #95a5a6; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 Log Platform API Dashboard</h1>
                <p>Multi-Language SDK Testing Environment</p>
            </div>
            
            <div class="stats">
                <div class="stat-card">
                    <div class="stat-number" id="total-logs">0</div>
                    <div class="stat-label">Total Logs Stored</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="websocket-connections">0</div>
                    <div class="stat-label">WebSocket Connections</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">1.0.0</div>
                    <div class="stat-label">API Version</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number" id="uptime">0s</div>
                    <div class="stat-label">Uptime</div>
                </div>
            </div>
            
            <div class="endpoints">
                <h3>Available API Endpoints</h3>
                <div class="endpoint">
                    <span class="method post">POST</span> <strong>/api/v1/logs</strong> - Submit single log entry
                </div>
                <div class="endpoint">
                    <span class="method post">POST</span> <strong>/api/v1/logs/batch</strong> - Submit multiple log entries
                </div>
                <div class="endpoint">
                    <span class="method get">GET</span> <strong>/api/v1/logs/query</strong> - Query logs with filters
                </div>
                <div class="endpoint">
                    <span class="method get">GET</span> <strong>/api/v1/health</strong> - Health check endpoint
                </div>
                <div class="endpoint">
                    <span class="method get">WS</span> <strong>/api/v1/logs/stream</strong> - Real-time log streaming
                </div>
            </div>
            
            <div class="recent-logs">
                <h3>Recent Log Entries</h3>
                <div id="logs-container">
                    <p style="color: #7f8c8d; font-style: italic;">No logs yet. Submit some logs using the SDKs!</p>
                </div>
            </div>
        </div>
        
        <script>
            const startTime = Date.now();
            
            function updateStats() {
                fetch('/api/v1/stats')
                    .then(response => response.json())
                    .then(data => {
                        document.getElementById('total-logs').textContent = data.total_logs;
                        document.getElementById('websocket-connections').textContent = data.websocket_connections;
                        
                        const uptime = Math.floor((Date.now() - startTime) / 1000);
                        document.getElementById('uptime').textContent = uptime + 's';
                    });
            }
            
            function updateRecentLogs() {
                fetch('/api/v1/logs/recent')
                    .then(response => response.json())
                    .then(logs => {
                        const container = document.getElementById('logs-container');
                        if (logs.length === 0) {
                            container.innerHTML = '<p style="color: #7f8c8d; font-style: italic;">No logs yet. Submit some logs using the SDKs!</p>';
                            return;
                        }
                        
                        container.innerHTML = logs.map(log => `
                            <div class="log-entry">
                                <span class="log-level ${log.level.toLowerCase()}">${log.level}</span>
                                <strong>${log.service}</strong> - ${log.message}
                                <span style="float: right; color: #7f8c8d;">${new Date(log.timestamp).toLocaleTimeString()}</span>
                            </div>
                        `).join('');
                    });
            }
            
            // Update every 2 seconds
            setInterval(() => {
                updateStats();
                updateRecentLogs();
            }, 2000);
            
            // Initial load
            updateStats();
            updateRecentLogs();
        </script>
    </body>
    </html>
    """)

@app.post("/api/v1/logs")
async def submit_log(log_entry: LogEntry, authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authentication")
    
    log_dict = log_entry.dict()
    if log_dict.get('timestamp') is None:
        log_dict['timestamp'] = datetime.now()
    
    log_dict['id'] = f"log_{len(logs_storage) + 1}"
    logs_storage.append(log_dict)
    
    # Broadcast to WebSocket connections
    if connected_websockets:
        message = json.dumps({
            "type": "log",
            "payload": log_dict
        }, default=str)
        
        disconnected = []
        for ws in connected_websockets:
            try:
                await ws.send_text(message)
            except:
                disconnected.append(ws)
        
        # Remove disconnected WebSockets
        for ws in disconnected:
            connected_websockets.remove(ws)
    
    return {"success": True, "log_id": log_dict['id'], "message": "Log submitted successfully"}

@app.post("/api/v1/logs/batch")
async def submit_logs_batch(batch_request: BatchRequest, authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authentication")
    
    submitted_count = 0
    for log_entry in batch_request.logs:
        log_dict = log_entry.dict()
        if log_dict.get('timestamp') is None:
            log_dict['timestamp'] = datetime.now()
        
        log_dict['id'] = f"log_{len(logs_storage) + 1}"
        logs_storage.append(log_dict)
        submitted_count += 1
    
    return {"success": True, "submitted_count": submitted_count, "message": f"Batch of {submitted_count} logs submitted successfully"}

@app.get("/api/v1/logs/query")
async def query_logs(q: str = "", limit: int = 100, authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authentication")
    
    start_time = time.time()
    
    # Simple filtering based on query string
    filtered_logs = logs_storage
    if q:
        filtered_logs = [
            log for log in logs_storage 
            if q.lower() in log.get('message', '').lower() or 
               q.lower() in log.get('service', '').lower() or
               q.lower() in log.get('level', '').lower()
        ]
    
    # Apply limit
    result_logs = filtered_logs[-limit:] if limit > 0 else filtered_logs
    
    query_time_ms = int((time.time() - start_time) * 1000)
    
    return {
        "logs": result_logs,
        "total_count": len(filtered_logs),
        "query_time_ms": query_time_ms
    }

@app.websocket("/api/v1/logs/stream")
async def stream_logs(websocket: WebSocket):
    await websocket.accept()
    connected_websockets.append(websocket)
    
    try:
        # Wait for stream configuration
        config_data = await websocket.receive_text()
        stream_config = StreamConfig(**json.loads(config_data))
        
        # Send existing logs if requested
        if not stream_config.real_time:
            for log in logs_storage[-stream_config.buffer_size:]:
                message = json.dumps({
                    "type": "log",
                    "payload": log
                }, default=str)
                await websocket.send_text(message)
        
        # Keep connection alive
        while True:
            await asyncio.sleep(1)
            
    except WebSocketDisconnect:
        if websocket in connected_websockets:
            connected_websockets.remove(websocket)

@app.get("/api/v1/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0",
        "uptime": int(time.time())
    }

@app.get("/api/v1/stats")
async def get_stats():
    return {
        "total_logs": len(logs_storage),
        "websocket_connections": len(connected_websockets)
    }

@app.get("/api/v1/logs/recent")
async def get_recent_logs(limit: int = 10):
    return logs_storage[-limit:] if logs_storage else []

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
