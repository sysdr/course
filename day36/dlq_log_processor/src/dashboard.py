import asyncio
import json
from datetime import datetime
from typing import Dict, Any

from fastapi import FastAPI, WebSocket, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import uvicorn

from src.dlq_handler import DLQHandler
from config.settings import settings

app = FastAPI(title="DLQ Log Processing Dashboard")

# Create templates directory and files
import os
os.makedirs("templates", exist_ok=True)

# Dashboard HTML template
dashboard_html = '''
<!DOCTYPE html>
<html>
<head>
    <title>DLQ Log Processing Dashboard</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .stat-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stat-number { font-size: 2em; font-weight: bold; color: #333; }
        .stat-label { color: #666; margin-top: 5px; }
        .dlq-content { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .message-card { border: 1px solid #ddd; border-radius: 4px; padding: 15px; margin-bottom: 10px; background: #fafafa; }
        .failure-type { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 0.8em; font-weight: bold; }
        .parsing_error { background: #ffebee; color: #c62828; }
        .network_error { background: #e3f2fd; color: #1565c0; }
        .resource_error { background: #fff3e0; color: #ef6c00; }
        .unknown_error { background: #f3e5f5; color: #7b1fa2; }
        .timestamp { color: #666; font-size: 0.9em; }
        .button { background: #1976d2; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer; margin: 2px; }
        .button:hover { background: #1565c0; }
        .button.danger { background: #d32f2f; }
        .button.danger:hover { background: #c62828; }
        .status-indicator { width: 10px; height: 10px; border-radius: 50%; display: inline-block; margin-right: 5px; }
        .status-good { background: #4caf50; }
        .status-warning { background: #ff9800; }
        .status-error { background: #f44336; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Dead Letter Queue Dashboard</h1>
            <p>Real-time monitoring of log processing system</p>
            <div id="status">
                <span class="status-indicator status-good"></span>
                <span>System Status: Connected</span>
            </div>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-number" id="primary-count">-</div>
                <div class="stat-label">Primary Queue</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="processed-count">-</div>
                <div class="stat-label">Processed Messages</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="retry-count">-</div>
                <div class="stat-label">Retry Queue</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="dlq-count">-</div>
                <div class="stat-label">Dead Letter Queue</div>
            </div>
        </div>
        
        <div class="dlq-content">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                <h2>Dead Letter Queue Messages</h2>
                <div>
                    <button class="button" onclick="reprocessAll()">Reprocess All</button>
                    <button class="button danger" onclick="clearDLQ()">Clear DLQ</button>
                </div>
            </div>
            
            <div id="dlq-messages">
                <p>Loading messages...</p>
            </div>
        </div>
    </div>

    <script>
        let ws = null;
        let reconnectInterval = null;

        function connect() {
            const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
            ws = new WebSocket(`${protocol}//${location.host}/ws`);
            
            ws.onopen = function() {
                console.log('Connected to WebSocket');
                document.getElementById('status').innerHTML = '<span class="status-indicator status-good"></span><span>System Status: Connected</span>';
                if (reconnectInterval) {
                    clearInterval(reconnectInterval);
                    reconnectInterval = null;
                }
            };
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                updateDashboard(data);
            };
            
            ws.onclose = function() {
                console.log('WebSocket connection closed');
                document.getElementById('status').innerHTML = '<span class="status-indicator status-error"></span><span>System Status: Disconnected</span>';
                
                if (!reconnectInterval) {
                    reconnectInterval = setInterval(() => {
                        console.log('Attempting to reconnect...');
                        connect();
                    }, 5000);
                }
            };
        }

        function updateDashboard(data) {
            document.getElementById('primary-count').textContent = data.stats.primary_count;
            document.getElementById('processed-count').textContent = data.stats.processed_count;
            document.getElementById('retry-count').textContent = data.stats.retry_count;
            document.getElementById('dlq-count').textContent = data.stats.dlq_count;
            
            const messagesDiv = document.getElementById('dlq-messages');
            if (data.dlq_messages.length === 0) {
                messagesDiv.innerHTML = '<p>No messages in dead letter queue</p>';
            } else {
                const messagesHtml = data.dlq_messages.map((msg, index) => `
                    <div class="message-card">
                        <div style="display: flex; justify-content: space-between; align-items: start;">
                            <div>
                                <div><strong>ID:</strong> ${msg.original_message.id}</div>
                                <div><strong>Source:</strong> ${msg.original_message.source}</div>
                                <div><strong>Message:</strong> ${msg.original_message.message}</div>
                                <div class="timestamp">Failed: ${new Date(msg.first_failure).toLocaleString()}</div>
                                <div>Retries: ${msg.retry_count}</div>
                            </div>
                            <div>
                                <span class="failure-type ${msg.failure_type}">${msg.failure_type.replace('_', ' ')}</span>
                                <br><br>
                                <button class="button" onclick="reprocessMessage(${index})">Reprocess</button>
                            </div>
                        </div>
                        <div style="margin-top: 10px; padding: 10px; background: #f0f0f0; border-radius: 4px; font-size: 0.9em;">
                            <strong>Error:</strong> ${msg.error_details}
                        </div>
                    </div>
                `).join('');
                messagesDiv.innerHTML = messagesHtml;
            }
        }

        async function reprocessMessage(index) {
            try {
                const response = await fetch(`/reprocess/${index}`, { method: 'POST' });
                const result = await response.json();
                if (result.success) {
                    console.log('Message reprocessed successfully');
                } else {
                    console.error('Failed to reprocess message');
                }
            } catch (error) {
                console.error('Error reprocessing message:', error);
            }
        }

        async function reprocessAll() {
            if (confirm('Reprocess all DLQ messages?')) {
                try {
                    const response = await fetch('/reprocess-all', { method: 'POST' });
                    const result = await response.json();
                    console.log(`Reprocessed ${result.count} messages`);
                } catch (error) {
                    console.error('Error reprocessing messages:', error);
                }
            }
        }

        async function clearDLQ() {
            if (confirm('Clear all DLQ messages? This cannot be undone.')) {
                try {
                    const response = await fetch('/clear-dlq', { method: 'POST' });
                    const result = await response.json();
                    console.log(`Cleared ${result.count} messages`);
                } catch (error) {
                    console.error('Error clearing DLQ:', error);
                }
            }
        }

        connect();
    </script>
</body>
</html>
'''

with open("templates/dashboard.html", "w") as f:
    f.write(dashboard_html)

templates = Jinja2Templates(directory="templates")
dlq_handler = DLQHandler()

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    return templates.TemplateResponse("dashboard.html", {"request": request})

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    
    try:
        while True:
            # Get current stats and DLQ messages
            stats = await dlq_handler.get_dlq_stats()
            dlq_messages = await dlq_handler.get_dlq_messages(20)
            
            data = {
                "stats": stats,
                "dlq_messages": dlq_messages
            }
            
            await websocket.send_text(json.dumps(data, default=str))
            await asyncio.sleep(2)  # Update every 2 seconds
            
    except Exception as e:
        print(f"WebSocket error: {e}")

@app.post("/reprocess/{index}")
async def reprocess_message(index: int):
    success = await dlq_handler.reprocess_message(index)
    return {"success": success}

@app.post("/reprocess-all")
async def reprocess_all():
    count = await dlq_handler.reprocess_by_failure_type("parsing_error", 100)
    count += await dlq_handler.reprocess_by_failure_type("network_error", 100)
    count += await dlq_handler.reprocess_by_failure_type("resource_error", 100)
    return {"count": count}

@app.post("/clear-dlq")
async def clear_dlq():
    count = await dlq_handler.clear_dlq()
    return {"count": count}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=settings.dashboard_port)
