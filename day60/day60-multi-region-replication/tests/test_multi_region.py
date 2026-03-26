import asyncio

from src.conflict.conflict_resolver import ConflictResolver
from src.regions.region_manager import RegionManager
from src.replication.replication_controller import ReplicationController


def test_region_creation():
    regions = {
        "us-east": RegionManager("us-east", 0, peers=["europe", "asia"]),
        "europe": RegionManager("europe", 0, peers=["us-east", "asia"]),
        "asia": RegionManager("asia", 0, peers=["us-east", "europe"]),
    }
    assert set(regions.keys()) == {"us-east", "europe", "asia"}
    for rm in regions.values():
        assert rm.log_store == {}
        assert rm.vector_clock[rm.region_name] == 0


def test_replication_controller_write():
    regions = {
        "us-east": RegionManager("us-east", 0, peers=["europe", "asia"]),
        "europe": RegionManager("europe", 0, peers=["us-east", "asia"]),
        "asia": RegionManager("asia", 0, peers=["us-east", "europe"]),
    }
    controller = ReplicationController(regions)
    log_id = asyncio.run(controller.write_log({"message": "hello", "level": "info"}))
    assert isinstance(log_id, str)
    # replicated to all regions in-process
    assert log_id in controller.regions["us-east"].log_store
    assert log_id in controller.regions["europe"].log_store
    assert log_id in controller.regions["asia"].log_store


def test_conflict_resolution_lww_concurrent():
    resolver = ConflictResolver()
    rm = RegionManager("us-east", 0, peers=[])

    # Construct concurrent entries with same log_id
    # We bypass rm.write_log to force concurrency and same id
    from datetime import datetime, timezone, timedelta
    from src.models import LogEntry

    base = datetime(2026, 1, 1, tzinfo=timezone.utc)
    e1 = LogEntry(
        log_id="same",
        data={"v": 1},
        region="us-east",
        created_at=base,
        vector_clock={"us-east": 1},
        logical_ts=1,
    )
    e2 = LogEntry(
        log_id="same",
        data={"v": 2},
        region="europe",
        created_at=base + timedelta(milliseconds=1),
        vector_clock={"europe": 1},
        logical_ts=1,
    )
    res = resolver.resolve_conflict([e1, e2])
    assert res.winner.data["v"] == 2

