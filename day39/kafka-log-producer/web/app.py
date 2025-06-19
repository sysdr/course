from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import json
import asyncio
import time
import sys
from pathlib import Path

# Add src to path
sys.path.append(str(Path(__file__).parent.parent / "src"))

from producer.kafka_producer import KafkaLogProducer
from utils.log_generator import LogGenerator

app = FastAPI(title="Kafka Producer Dashboard")
app.mount("/static", StaticFiles(directory="web/static"), name="static")
templates = Jinja2Templates(directory="web/templates")

# Global instances
producer = None
generator = LogGenerator()
connected_clients = []

@app.on_event("startup")
async def startup():
    global producer
    try:
        producer = KafkaLogProducer()
        print("✅ Kafka producer initialized for dashboard")
    except Exception as e:
        print(f"❌ Failed to initialize producer: {e}")

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Main dashboard page"""
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "title": "Kafka Producer Dashboard"
    })

@app.get("/api/stats")
async def get_stats():
    """Get current producer statistics"""
    if not producer:
        return {"error": "Producer not initialized"}
        
    return producer.get_stats()

@app.post("/api/send-sample")
async def send_sample_logs():
    """Send sample logs for testing"""
    if not producer:
        return {"error": "Producer not initialized"}
        
    try:
        # Generate 10 sample logs
        logs = generator.generate_batch(10, 1)
        results = producer.send_logs_batch(logs)
        
        return {
            "success": True,
            "logs_sent": results["sent"],
            "logs_failed": results["failed"]
        }
    except Exception as e:
        return {"error": str(e)}

@app.post("/api/send-errors")
async def send_error_burst():
    """Send error burst for testing"""
    if not producer:
        return {"error": "Producer not initialized"}
        
    try:
        error_logs = generator.generate_error_burst(5)
        results = producer.send_logs_batch(error_logs)
        
        return {
            "success": True,
            "error_logs_sent": results["sent"],
            "error_logs_failed": results["failed"]
        }
    except Exception as e:
        return {"error": str(e)}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket for real-time updates"""
    await websocket.accept()
    connected_clients.append(websocket)
    
    try:
        while True:
            # Send periodic updates
            if producer:
                stats = producer.get_stats()
                await websocket.send_text(json.dumps({
                    "type": "stats_update",
                    "data": stats,
                    "timestamp": time.time()
                }))
            
            await asyncio.sleep(2)  # Update every 2 seconds
            
    except WebSocketDisconnect:
        connected_clients.remove(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
