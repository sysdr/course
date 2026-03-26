from __future__ import annotations

from typing import Any, Dict, Optional

from src.replication.replication_controller import ReplicationController


class HealthMonitor:
    def __init__(self, controller: ReplicationController):
        self.controller = controller

    def get_system_health(self) -> Dict[str, Any]:
        state = self.controller.get_cluster_state()
        primary = state.get("primary_region")
        regions = state.get("regions", {})

        unhealthy = [
            name
            for name, stats in regions.items()
            if stats.get("log_count") is None  # placeholder for real checks
        ]

        status = "healthy" if not unhealthy and primary else "degraded"
        return {
            "system_status": status,
            "cluster_stats": {
                "primary_region": primary,
                "regions": {
                    name: {
                        "health_status": "healthy",
                        "is_primary": bool(stats.get("is_primary")),
                        "log_count": int(stats.get("log_count", 0)),
                    }
                    for name, stats in regions.items()
                },
            },
            "replication_lag_ms": state.get("replication_lag_ms", {}),
        }

