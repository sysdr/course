"""Tests for session_extractor.py"""
import os, sys, tempfile, pytest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from session_extractor import extract_sessions

SAMPLE = """\
2025-01-15T10:00:01Z user_id=u001 session_id=s0001 action=page_view page=/home latency_ms=45
2025-01-15T10:00:10Z user_id=u001 session_id=s0001 action=page_view page=/products latency_ms=80
2025-01-15T10:00:05Z user_id=u002 session_id=s0002 action=page_view page=/home latency_ms=30
2025-01-15T10:00:20Z user_id=u002 session_id=s0002 action=add_to_cart page=/cart latency_ms=55
BADLINE IGNORED
"""

def _tmp_log(content):
    f = tempfile.NamedTemporaryFile(mode="w", suffix=".log", delete=False)
    f.write(content); f.close()
    return f.name

def test_parse_valid_line():
    path = _tmp_log(SAMPLE)
    sessions = extract_sessions(path)
    os.unlink(path)
    assert "s0001" in sessions
    assert "s0002" in sessions

def test_session_grouping():
    path = _tmp_log(SAMPLE)
    sessions = extract_sessions(path)
    os.unlink(path)
    assert sessions["s0001"]["page_count"] == 2
    assert sessions["s0002"]["user_id"] == "u002"

def test_events_sorted_by_timestamp():
    path = _tmp_log(SAMPLE)
    sessions = extract_sessions(path)
    os.unlink(path)
    events = sessions["s0001"]["events"]
    timestamps = [e["timestamp"] for e in events]
    assert timestamps == sorted(timestamps)

def test_bad_lines_skipped():
    path = _tmp_log(SAMPLE)
    sessions = extract_sessions(path)
    os.unlink(path)
    assert len(sessions) == 2   # bad line must be ignored
