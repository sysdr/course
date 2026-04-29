"""Tests for flow_analyzer.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from flow_analyzer import analyze_flow

def _j(path):
    return {
        "session_id": "s0001", "user_id": "u001",
        "path": path,
        "path_str": " → ".join(path),
        "steps": len(path),
        "avg_latency_ms": 50.0,
        "converted": path[-1] == "/confirmation",
        "start_time": "2025-01-15T10:00:00Z",
    }

def test_edge_counts():
    journeys = [_j(["/home", "/products", "/cart"])] * 3
    flow = analyze_flow(journeys)
    edge_map = {(e["source"], e["target"]): e["count"] for e in flow["edges"]}
    assert edge_map[("/home", "/products")] == 3
    assert edge_map[("/products", "/cart")] == 3

def test_conversion_rate():
    journeys = [_j(["/home", "/confirmation"])] * 2 + [_j(["/home", "/products"])] * 8
    flow = analyze_flow(journeys)
    assert flow["conversion_rate"] == 20.0
    assert flow["converted_sessions"] == 2

def test_entry_exit_points():
    journeys = [_j(["/home", "/products"]), _j(["/home", "/cart"])]
    flow = analyze_flow(journeys)
    assert flow["entry_points"].get("/home") == 2
    assert "/products" in flow["exit_points"]
