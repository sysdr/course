"""Tests for journey_builder.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from journey_builder import build_journeys, get_top_paths

def _make_sessions(paths_per_sid):
    sessions = {}
    for i, pages in enumerate(paths_per_sid):
        sid = f"s{i+1:04d}"
        events = [{"timestamp": f"2025-01-15T10:{i:02d}:{j:02d}Z",
                   "user_id": "u001", "action": "page_view",
                   "page": p, "latency_ms": 50}
                  for j, p in enumerate(pages)]
        sessions[sid] = {"session_id": sid, "user_id": "u001",
                         "start_time": events[0]["timestamp"],
                         "end_time": events[-1]["timestamp"],
                         "events": events, "page_count": len(events)}
    return sessions

def test_deduplication():
    sessions = _make_sessions([["/home", "/home", "/products"]])
    journeys = build_journeys(sessions)
    assert journeys[0]["path"] == ["/home", "/products"]

def test_conversion_flag():
    sessions = _make_sessions([["/home", "/confirmation"]])
    journeys = build_journeys(sessions)
    assert journeys[0]["converted"] is True

def test_no_conversion():
    sessions = _make_sessions([["/home", "/products"]])
    journeys = build_journeys(sessions)
    assert journeys[0]["converted"] is False

def test_top_paths_ordering():
    sessions = _make_sessions([
        ["/home", "/products"],
        ["/home", "/products"],
        ["/home", "/cart"],
    ])
    journeys  = build_journeys(sessions)
    top_paths = get_top_paths(journeys)
    assert top_paths[0]["count"] == 2
