import asyncio
import json
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from typing import List, Dict, Any
import uvicorn
import structlog

from profiler.profiler_engine import ProfilerEngine
from optimizer.optimization_engine import OptimizationEngine
from analyzer.log_analyzer import LogAnalyzer, generate_test_logs
from config.profiler_config import DEFAULT_CONFIG

logger = structlog.get_logger()

profiler_engine = ProfilerEngine(DEFAULT_CONFIG)
optimization_engine = OptimizationEngine(DEFAULT_CONFIG)
log_analyzer = LogAnalyzer()

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
            except Exception:
                pass

manager = ConnectionManager()

def merge_dashboard_metrics() -> Dict[str, Any]:
    """Combine profiler samples with log-analyzer stats for the dashboard."""
    prof = profiler_engine.get_metrics_summary()
    if not prof:
        prof = {"summary": {}, "bottlenecks": [], "function_timings": {}}
    stats = log_analyzer.get_performance_stats()
    if stats.get("status") == "no_data":
        stats = {"processed_count": 0, "error_count": 0, "error_rate": 0.0}
    summary = dict(prof.get("summary") or {})
    dur = float(summary.get("profiling_duration_seconds") or 0)
    if dur <= 0:
        dur = 0.001
    processed = int(stats.get("processed_count") or 0)
    summary["logs_processed"] = processed
    summary["logs_per_second"] = round(processed / dur, 2)
    prof["summary"] = summary
    prof["analyzer"] = stats
    return prof

async def simulate_log_processing():
    """Background task to simulate ongoing log processing"""
    while profiler_engine.is_profiling:
        test_logs = generate_test_logs(20)
        await log_analyzer.process_log_batch(test_logs)
        
        if manager.active_connections:
            metrics = merge_dashboard_metrics()
            await manager.broadcast({
                "type": "metrics_update",
                "data": metrics
            })
        
        await asyncio.sleep(1)

@asynccontextmanager
async def lifespan(app: FastAPI):
    profiler_engine.start_profiling()
    asyncio.create_task(simulate_log_processing())
    yield
    if profiler_engine.is_profiling:
        profiler_engine.stop_profiling()

app = FastAPI(title="Log Performance Profiler Dashboard", version="1.0.0", lifespan=lifespan)

app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Main dashboard page"""
    return templates.TemplateResponse("dashboard.html", {"request": request})

@app.post("/api/start-profiling")
async def start_profiling():
    """Start performance profiling"""
    if not profiler_engine.is_profiling:
        profiler_engine.start_profiling()
        asyncio.create_task(simulate_log_processing())
        return {"status": "started", "message": "Profiling started successfully"}
    else:
        return {"status": "already_running", "message": "Profiling is already running"}

@app.post("/api/stop-profiling")
async def stop_profiling():
    """Stop performance profiling and get results"""
    if profiler_engine.is_profiling:
        metrics_summary = profiler_engine.stop_profiling()
        optimization_report = optimization_engine.generate_optimization_report(metrics_summary)
        return {
            "status": "stopped",
            "metrics": merge_dashboard_metrics(),
            "optimization_report": optimization_report
        }
    else:
        return {"status": "not_running", "message": "Profiling is not currently running"}

@app.get("/api/metrics")
async def get_current_metrics():
    """Get current performance metrics (profiler + log analyzer)"""
    return merge_dashboard_metrics()

@app.get("/api/optimization-suggestions")
async def get_optimization_suggestions():
    """Get current optimization suggestions"""
    metrics_summary = profiler_engine.get_metrics_summary()
    if metrics_summary:
        suggestions = optimization_engine.analyze_performance_data(metrics_summary)
        return {"suggestions": [suggestion.__dict__ for suggestion in suggestions]}
    else:
        return {"suggestions": []}

@app.post("/api/load-test")
async def run_load_test(test_config: dict = None):
    """Run load test to generate performance data"""
    if test_config is None:
        test_config = {"log_count": 1000, "batch_size": 50, "concurrent_batches": 10}
    
    if not profiler_engine.is_profiling:
        profiler_engine.start_profiling()
        asyncio.create_task(simulate_log_processing())
    
    log_count = test_config.get("log_count", 1000)
    batch_size = test_config.get("batch_size", 50)
    concurrent_batches = test_config.get("concurrent_batches", 10)
    
    logger.info(f"Starting load test: {log_count} logs, batch size {batch_size}")
    
    test_logs = generate_test_logs(log_count)
    batches = [test_logs[i:i + batch_size] for i in range(0, len(test_logs), batch_size)]
    
    tasks = []
    for i in range(0, len(batches), concurrent_batches):
        batch_group = batches[i:i + concurrent_batches]
        for batch in batch_group:
            task = log_analyzer.process_log_batch(batch)
            tasks.append(task)
    
    results = await asyncio.gather(*tasks)
    
    analyzer_stats = log_analyzer.get_performance_stats()
    profiler_stats = merge_dashboard_metrics()
    
    return {
        "status": "completed",
        "load_test_config": test_config,
        "analyzer_stats": analyzer_stats,
        "profiler_stats": profiler_stats,
        "processed_batches": len(results)
    }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await manager.connect(websocket)
    try:
        while True:
            metrics = merge_dashboard_metrics()
            await websocket.send_text(json.dumps({
                "type": "metrics_update",
                "data": metrics
            }))
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
