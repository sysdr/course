"""Integration test — MetricsComputer full pipeline"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.aggregator.session import SessionAggregator
from src.metrics.computer import MetricsComputer
from src.ingestor.simulator import generate_events

def test_full_pipeline():
    agg  = SessionAggregator(idle_timeout=1800)
    comp = MetricsComputer(window_sec=300)
    count = 0
    for ev in generate_events(2000):
        sm = agg.ingest(ev)
        if sm:
            comp.consume(sm)
        count += 1
    for sm in agg.flush_all():
        comp.consume(sm)

    snap = comp.snapshot()
    assert snap.total_sessions > 0,            "No sessions in snapshot"
    assert 0 <= snap.error_rate <= 1,          "error_rate out of range"
    assert 0 <= snap.completion_rate <= 1,     "completion_rate out of range"
    assert snap.p95_ms >= snap.p50_ms,         "p95 < p50 — impossible"
    assert snap.p99_ms >= snap.p95_ms,         "p99 < p95 — impossible"
    print(f"  sessions={snap.total_sessions} "
          f"conv={snap.converted} "
          f"p50={snap.p50_ms:.0f}ms "
          f"p95={snap.p95_ms:.0f}ms "
          f"err={snap.error_rate:.3f} "
          f"completion={snap.completion_rate:.3f}")

print("metrics integration test defined")
