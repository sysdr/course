from __future__ import annotations

import asyncio
import queue
import uuid
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Awaitable, Callable, Dict, List, Optional, Tuple

from src.conflict.conflict_resolver import ConflictResolver
from src.models import LogEntry, VectorClock, utc_now


@dataclass(frozen=True)
class ReplicationEnvelope:
    peer: str
    log_entry: LogEntry


class RegionManager:
    """
    Per-region state machine:
    - maintains a vector clock and logical timestamp
    - stores log entries by log_id
    - produces replication envelopes for peers (transport is injected)
    """

    def __init__(self, region_name: str, port: int, peers: List[str]):
        self.region_name = region_name
        self.port = port
        self.peers = list(peers)

        self.is_primary: bool = False
        self.log_store: Dict[str, LogEntry] = {}
        self.vector_clock: VectorClock = {region_name: 0}
        self.logical_ts: int = 0

        self.replication_queue: "queue.Queue[ReplicationEnvelope]" = queue.Queue()
        self._resolver = ConflictResolver()

        # Replication lag tracking: peer -> last observed lag seconds
        self.replication_lag_s: Dict[str, float] = {}

    def _tick(self) -> Tuple[VectorClock, int]:
        self.vector_clock[self.region_name] = self.vector_clock.get(self.region_name, 0) + 1
        self.logical_ts += 1
        return dict(self.vector_clock), self.logical_ts

    async def write_log(self, data: Dict[str, Any], *, log_id: Optional[str] = None) -> str:
        vc, lts = self._tick()
        created = utc_now()
        new_id = log_id or str(uuid.uuid4())

        entry = LogEntry(
            log_id=new_id,
            data=dict(data),
            region=self.region_name,
            created_at=created,
            vector_clock=vc,
            logical_ts=lts,
        )
        self._upsert_entry(entry)

        for peer in self.peers:
            self.replication_queue.put(ReplicationEnvelope(peer=peer, log_entry=entry))

        return new_id

    def _upsert_entry(self, incoming: LogEntry) -> None:
        existing = self.log_store.get(incoming.log_id)
        if existing is None:
            self.log_store[incoming.log_id] = incoming
            return

        result = self._resolver.resolve_conflict([existing, incoming])
        self.log_store[incoming.log_id] = result.winner

    async def receive_replicated_log(self, log_entry_dict: Dict[str, Any]) -> None:
        incoming = LogEntry.from_dict(log_entry_dict)

        # Merge vector clocks (max per key)
        for k, v in incoming.vector_clock.items():
            self.vector_clock[k] = max(self.vector_clock.get(k, 0), int(v))

        # Move our logical clock forward to preserve monotonicity
        self.logical_ts = max(self.logical_ts, incoming.logical_ts)

        self._upsert_entry(incoming)

    async def replication_worker(
        self,
        send_to_peer: Callable[[str, Dict[str, Any]], Awaitable[None]],
        *,
        stop_event: asyncio.Event,
        poll_interval_s: float = 0.05,
    ) -> None:
        """
        Drain replication_queue and send to peers using injected transport.
        Designed to run as a background task.
        """
        while not stop_event.is_set():
            try:
                env = self.replication_queue.get_nowait()
            except queue.Empty:
                await asyncio.sleep(poll_interval_s)
                continue

            start = utc_now()
            try:
                await send_to_peer(env.peer, env.log_entry.to_dict())
            finally:
                end = utc_now()
                lag_s = max(0.0, (end - start).total_seconds())
                self.replication_lag_s[env.peer] = lag_s

    def get_stats(self) -> Dict[str, Any]:
        return {
            "region": self.region_name,
            "port": self.port,
            "is_primary": self.is_primary,
            "log_count": len(self.log_store),
            "vector_clock": dict(self.vector_clock),
            "logical_ts": self.logical_ts,
            "replication_queue_depth": self.replication_queue.qsize(),
            "replication_lag_s": dict(self.replication_lag_s),
        }

