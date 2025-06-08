from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
import asyncio
import json
from src.consistency_manager import ConsistencyManager, ConsistencyLevel

app = FastAPI(title="Quorum Consistency Demo")
templates = Jinja2Templates(directory="web")

# Global manager
manager = ConsistencyManager()

@app.on_event("startup")
async def startup():
    # Setup 5-node cluster
    nodes = [f"node-{i}" for i in range(1, 6)]
    await manager.setup_cluster(nodes, ConsistencyLevel.BALANCED)

@app.on_event("shutdown")
async def shutdown():
    await manager.shutdown()

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "metrics": manager.get_metrics()
    })

@app.post("/write")
async def write_data(key: str = Form(...), value: str = Form(...)):
    result = await manager.write_with_quorum(key, value)
    return result

@app.post("/read")
async def read_data(key: str = Form(...)):
    result = await manager.read_with_quorum(key)
    return result

@app.post("/consistency")
async def change_consistency(level: str = Form(...)):
    consistency_level = ConsistencyLevel(level)
    await manager.change_consistency_level(consistency_level)
    return {"status": "success", "level": level}

@app.get("/metrics")
async def get_metrics():
    return manager.get_metrics()
