#!/usr/bin/env python3
"""Real-time Kafka monitoring dashboard."""

import json
import asyncio
from fastapi import FastAPI, WebSocket
from fastapi.responses import HTMLResponse
from confluent_kafka import Consumer
import threading
import time
from collections import deque

app = FastAPI()

# Store recent messages for dashboard
recent_messages = deque(maxlen=100)
stats = {'total_messages': 0, 'error_count': 0, 'services': set()}

def kafka_consumer_thread():
    """Background thread to consume Kafka messages."""
    consumer = Consumer({
        'bootstrap.servers': 'localhost:9092',
        'group.id': 'dashboard-group',
        'auto.offset.reset': 'latest'
    })
    consumer.subscribe(['web-api-logs', 'user-service-logs', 'payment-service-logs', 'critical-logs'])
    
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            continue
            
        try:
            log_entry = json.loads(msg.value().decode('utf-8'))
            log_entry['topic'] = msg.topic()
            recent_messages.append(log_entry)
            
            stats['total_messages'] += 1
            if log_entry.get('level') == 'ERROR':
                stats['error_count'] += 1
            stats['services'].add(log_entry.get('service', 'unknown'))
        except:
            continue

# Start Kafka consumer in background
threading.Thread(target=kafka_consumer_thread, daemon=True).start()

@app.get("/")
async def dashboard():
    """Serve the monitoring dashboard."""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Kafka Log Monitoring Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
            .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
            .stats { display: flex; gap: 20px; margin: 20px 0; }
            .stat-card { background: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .messages { background: white; padding: 20px; border-radius: 5px; max-height: 600px; overflow-y: auto; }
            .message { padding: 10px; margin: 5px 0; border-left: 4px solid #3498db; background: #ecf0f1; }
            .error { border-left-color: #e74c3c; background: #fadbd8; }
            .critical { border-left-color: #f39c12; background: #fdeaa7; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🚀 Kafka Log Processing Dashboard</h1>
            <p>Real-time monitoring of distributed log streams</p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <h3>Total Messages</h3>
                <p id="total-messages">0</p>
            </div>
            <div class="stat-card">
                <h3>Error Count</h3>
                <p id="error-count">0</p>
            </div>
            <div class="stat-card">
                <h3>Active Services</h3>
                <p id="service-count">0</p>
            </div>
        </div>
        
        <div class="messages">
            <h3>Recent Log Messages</h3>
            <div id="message-list"></div>
        </div>
        
        <script>
            const ws = new WebSocket("ws://localhost:8000/ws");
            
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                
                // Update stats
                document.getElementById('total-messages').textContent = data.stats.total_messages;
                document.getElementById('error-count').textContent = data.stats.error_count;
                document.getElementById('service-count').textContent = data.stats.services.length;
                
                // Update messages
                const messageList = document.getElementById('message-list');
                messageList.innerHTML = '';
                
                data.messages.forEach(msg => {
                    const div = document.createElement('div');
                    div.className = 'message';
                    if (msg.level === 'ERROR') div.className += ' error';
                    if (msg.topic === 'critical-logs') div.className += ' critical';
                    
                    div.innerHTML = `
                        <strong>${msg.service || msg.topic}</strong> 
                        [${msg.level || 'INFO'}] 
                        ${msg.timestamp}
                        <br>
                        <small>${JSON.stringify(msg, null, 2)}</small>
                    `;
                    messageList.appendChild(div);
                });
            };
            
            // Request updates every second
            setInterval(() => {
                if (ws.readyState === WebSocket.OPEN) {
                    ws.send('get_update');
                }
            }, 1000);
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates."""
    await websocket.accept()
    
    while True:
        try:
            await websocket.receive_text()
            
            # Send current stats and messages
            update_data = {
                'stats': {
                    'total_messages': stats['total_messages'],
                    'error_count': stats['error_count'],
                    'services': list(stats['services'])
                },
                'messages': list(recent_messages)
            }
            
            await websocket.send_text(json.dumps(update_data))
        except:
            break

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
