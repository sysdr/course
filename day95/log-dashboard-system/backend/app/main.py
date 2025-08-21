from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import json
import uuid
from datetime import datetime
import random
from typing import Dict

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

@app.get("/")
async def root():
    return {"message": "Log Dashboard System API"}

@app.get("/api/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    connections[client_id] = websocket
    
    try:
        while True:
            # Generate and send live log data
            log_data = generate_log_batch(10)
            metrics = generate_metrics()
            
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

def generate_log_entry():
    services = ['web-api', 'auth-service', 'db-service', 'cache-service']
    log_levels = ['INFO', 'WARNING', 'ERROR', 'DEBUG']
    endpoints = ['/api/users', '/api/orders', '/api/products', '/health']
    
    return {
        'id': str(uuid.uuid4()),
        'timestamp': datetime.now().isoformat(),
        'level': random.choice(log_levels),
        'service': random.choice(services),
        'endpoint': random.choice(endpoints),
        'message': f"Log entry {random.randint(1000, 9999)}",
        'response_time': random.uniform(10, 500),
        'status_code': random.choices([200, 201, 400, 404, 500], weights=[70, 10, 10, 5, 5])[0],
        'user_id': str(uuid.uuid4()) if random.random() > 0.3 else None,
        'ip_address': f"192.168.1.{random.randint(1, 255)}",
    }

def generate_log_batch(count: int = 10):
    return [generate_log_entry() for _ in range(count)]

def generate_metrics():
    return {
        'requests_per_second': random.uniform(100, 1000),
        'error_rate': random.uniform(0.01, 0.1),
        'avg_response_time': random.uniform(50, 200),
        'active_users': random.randint(500, 5000),
        'cpu_usage': random.uniform(0.1, 0.9),
        'memory_usage': random.uniform(0.3, 0.8),
        'disk_usage': random.uniform(0.2, 0.7),
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
