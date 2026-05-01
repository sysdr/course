"""
FastAPI server exposing CX metrics.
Run: uvicorn src.api.server:app --reload --port 8175
"""
import asyncio, json, time
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from dataclasses import asdict
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../.."))

from config.settings import (SESSION_IDLE_TIMEOUT, METRICS_WINDOW_SEC,
                              SIMULATION_EVENTS, API_PORT,
                              SLO_P95_MS, SLO_ERROR_RATE, SLO_COMPLETION_RATE)
from src.ingestor.simulator import generate_events
from src.aggregator.session import SessionAggregator
from src.metrics.computer   import MetricsComputer, CXSnapshot

app = FastAPI(title="Day 175 — CX Monitoring", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

aggregator = SessionAggregator(idle_timeout=SESSION_IDLE_TIMEOUT)
computer   = MetricsComputer(window_sec=METRICS_WINDOW_SEC)
_ingested  = {"count": 0}
WARMUP_EVENTS = int(os.getenv("WARMUP_EVENTS", "900"))

def _warmup_pipeline():
    """Process a bounded batch so dashboard metrics are non-empty before steady-state."""
    for i, ev in enumerate(generate_events(WARMUP_EVENTS)):
        summary = aggregator.ingest(ev)
        if summary:
            computer.consume(summary)
        _ingested["count"] += 1
        if _ingested["count"] % 200 == 0:
            for s in aggregator.flush_expired():
                computer.consume(s)
    for s in aggregator.flush_expired():
        computer.consume(s)
    for s in aggregator.flush_all():
        computer.consume(s)

async def _run_pipeline():
    """Background task: continuously ingest simulated log events."""
    for ev in generate_events(SIMULATION_EVENTS):
        summary = aggregator.ingest(ev)
        if summary:
            computer.consume(summary)
        _ingested["count"] += 1
        if _ingested["count"] % 500 == 0:
            for s in aggregator.flush_expired():
                computer.consume(s)
        await asyncio.sleep(0)   # yield to event loop
    # flush remaining open sessions
    for s in aggregator.flush_all():
        computer.consume(s)
    print(f"[pipeline] ingested {_ingested['count']} events — all sessions closed.")

@app.on_event("startup")
async def startup():
    await asyncio.to_thread(_warmup_pipeline)
    asyncio.create_task(_run_pipeline())

@app.get("/health")
async def health():
    return {"status": "ok", "ingested": _ingested["count"]}

@app.get("/metrics/cx")
async def cx_metrics():
    snap   = computer.snapshot()
    d      = asdict(snap)
    d["slo"] = {
        "p95_breach"        : snap.p95_ms > SLO_P95_MS,
        "error_rate_breach" : snap.error_rate > SLO_ERROR_RATE,
        "completion_breach" : snap.completion_rate < SLO_COMPLETION_RATE,
        "thresholds" : {
            "p95_ms"          : SLO_P95_MS,
            "error_rate"      : SLO_ERROR_RATE,
            "completion_rate" : SLO_COMPLETION_RATE,
        }
    }
    d["ingested_events"] = _ingested["count"]
    return d

# Serve React frontend from /frontend/dist if built, else a simple HTML fallback
_DIST = os.path.join(os.path.dirname(__file__), "..", "..", "frontend", "dist")
_FALLBACK = os.path.join(os.path.dirname(__file__), "..", "..", "frontend", "index.html")

if os.path.isdir(_DIST):
    app.mount("/", StaticFiles(directory=_DIST, html=True), name="static")
else:
    @app.get("/")
    async def root():
        return FileResponse(_FALLBACK)
