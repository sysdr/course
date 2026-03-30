#!/bin/bash
PORT="${PORT:-8000}"
if command -v fuser >/dev/null 2>&1; then
  if fuser "${PORT}/tcp" 2>/dev/null | grep -q .; then
    fuser -k "${PORT}/tcp" 2>/dev/null || true
    echo "Stopped process(es) on port ${PORT}."
  else
    echo "No process listening on port ${PORT}."
  fi
  exit 0
fi
if command -v lsof >/dev/null 2>&1; then
  mapfile -t PIDS < <(lsof -ti ":${PORT}" 2>/dev/null || true)
  if [[ ${#PIDS[@]} -eq 0 ]]; then
    echo "No process listening on port ${PORT}."
    exit 0
  fi
  kill "${PIDS[@]}" 2>/dev/null || true
  echo "Stopped process(es) on port ${PORT}."
  exit 0
fi
echo "ERROR: Install psmisc (fuser) or lsof to stop the server." >&2
exit 1
