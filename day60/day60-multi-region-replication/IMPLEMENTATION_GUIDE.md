# Implementation Guide — Day 60: Multi‑Region Log Replication

This guide explains how to **run**, **test**, and **understand/extend** the Day 60 project: a three‑region log replication simulation with a real-time dashboard.

It’s written to be **safe and clear**:
- It runs locally on your machine (localhost / 127.0.0.1).
- It does **not** require any API keys.
- Docker usage is optional.

---

## What you’re building

A small distributed-systems simulation that demonstrates:
- **Primary/secondary log replication** across three regions (US‑East, Europe, Asia)
- **Primary election** (deterministic; prefers `us-east`)
- **Conflict resolution** using **vector clocks**, with deterministic tie-breaking
- **Health monitoring** including replication lag
- **Web dashboard** + **WebSocket** system updates

This is intentionally lightweight: the “regions” are **in-process RegionManagers** (not separate servers), which makes the project easy to run and test while still modeling core replication concepts.

---

## Quick start (recommended)

### Clone and enter the project

```bash
git clone https://github.com/sysdr/course.git
cd course
git checkout day60
cd day60/day60-multi-region-replication
```

### Create venv and install dependencies

```bash
python3 -m venv venv
. venv/bin/activate
pip install -r requirements.txt
```

### Run tests

```bash
python -m pytest -q
```

### Start the app

```bash
python -m uvicorn src.web.app:app --host 127.0.0.1 --port 8000
```

Open the dashboard at `http://localhost:8000`.

---

## API endpoints

The FastAPI app is implemented in `src/web/app.py`.

- **Dashboard**: `GET /`
- **Health**: `GET /api/health`
- **Region status (dashboard polling)**: `GET /api/status`
- **Write log**: `POST /api/logs`
- **List logs**: `GET /api/logs?limit=25`
- **WebSocket updates**: `WS /ws` (system updates every 5 seconds)

### Example: health check

```bash
curl -s http://127.0.0.1:8000/api/health
```

### Example: write a log

```bash
curl -s -X POST http://127.0.0.1:8000/api/logs \
  -H "Content-Type: application/json" \
  -d '{"message":"Test log","level":"info","service":"test"}'
```

### Example: list logs

```bash
curl -s "http://127.0.0.1:8000/api/logs?limit=10"
```

---

## Demo

Run the demo (expects the server already running on port 8000):

```bash
python demo.py
```

It will:
- Fetch health
- Write sample logs
- Print a simple throughput measurement
- Print replication lag

---

## Docker (optional)

This project includes a simple container definition for the app and a Redis container (Redis is not required for the in-process simulation but is included to mirror real deployments).

```bash
docker compose up --build
```

Then open `http://localhost:8000`.

To stop:

```bash
docker compose down --remove-orphans
```

---

## Cleanup (safe)

To stop services and remove local runtime artifacts + prune unused Docker resources:

```bash
./cleanup.sh
```

Notes:
- `cleanup.sh` is conservative: it does **not** delete your `venv/` automatically.
- `.gitignore` is set up to prevent committing runtime artifacts (venv, caches, pid files, logs, data).

---

## Project structure (core components)

Key modules:

- **Models**: `src/models.py`
  - `LogEntry`, `VectorClock`, vector clock comparison helpers
- **Region manager**: `src/regions/region_manager.py`
  - Per-region storage and vector clocks
  - Enqueues replication “envelopes” to peers
- **Replication controller**: `src/replication/replication_controller.py`
  - Elects a primary
  - Routes writes through the primary
  - Performs in-process replication delivery to secondaries
- **Conflict resolver**: `src/conflict/conflict_resolver.py`
  - Vector-clock based causal ordering
  - Deterministic last-write-wins tie-break for concurrent updates
- **Health monitor**: `src/monitoring/health_monitor.py`
  - System health report and replication lag
- **Web app**: `src/web/app.py`
  - FastAPI routes + WebSocket updates
- **Dashboard UI**: `templates/dashboard.html`
  - Vue + Tailwind (CDN) client that polls `/api/status` and `/api/logs`

---

## Manual implementation walkthrough (how the pieces fit)

This section describes the design and how you would implement it from scratch.

### 1) Define your data model (`src/models.py`)

Implement:
- A `LogEntry` with:
  - `log_id`
  - `data` (your log payload)
  - `region` (origin region)
  - `created_at`
  - `vector_clock`
  - `logical_ts` (monotonic per region)
- A `vector_clock_compare(a, b)` helper returning:
  - `-1` if `a < b` (a happened before b)
  - `1` if `a > b`
  - `0` if equal
  - `None` if concurrent/incomparable

### 2) Region manager (`src/regions/region_manager.py`)

Responsibilities:
- Maintain a **vector clock** and **logical timestamp**
- Store logs by `log_id`
- Queue replication work to peers

Key operations:
- `write_log(data)`: increments the clock, stores a `LogEntry`, and enqueues replication envelopes
- `receive_replicated_log(entry_dict)`: merges vector clocks and upserts with conflict resolution

### 3) Conflict resolution (`src/conflict/conflict_resolver.py`)

Resolution policy:
- If vector clocks are comparable, the causally newer entry wins
- If concurrent, use deterministic last-write-wins on a stable tuple such as:
  - `(logical_ts, created_at, region, log_id)`

This ensures every node makes the same decision given the same candidates.

### 4) Replication controller (`src/replication/replication_controller.py`)

Responsibilities:
- Elect a primary (this project prefers `us-east` when present)
- Route writes through the primary
- Deliver replication to secondaries (in this project, done in-process for simplicity)
- Track observed replication lag (ms)

### 5) Health monitor (`src/monitoring/health_monitor.py`)

Provide:
- Overall `system_status`
- Cluster stats per region (log counts + primary flag)
- Replication lag summary

### 6) Web app + dashboard (`src/web/app.py`, `templates/dashboard.html`)

Implementation approach:
- Serve the dashboard HTML at `/` as **raw HTML** (not Jinja rendering), because Vue uses `{{ }}`.
- Provide REST endpoints (`/api/*`) that return exactly the JSON fields the dashboard expects.
- Push periodic updates over `/ws` so the UI can become realtime (or keep polling, both are fine).

---

## Safety notes

- **No API keys**: the project does not require or embed secrets.
- **Local only**: default examples bind to `127.0.0.1`. If you bind to `0.0.0.0`, treat it as development-only and ensure your environment/network is safe.
- **Production**: the dashboard uses CDN Tailwind/Vue builds. That’s acceptable for a learning project, but for production you would bundle assets and use production builds.

