from __future__ import annotations

import asyncio
from pathlib import Path
from typing import Any, Dict, Optional

import structlog
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from src.monitoring.health_monitor import HealthMonitor
from src.regions.region_manager import RegionManager
from src.replication.replication_controller import ReplicationController

logger = structlog.get_logger()


class LogWriteRequest(BaseModel):
    message: str = Field(..., min_length=1)
    level: str = Field(default="info")
    service: str = Field(default="unknown")
    metadata: Dict[str, Any] = Field(default_factory=dict)


def build_default_cluster() -> tuple[ReplicationController, HealthMonitor]:
    # In-process simulated regions (used for tests + single-process demo).
    regions = {
        "us-east": RegionManager(region_name="us-east", port=8000, peers=["europe", "asia"]),
        "europe": RegionManager(region_name="europe", port=8000, peers=["us-east", "asia"]),
        "asia": RegionManager(region_name="asia", port=8000, peers=["us-east", "europe"]),
    }
    controller = ReplicationController(regions=regions)
    monitor = HealthMonitor(controller=controller)
    return controller, monitor


controller, monitor = build_default_cluster()

app = FastAPI(
    title="Day 60: Multi-Region Log Replication System",
    description="In-process multi-region replication simulation with health + dashboard.",
    version="1.0.0",
)

REGION_COLORS = {"us-east": "#3B82F6", "europe": "#10B981", "asia": "#F59E0B"}


@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    # Serve as raw HTML (not a Jinja2 template). The dashboard uses Vue's `{{ }}`.
    html_path = Path(__file__).resolve().parents[2] / "templates" / "dashboard.html"
    return HTMLResponse(content=html_path.read_text(encoding="utf-8"))


@app.get("/favicon.ico")
async def favicon():
    # Avoid noisy 404s in browser console.
    return HTMLResponse(content="", status_code=204)


@app.get("/api/health")
async def api_health():
    return monitor.get_system_health()


@app.get("/api/status")
async def api_status():
    """
    Dashboard-friendly region status.
    Returns a list (not wrapped) to match the existing dashboard.html JS.
    """
    state = controller.get_cluster_state()
    regions = state["regions"]
    out = []
    for name, stats in regions.items():
        out.append(
            {
                "region": name,
                "status": "healthy",
                "log_count": stats["log_count"],
                "timestamp": "",  # kept for template compatibility
                "color": REGION_COLORS.get(name, "#6B7280"),
            }
        )
    return out


@app.post("/api/logs")
async def api_write_log(req: LogWriteRequest):
    log_id = await controller.write_log(
        {
            "message": req.message,
            "level": req.level,
            "service": req.service,
            "metadata": req.metadata,
        }
    )
    logger.info("log_written", log_id=log_id, primary=controller.primary_region)
    # Match the existing dashboard's expectation: result.status === "success"
    return {
        "status": "success",
        "success": True,
        "log_id": log_id,
        "primary_region": controller.primary_region,
    }


@app.get("/api/logs")
async def api_list_logs(region: Optional[str] = None, limit: int = 100):
    state = controller.get_cluster_state()
    regions = state["regions"]

    entries = []
    for name, stats in regions.items():
        if region and name != region:
            continue
        rm = controller.regions[name]
        for e in rm.log_store.values():
            # Shape expected by templates/dashboard.html:
            # { id, timestamp, region, level, message, metadata, source_region, color }
            data = dict(e.data or {})
            entries.append(
                {
                    "id": e.log_id,
                    "timestamp": e.created_at.isoformat(),
                    "region": e.region,
                    "level": data.get("level", "info"),
                    "message": data.get("message", ""),
                    "metadata": data.get("metadata", {}),
                    "source_region": name,
                    "color": REGION_COLORS.get(name, "#6B7280"),
                }
            )

    entries.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
    return {"logs": entries[:limit]}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    logger.info("ws_connected")
    try:
        while True:
            await websocket.send_json(
                {
                    "type": "system_update",
                    "health": monitor.get_system_health(),
                }
            )
            await asyncio.sleep(5)
    except WebSocketDisconnect:
        logger.info("ws_disconnected")

