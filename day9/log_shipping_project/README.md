# Log Shipping Project - Complete Implementation

This project contains both the basic log shipping implementation and the advanced assignment solution.

## Project Structure
```
log_shipping_project/
├── main_project/          # Basic log shipping client
│   ├── src/               # Log reader, shipper, main entry point
│   ├── server.py          # TCP log server
│   ├── logs/              # Log files (when using Docker volume)
│   └── tests/
└── assignment/            # Enhanced log shipping client with advanced features
    ├── src/               # Resilient shipper, enhanced shipper, main entry points
    ├── enhanced_server.py # Server supporting compression & heartbeat
    ├── logs/              # Log files (when using Docker volume)
    └── tests/
```

## Prerequisites

- **Python 3.10+** (for local runs). On Linux use `python3`; a virtual environment is recommended (see below).
- **Docker & Docker Compose** (optional, for containerized runs).

---

## Local setup (virtual environment)

On many systems (e.g. Debian/Ubuntu) Python is externally managed, so install dependencies inside a venv:

```bash
cd log_shipping_project/main_project   # or assignment
python3 -m venv .venv
source .venv/bin/activate               # Linux/macOS; on Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Use the same venv for both server and client (two terminals): activate it in each, then run the commands below. All `python` / `pip` in this guide mean the venv’s `python` and `pip` after activation.

---

## Implementation Guide

### Running main_project

The main project provides a basic log shipping client and TCP server.

#### Option A: Run locally (two terminals)

Create and activate a venv in `main_project` (see **Local setup** above), then:

**Terminal 1 – start the server**
```bash
cd main_project
# (activate venv if not already: source .venv/bin/activate)
pip install -r requirements.txt
python server.py --port 9000
```

**Terminal 2 – run the client**
```bash
cd main_project
# (activate venv: source .venv/bin/activate)
# Continuous mode (tail-style, watches for new lines)
python -m src.main --log-file sample_logs.txt --server-host localhost --server-port 9000

# Batch mode (send existing file once and exit)
python -m src.main --log-file sample_logs.txt --server-host localhost --server-port 9000 --batch
```

#### Option B: Run with Docker Compose

```bash
cd main_project
docker-compose up --build
```

This starts the log server and client in containers. The server listens on **port 9000**. Logs from `./logs` are shipped to the server. Use `docker-compose logs -f` to follow output.

**Stop:** `docker-compose down`

#### Run tests (main_project)

```bash
cd main_project
# (activate venv first)
pytest tests/ -v
pytest --cov=src tests/   # with coverage
```

---

### Running assignment

The assignment adds resilience, compression, batching, and metrics.

#### Option A: Run locally (two terminals)

Create and activate a venv in `assignment` (see **Local setup** above), then:

**Terminal 1 – start the enhanced server**
```bash
cd assignment
# (activate venv if not already: source .venv/bin/activate)
pip install -r requirements.txt
python enhanced_server.py --port 9000
```

**Terminal 2 – run the client**

Resilient client (buffering, persistence, backoff):
```bash
cd assignment
# (activate venv: source .venv/bin/activate)
python -m src.resilient_main --log-file sample_logs.txt --server-host localhost --server-port 9000
```

Enhanced client (compression, batching, metrics):
```bash
cd assignment
# (activate venv: source .venv/bin/activate)
python -m src.enhanced_main --log-file sample_logs.txt --server-host localhost --server-port 9000 --compress --batch-size 5 --metrics-interval 10
```

Use `--no-compress` to disable compression, or `--batch` to send once and exit.

#### Option B: Run with Docker Compose

```bash
cd assignment
docker-compose up --build
```

This starts the enhanced server and enhanced client in containers. Server is on **port 9000**. Use `docker-compose logs -f` to follow output.

**Stop:** `docker-compose down`

#### Run tests (assignment)

```bash
cd assignment
# (activate venv first)
pytest tests/ -v
```

#### Testing resilience (assignment)

1. Start the server and client (local or Docker).
2. Stop the server to trigger client buffering.
3. Append lines to the log file while the server is down.
4. Restart the server and watch the client reconnect and drain the buffer.

---

## Learning Path

1. **Main Project** – core concepts
   - Log reading (batch and incremental)
   - TCP communication
   - Basic error handling
   - Testing fundamentals

2. **Assignment** – production-style features
   - Resilience (buffering, persistence, backoff)
   - Compression and batching
   - Metrics and heartbeat
   - Advanced testing

---

## Quick reference

| Goal                    | main_project                    | assignment                          |
|-------------------------|----------------------------------|-------------------------------------|
| Server (local)          | `python server.py --port 9000`   | `python enhanced_server.py --port 9000` |
| Client continuous       | `python -m src.main --log-file sample_logs.txt --server-host localhost --server-port 9000` | `python -m src.enhanced_main --log-file sample_logs.txt --server-host localhost --server-port 9000 --compress` |
| Client batch            | add `--batch`                    | add `--batch`                        |
| Docker                  | `cd main_project && docker-compose up` | `cd assignment && docker-compose up` |
| Tests                   | `pytest tests/ -v`               | `pytest tests/ -v`                   |
