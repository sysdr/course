#!/usr/bin/env python3
"""
Flask REST API — User Journey Tracking
Serves the React dashboard and exposes flow analysis endpoints.
"""
import os
import sys

# Allow imports from src/ when run from project root
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

from log_generator     import generate_logs
from session_extractor import extract_sessions
from journey_builder   import build_journeys, get_top_paths
from flow_analyzer     import analyze_flow

LOG_FILE    = os.environ.get("LOG_FILE", "logs/app.log")
STATIC_DIR  = os.path.join(os.path.dirname(__file__), "..", "static")
app         = Flask(__name__, static_folder=STATIC_DIR, static_url_path="/static")
CORS(app)

def _pipeline():
    if not os.path.exists(LOG_FILE):
        generate_logs(output_file=LOG_FILE)
    sessions = extract_sessions(LOG_FILE)
    journeys = build_journeys(sessions)
    return sessions, journeys

# ── Routes ───────────────────────────────────────────────────────────────────
@app.route("/")
def index():
    return send_from_directory(app.static_folder, "index.html")

@app.route("/api/stats")
def stats():
    _, journeys = _pipeline()
    flow = analyze_flow(journeys)
    return jsonify({
        "total_sessions":     flow["total_sessions"],
        "conversion_rate":    flow["conversion_rate"],
        "avg_path_length":    flow["avg_path_length"],
        "converted_sessions": flow["converted_sessions"],
    })

@app.route("/api/flow")
def flow():
    _, journeys = _pipeline()
    data = analyze_flow(journeys)
    return jsonify({
        "nodes":        data["nodes"],
        "edges":        data["edges"],
        "entry_points": data["entry_points"],
        "exit_points":  data["exit_points"],
    })

@app.route("/api/journeys")
def top_journeys():
    _, journeys = _pipeline()
    return jsonify(get_top_paths(journeys, top_n=12))

@app.route("/api/sessions")
def sessions():
    _, journeys = _pipeline()
    recent = sorted(journeys, key=lambda j: j["start_time"], reverse=True)[:20]
    return jsonify(recent)

@app.route("/api/reload", methods=["POST"])
def reload_logs():
    generate_logs(num_sessions=80, output_file=LOG_FILE)
    return jsonify({"status": "ok", "message": "Logs regenerated — refresh your view"})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5170))
    print(f"Starting User Journey API  →  http://localhost:{port}")
    app.run(host="0.0.0.0", port=port, debug=False)
