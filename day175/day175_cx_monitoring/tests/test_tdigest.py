"""Unit tests — TDigest percentile accuracy"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.metrics.tdigest import TDigest

def test_uniform_p50():
    td = TDigest()
    for v in range(1, 1001):
        td.add(float(v))
    p50 = td.percentile(50)
    assert abs(p50 - 500) < 30, f"p50={p50}"

def test_uniform_p99():
    td = TDigest()
    for v in range(1, 1001):
        td.add(float(v))
    p99 = td.percentile(99)
    assert abs(p99 - 990) < 30, f"p99={p99}"

def test_empty():
    td = TDigest()
    assert td.percentile(95) == 0.0

def test_single():
    td = TDigest()
    td.add(42.0)
    assert td.percentile(50) == 42.0

print("tdigest tests defined")
