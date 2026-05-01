"""Unit tests — SessionAggregator"""
import time
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.aggregator.session import SessionAggregator

def _ev(uid, sid, event="page_view", status=200, lat=150.0):
    return {"user_id": uid, "session_id": sid, "event_type": event,
            "latency_ms": lat, "status_code": status,
            "timestamp": "2025-01-01T00:00:00Z"}

def test_purchase_closes_session():
    agg = SessionAggregator(idle_timeout=1800)
    agg.ingest(_ev("u1","s1","page_view"))
    agg.ingest(_ev("u1","s1","add_to_cart"))
    summary = agg.ingest(_ev("u1","s1","purchase"))
    assert summary is not None
    assert summary.converted is True
    assert summary.max_funnel_stage == 3

def test_error_counted():
    agg = SessionAggregator(idle_timeout=1800)
    agg.ingest(_ev("u2","s2","page_view", status=200))
    agg.ingest(_ev("u2","s2","page_view", status=500))
    summaries = agg.flush_all()
    assert any(s.error_count > 0 for s in summaries)

def test_multiple_users():
    agg = SessionAggregator(idle_timeout=1800)
    for i in range(5):
        agg.ingest(_ev(f"u{i}", f"s{i}", "page_view"))
    sums = agg.flush_all()
    assert len(sums) == 5

def test_new_session_closes_old():
    agg = SessionAggregator(idle_timeout=1800)
    agg.ingest(_ev("u3","s3a","page_view"))
    summary = agg.ingest(_ev("u3","s3b","page_view"))  # new session_id
    assert summary is not None
    assert summary.session_id == "s3a"

print("session tests defined")
