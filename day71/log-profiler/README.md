# Log Performance Profiler

Day 71 course project: a small FastAPI service that profiles log-processing workloads, exposes metrics over HTTP/WebSocket, and serves a browser dashboard.

---

## What you need

| Manual run | Docker run |
|------------|------------|
| Python **3.11+** (3.12 recommended) | **Docker Engine** + **Docker Compose** v2 (`docker compose`) |

---

## Clone from GitHub

```bash
git clone <YOUR_REPO_URL>
cd log-profiler
```

Do **not** commit `venv/`, logs, or caches—they are listed in [`.gitignore`](.gitignore). After clone, create a local virtualenv (manual path below).

---

## Manual execution (recommended for development)

### 1. Create a virtual environment

**Linux / macOS:**

```bash
python3 -m venv venv
source venv/bin/activate
```

**Windows (PowerShell):**

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Run the dashboard

From the `log-profiler` directory (repository root):

```bash
./start.sh
```

Or in the background:

```bash
./start.sh --background
```

Open **http://127.0.0.1:8000/** in your browser.

- **Foreground:** leave the terminal open; stop with `Ctrl+C`.
- **Background:** stop with `./stop.sh` (frees port `8000`).

`start.sh` sets `PYTHONPATH` to the project root so `config/` and `src/` imports resolve correctly.

### 4. Tests and demo

```bash
./build_and_test.sh
```

Runs `pytest` on `tests/` and the `demo.py` script.

### 5. Cleanup (local files + optional Docker)

```bash
./cleanup.sh
```

Stops the app on port 8000, runs Docker prune commands if Docker is installed, removes `venv/`, logs, pytest cache, and Python bytecode. Recreate the venv afterward if you need to run manually again:

```bash
python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
```

---

## Docker execution

All commands below assume your current directory is the **`log-profiler`** repository root (where `Dockerfile` and `docker-compose.yml` live).

### Option A — Docker Compose (app + Redis)

Build and start:

```bash
docker compose up --build
```

- Dashboard: **http://127.0.0.1:8000/**
- Redis is exposed on **6379** (included for future/extension use; the demo app does not require Redis to run).

Run detached:

```bash
docker compose up --build -d
```

Stop and remove containers:

```bash
docker compose down
```

### Option B — Image only (no Compose)

```bash
docker build -t log-profiler:local .
docker run --rm -p 8000:8000 \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/logs:/app/logs" \
  log-profiler:local
```

### Docker notes

- The image sets `PYTHONPATH=/app` and runs `python src/main.py`.
- Ensure port **8000** is free on the host before mapping `-p 8000:8000`.

---

## GitHub checklist

Before you push:

1. **Virtualenv** — never commit `venv/` (ignored).
2. **Secrets** — do not commit `.env` files with real keys; use `.env.example` if you add configuration later.
3. **Generated noise** — run `./cleanup.sh` or manually delete `logs/`, `.pytest_cache/`, `__pycache__/`, `.server.pid` if present.
4. **Branch** — push `main` (or your default branch) after `git add` / `git commit`.

```bash
git add .
git status   # confirm venv/ and caches are not staged
git commit -m "Add log-profiler implementation"
git push origin main
```

---

## Project layout (high level)

| Path | Purpose |
|------|---------|
| `src/main.py` | Uvicorn entrypoint |
| `src/dashboard/` | FastAPI app + WebSocket |
| `src/profiler/`, `src/optimizer/`, `src/analyzer/` | Profiling and log simulation |
| `config/` | Python configuration |
| `templates/` | Dashboard HTML |
| `tests/` | Pytest suite |
| `start.sh` / `stop.sh` | Manual run helpers |
| `cleanup.sh` | Stop services + prune Docker + remove local artifacts |
| `docker-compose.yml` / `Dockerfile` | Container deployment |

---

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| **Connection refused** in the browser | Start the app: `./start.sh` or Docker Compose. Nothing listens until the server runs. |
| **Port 8000 in use** | `./stop.sh` or change `PORT=8001 ./start.sh` (match your setup). |
| **Import errors** | Run from repo root; use `./start.sh` (sets `PYTHONPATH`). In Docker, use the provided `Dockerfile` / Compose. |
| **No `venv`** after cleanup | `python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt` |

---

## License

Add a `LICENSE` file in this repository if you need an explicit license for GitHub.
