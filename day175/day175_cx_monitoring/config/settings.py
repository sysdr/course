# config/settings.py
import os

SESSION_IDLE_TIMEOUT   = int(os.getenv("SESSION_IDLE_TIMEOUT", "1800"))   # 30 min
METRICS_WINDOW_SEC     = int(os.getenv("METRICS_WINDOW_SEC", "300"))       # 5 min
REDIS_URL              = os.getenv("REDIS_URL", "redis://localhost:6379/0")
API_PORT               = int(os.getenv("API_PORT", "8175"))
SIMULATION_EVENTS      = int(os.getenv("SIMULATION_EVENTS", "10000"))
SLO_P95_MS             = float(os.getenv("SLO_P95_MS", "2000"))           # 2 s
SLO_ERROR_RATE         = float(os.getenv("SLO_ERROR_RATE", "0.005"))      # 0.5 %
SLO_COMPLETION_RATE    = float(os.getenv("SLO_COMPLETION_RATE", "0.30"))  # 30 %
