from __future__ import annotations

import asyncio
from typing import Any, Dict, List, Optional

from src.models import utc_now
from src.regions.region_manager import RegionManager


class ReplicationController:
    """
    In-process controller used by tests and demos.
    It elects a primary among RegionManagers and routes writes through the primary.
    """

    def __init__(self, regions: Dict[str, RegionManager]):
        if not regions:
            raise ValueError("regions must be non-empty")
        self.regions = dict(regions)
        self.primary_region: Optional[str] = None
        self.replication_lag_ms: Dict[str, float] = {}
        self._lock = asyncio.Lock()

        self._elect_primary(initial=True)

    def _elect_primary(self, *, initial: bool = False) -> str:
        # Deterministic: prefer "us-east" when present (guide expectation),
        # otherwise fall back to smallest region name.
        candidate = "us-east" if "us-east" in self.regions else sorted(self.regions.keys())[0]
        self.primary_region = candidate
        for name, rm in self.regions.items():
            rm.is_primary = name == candidate
        return candidate

    async def write_log(self, data: Dict[str, Any]) -> str:
        async with self._lock:
            if self.primary_region is None or not self.regions.get(self.primary_region):
                self._elect_primary()

            primary = self.regions[self.primary_region]
            log_id = await primary.write_log(data)

            # Best-effort in-process replication: deliver queued entries immediately.
            await self._drain_all_replication_queues()
            return log_id

    async def _drain_all_replication_queues(self) -> None:
        # For the in-process model, we shortcut transport and directly call receive.
        for source in self.regions.values():
            while not source.replication_queue.empty():
                env = source.replication_queue.get_nowait()
                # peer is the region name for in-process mode
                target = self.regions.get(env.peer)
                if not target:
                    continue
                start = utc_now()
                await target.receive_replicated_log(env.log_entry.to_dict())
                end = utc_now()
                self.replication_lag_ms[target.region_name] = (end - start).total_seconds() * 1000.0

    async def failover_primary(self) -> str:
        async with self._lock:
            return await self._failover_primary()

    async def _failover_primary(self) -> str:
        # Simplified: pick the next region name in sorted order.
        names = sorted(self.regions.keys())
        if not names:
            raise RuntimeError("no regions available for failover")

        if self.primary_region not in names:
            new_primary = names[0]
        else:
            idx = names.index(self.primary_region)
            new_primary = names[(idx + 1) % len(names)]

        self.primary_region = new_primary
        for name, rm in self.regions.items():
            rm.is_primary = name == new_primary
        return new_primary

    def get_cluster_state(self) -> Dict[str, Any]:
        return {
            "primary_region": self.primary_region,
            "regions": {name: rm.get_stats() for name, rm in self.regions.items()},
            "replication_lag_ms": dict(self.replication_lag_ms),
        }

