# Day 175 — Customer Experience Monitoring

Synthetic log pipeline that turns session-level events into **CX metrics**: latency percentiles (T‑Digest approximation), funnel completion, error-heavy sessions, and abandonment by funnel stage. A FastAPI service exposes JSON metrics and a static dashboard backed by simulated traffic.

There are **no third-party API keys** in this codebase; tune behavior with environment variables described below only.

---

## Prerequisites

- **Python** 3.10+ (`python3` or `python3.11`).
- **`pip`** inside a virtual environment (recommended).

Optional:

- **Docker** and Docker Compose Plugin for containerized runs.

---

## Repository layout (`day175_cx_monitoring`)

| Path | Role |
|------|------|
| `config/settings.py` | Environment-backed defaults (timeouts, window, simulation size, API port). |
| `src/ingestor/simulator.py` | Generates realistic JSON-ish log lines (pages, funnel events, latency, status codes). |
| `src/aggregator/session.py` | Session aggregation until idle timeout or purchase. |
| `src/metrics/tdigest.py` | Streaming percentile estimates. |
| `src/metrics/computer.py` | Rolling-window CX snapshot computation. |
| `src/api/server.py` | FastAPI app, ingestion loop, endpoints, dashboard static fallback. |
| `frontend/index.html` | Static dashboard when `frontend/dist/` is absent. |
| `tests/` | `pytest` unit and integration coverage. |
| `docker/` | `Dockerfile` and `docker-compose.yml`. |
| `requirements.txt` | Python dependency pins for app + tests. |

---

## Install and run (local)

From this directory (`day175_cx_monitoring/`):

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Start the API and dashboard:

```bash
uvicorn src.api.server:app --host 0.0.0.0 --port 8175
```

Or use helpers (creates venv if needed, installs deps, runs tests, starts server):

```bash
chmod +x start.sh stop.sh cleanup.sh   # once
./start.sh
```

Stop:

```bash
./stop.sh
```

**URLs:**

- Dashboard and API root: **http://localhost:8175/**
- Metrics JSON: **http://localhost:8175/metrics/cx**
- Health: **http://localhost:8175/health**

---

## Environment variables (optional)

| Variable | Typical default | Meaning |
|---------|-----------------|--------|
| `API_PORT` | `8175` | Port baked into compose; override when running `uvicorn` manually. |
| `SESSION_IDLE_TIMEOUT` | `1800` | Seconds before a tracked session expires. |
| `METRICS_WINDOW_SEC` | `300` | Rolling window for summarized sessions/latencies. |
| `SIMULATION_EVENTS` | `10000` | Number of simulated events ingested after startup warmup. |
| `WARMUP_EVENTS` | `900` | Initial batch so metrics are populated quickly. |
| `SLO_P95_MS` | `2000` | Alert threshold flag in `/metrics/cx` `slo` block. |
| `SLO_ERROR_RATE` | `0.005` | Max acceptable error-heavy session fraction. |
| `SLO_COMPLETION_RATE` | `0.30` | Minimum acceptable funnel completion in window. |

`REDIS_URL` appears in defaults for illustration; this demo does **not** start Redis unless you extend the codebase.

---

## Tests

```bash
source .venv/bin/activate
python -m pytest tests/ -v --tb=short
```

Dependencies for tests (`pytest`, `pytest-asyncio`, `httpx`) are listed in `requirements.txt`.

---

## Docker

From **`docker/`** (Compose build context is the project root):

```bash
cd docker
docker compose up --build
```

The service listens on host port **8175** mapped to container port **8175**.

---

## Tear down and Docker cleanup

```bash
./cleanup.sh
```

This stops the local HTTP service, brings down this project’s Compose stack (removes **local** images built for `cx-monitor`), and runs non-destructive `docker ... prune -f` cleanups.

To also remove **all** unused Docker images globally (including non-dangling):

```bash
DOCKER_PRUNE_ALL_UNUSED_IMAGES=1 ./cleanup.sh
```

Remove local Python/ephemeral artefacts yourself when needed (`rm -rf .venv .pytest_cache`, delete `*.pyc` / `__pycache__`); see `.gitignore` for what should stay out of version control.

---

## License / attribution

Part of the SystemDR hands-on system design curriculum. Customize for your observability demos and production gateways as needed.
