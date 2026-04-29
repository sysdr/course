## User Journey Tracker (Day 170)

A small Flask + React (UMD) dashboard that analyzes synthetic e-commerce logs and visualizes user journeys:

- **Stats**: total sessions, conversion count/rate, average path length
- **Flow graph**: page-to-page transitions sized by volume
- **Top paths** and **recent sessions**

### Project layout

- `src/`: log generator + pipeline + Flask API (`api_server.py`)
- `static/`: dashboard UI (`index.html`) + UMD assets in `static/js/`
- `tests/`: pytest unit tests for parsing/building/analyzing
- `docker/`: Dockerfile + compose

### Run locally

```bash
cd day170-user-journey-tracking
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

export PORT=5170
export LOG_FILE=logs/app.log
python3 src/api_server.py
```

Open the dashboard at `http://localhost:5170/`.

### Regenerate demo data

```bash
curl -X POST http://localhost:5170/api/reload
```

### Run tests

```bash
source venv/bin/activate
python3 -m pytest -v
```

### Docker

```bash
cd docker
docker compose up --build
```
