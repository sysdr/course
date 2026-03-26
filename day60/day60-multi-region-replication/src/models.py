from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple


VectorClock = Dict[str, int]


def utc_now() -> datetime:
    return datetime.now(tz=timezone.utc)


def vector_clock_compare(a: VectorClock, b: VectorClock) -> Optional[int]:
    """
    Compare two vector clocks.

    Returns:
      -1 if a < b, 1 if a > b, 0 if equal, None if concurrent/incomparable.
    """
    keys = set(a.keys()) | set(b.keys())
    a_le = True
    b_le = True
    a_lt = False
    b_lt = False

    for k in keys:
        av = a.get(k, 0)
        bv = b.get(k, 0)
        if av > bv:
            a_le = False
            b_lt = True
        elif av < bv:
            b_le = False
            a_lt = True

    if a_le and b_le:
        return 0
    if a_le and a_lt:
        return -1
    if b_le and b_lt:
        return 1
    return None


@dataclass(frozen=True)
class LogEntry:
    log_id: str
    data: Dict[str, Any]
    region: str
    created_at: datetime
    vector_clock: VectorClock
    logical_ts: int

    def to_dict(self) -> Dict[str, Any]:
        return {
            "log_id": self.log_id,
            "data": self.data,
            "region": self.region,
            "created_at": self.created_at.isoformat(),
            "vector_clock": dict(self.vector_clock),
            "logical_ts": self.logical_ts,
        }

    @staticmethod
    def from_dict(d: Dict[str, Any]) -> "LogEntry":
        created_at = d["created_at"]
        if isinstance(created_at, str):
            created_at_dt = datetime.fromisoformat(created_at)
        else:
            created_at_dt = created_at
        if created_at_dt.tzinfo is None:
            created_at_dt = created_at_dt.replace(tzinfo=timezone.utc)
        return LogEntry(
            log_id=d["log_id"],
            data=dict(d.get("data") or {}),
            region=d["region"],
            created_at=created_at_dt,
            vector_clock=dict(d.get("vector_clock") or {}),
            logical_ts=int(d.get("logical_ts") or 0),
        )


@dataclass(frozen=True)
class ConflictResult:
    winner: LogEntry
    losers: List[LogEntry]
    reason: str

