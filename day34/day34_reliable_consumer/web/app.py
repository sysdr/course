from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import json
import asyncio
from typing import List
import uvicorn

app = FastAPI()

# Store connected websockets for real-time updates
connected_websockets: List[WebSocket] = []

# Mock consumer stats for demo (in real implementation, this would connect to your consumer)
consumer_stats = {
    'messages_processed': 0,
    'messages_acknowledged': 0,
    'messages_failed': 0,
    'messages_redelivered': 0,
    'pending': 0,
    'processing': 0,
    'acknowledged': 0,
    'failed': 0
}

@app.get("/", response_class=HTMLResponse)
async def get_dashboard():
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Reliable Consumer Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
            .dashboard { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
            .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .stat { display: flex; justify-content: space-between; margin: 10px 0; }
            .stat-value { font-weight: bold; color: #2196F3; }
            .status-indicator { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 8px; }
            .status-green { background: #4CAF50; }
            .status-orange { background: #FF9800; }
            .status-red { background: #F44336; }
            h1 { color: #333; text-align: center; }
            h2 { color: #555; border-bottom: 2px solid #2196F3; padding-bottom: 10px; }
        </style>
    </head>
    <body>
        <h1>🛡️ Reliable Consumer Dashboard</h1>
        <div class="dashboard">
            <div class="card">
                <h2>Message Processing Stats</h2>
                <div class="stat">
                    <span>Total Processed:</span>
                    <span class="stat-value" id="processed">0</span>
                </div>
                <div class="stat">
                    <span>Acknowledged:</span>
                    <span class="stat-value" id="acknowledged">0</span>
                </div>
                <div class="stat">
                    <span>Failed:</span>
                    <span class="stat-value" id="failed">0</span>
                </div>
                <div class="stat">
                    <span>Redelivered:</span>
                    <span class="stat-value" id="redelivered">0</span>
                </div>
            </div>
            
            <div class="card">
                <h2>Current Message States</h2>
                <div class="stat">
                    <span><span class="status-indicator status-orange"></span>Pending:</span>
                    <span class="stat-value" id="pending">0</span>
                </div>
                <div class="stat">
                    <span><span class="status-indicator status-green"></span>Processing:</span>
                    <span class="stat-value" id="processing">0</span>
                </div>
                <div class="stat">
                    <span><span class="status-indicator status-green"></span>Success:</span>
                    <span class="stat-value" id="success">0</span>
                </div>
                <div class="stat">
                    <span><span class="status-indicator status-red"></span>Failed State:</span>
                    <span class="stat-value" id="failed-state">0</span>
                </div>
            </div>
            
            <div class="card">
                <h2>System Health</h2>
                <div class="stat">
                    <span>Consumer Status:</span>
                    <span class="stat-value" id="consumer-status">🟢 Running</span>
                </div>
                <div class="stat">
                    <span>Queue Connection:</span>
                    <span class="stat-value" id="queue-status">🟢 Connected</span>
                </div>
                <div class="stat">
                    <span>Success Rate:</span>
                    <span class="stat-value" id="success-rate">95%</span>
                </div>
            </div>
        </div>
        
        <script>
            const ws = new WebSocket('ws://localhost:8000/ws');
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                updateDashboard(data);
            };
            
            function updateDashboard(stats) {
                document.getElementById('processed').textContent = stats.messages_processed;
                document.getElementById('acknowledged').textContent = stats.messages_acknowledged;
                document.getElementById('failed').textContent = stats.messages_failed;
                document.getElementById('redelivered').textContent = stats.messages_redelivered;
                document.getElementById('pending').textContent = stats.pending;
                document.getElementById('processing').textContent = stats.processing;
                document.getElementById('success').textContent = stats.acknowledged;
                document.getElementById('failed-state').textContent = stats.failed;
                
                const total = stats.messages_processed;
                const success = stats.messages_acknowledged;
                const rate = total > 0 ? Math.round((success / total) * 100) : 100;
                document.getElementById('success-rate').textContent = rate + '%';
            }
            
            // Simulate real-time updates for demo
            setInterval(() => {
                fetch('/api/stats').then(r => r.json()).then(updateDashboard);
            }, 1000);
        </script>
    </body>
    </html>
    '''

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    connected_websockets.append(websocket)
    try:
        while True:
            await asyncio.sleep(1)
            await websocket.send_text(json.dumps(consumer_stats))
    except WebSocketDisconnect:
        connected_websockets.remove(websocket)

@app.get("/api/stats")
async def get_stats():
    # Simulate updating stats
    consumer_stats['messages_processed'] += 1
    if consumer_stats['messages_processed'] % 5 != 0:  # 80% success rate
        consumer_stats['messages_acknowledged'] += 1
    else:
        consumer_stats['messages_failed'] += 1
        if consumer_stats['messages_failed'] % 2 == 0:  # Half get redelivered
            consumer_stats['messages_redelivered'] += 1
    
    return consumer_stats

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
