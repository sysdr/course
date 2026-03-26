import time

import asyncio

from src.regions.region_manager import RegionManager
from src.replication.replication_controller import ReplicationController


def test_throughput():
    regions = {
        "us-east": RegionManager("us-east", 0, peers=["europe", "asia"]),
        "europe": RegionManager("europe", 0, peers=["us-east", "asia"]),
        "asia": RegionManager("asia", 0, peers=["us-east", "europe"]),
    }
    controller = ReplicationController(regions)

    async def run_many(n: int) -> None:
        for i in range(n):
            await controller.write_log({"message": f"m{i}", "level": "info"})

    n = 200
    start = time.perf_counter()
    asyncio.run(run_many(n))
    end = time.perf_counter()
    throughput = n / max(1e-9, end - start)
    assert throughput > 10.0


def test_replication_latency():
    regions = {
        "us-east": RegionManager("us-east", 0, peers=["europe", "asia"]),
        "europe": RegionManager("europe", 0, peers=["us-east", "asia"]),
        "asia": RegionManager("asia", 0, peers=["us-east", "europe"]),
    }
    controller = ReplicationController(regions)
    asyncio.run(controller.write_log({"message": "latency", "level": "info"}))
    # In-process replication should be effectively immediate
    lag_ms = max(controller.replication_lag_ms.values() or [0.0])
    assert lag_ms < 1000.0

