from __future__ import annotations

from typing import List

from src.models import ConflictResult, LogEntry, vector_clock_compare


class ConflictResolver:
    """
    Deterministic resolution:
    - If vector clocks are comparable, pick the causally-later entry.
    - If concurrent, use Last-Write-Wins on (logical_ts, created_at, region, log_id).
    """

    def resolve_conflict(self, entries: List[LogEntry]) -> ConflictResult:
        if not entries:
            raise ValueError("entries must be non-empty")
        if len(entries) == 1:
            return ConflictResult(winner=entries[0], losers=[], reason="single_entry")

        winner = entries[0]
        losers: List[LogEntry] = []

        for e in entries[1:]:
            cmp = vector_clock_compare(winner.vector_clock, e.vector_clock)
            if cmp == -1:
                losers.append(winner)
                winner = e
            elif cmp == 1:
                losers.append(e)
            elif cmp == 0:
                losers.append(e)
            else:
                # concurrent - fall back to stable LWW
                if self._lww_key(e) > self._lww_key(winner):
                    losers.append(winner)
                    winner = e
                else:
                    losers.append(e)

        # Remove accidental duplicates from losers while preserving order
        seen = set()
        uniq_losers: List[LogEntry] = []
        for l in losers:
            if l.log_id in seen and l is winner:
                continue
            ident = (l.log_id, l.region, l.logical_ts, l.created_at)
            if ident in seen:
                continue
            seen.add(ident)
            uniq_losers.append(l)

        return ConflictResult(winner=winner, losers=uniq_losers, reason="vector_clock_then_lww")

    def _lww_key(self, e: LogEntry):
        # logical_ts is monotonic per-region; created_at provides wall-clock tie-break.
        return (e.logical_ts, e.created_at, e.region, e.log_id)

