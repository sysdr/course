"""
MetricsComputer — consumes SessionSummary objects and produces CX metrics.
Maintains a rolling 5-min window via deque of timestamped snapshots.
"""
import time
from collections import deque
from dataclasses import dataclass, field
from typing import Deque

from src.metrics.tdigest import TDigest
from src.aggregator.session import SessionSummary

FUNNEL_LABELS = {0: "browsing", 1: "cart", 2: "checkout", 3: "converted"}

@dataclass
class CXSnapshot:
    timestamp            : float = field(default_factory=time.time)
    total_sessions       : int   = 0
    converted            : int   = 0
    abandoned            : int   = 0
    error_sessions       : int   = 0
    abandonment_by_stage : dict  = field(default_factory=dict)
    p50_ms               : float = 0.0
    p90_ms               : float = 0.0
    p95_ms               : float = 0.0
    p99_ms               : float = 0.0
    error_rate           : float = 0.0
    completion_rate      : float = 0.0
    avg_session_sec      : float = 0.0

class MetricsComputer:
    def __init__(self, window_sec: int = 300):
        self._window    = window_sec
        self._tdigest   = TDigest(compression=200)
        self._summaries : Deque[tuple[float, SessionSummary]] = deque()
        # Abandonment only applies to non-converted sessions (exclude "converted" stage).
        self._abandon_stage : dict[str, int] = {
            FUNNEL_LABELS[0]: 0, FUNNEL_LABELS[1]: 0, FUNNEL_LABELS[2]: 0,
        }

    def consume(self, summary: SessionSummary):
        now = time.time()
        self._summaries.append((now, summary))
        for lat in summary.latencies_ms:
            self._tdigest.add(lat)
        self._evict(now)
        if not summary.converted:
            label = FUNNEL_LABELS.get(summary.max_funnel_stage, "browsing")
            self._abandon_stage[label] = self._abandon_stage.get(label, 0) + 1

    def _evict(self, now: float):
        cutoff = now - self._window
        while self._summaries and self._summaries[0][0] < cutoff:
            self._summaries.popleft()

    def snapshot(self) -> CXSnapshot:
        now = time.time()
        self._evict(now)
        slist = [s for _, s in self._summaries]
        total = len(slist)
        if total == 0:
            return CXSnapshot()
        converted    = sum(1 for s in slist if s.converted)
        error_sess   = sum(1 for s in slist if s.error_count > 0)
        abandoned    = total - converted
        avg_dur      = sum(s.duration_sec for s in slist) / total
        snap = CXSnapshot(
            timestamp            = now,
            total_sessions       = total,
            converted            = converted,
            abandoned            = abandoned,
            error_sessions       = error_sess,
            abandonment_by_stage = dict(self._abandon_stage),
            p50_ms               = round(self._tdigest.percentile(50), 2),
            p90_ms               = round(self._tdigest.percentile(90), 2),
            p95_ms               = round(self._tdigest.percentile(95), 2),
            p99_ms               = round(self._tdigest.percentile(99), 2),
            error_rate           = round(error_sess / total, 4) if total else 0,
            completion_rate      = round(converted / total, 4)  if total else 0,
            avg_session_sec      = round(avg_dur, 2),
        )
        return snap
