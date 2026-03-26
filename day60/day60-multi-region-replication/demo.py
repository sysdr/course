#!/usr/bin/env python3
"""
Day 60: Multi-Region Log Replication Demo (single-process cluster).
"""

import asyncio
import time

import aiohttp


async def main() -> None:
    base = "http://localhost:8000"
    async with aiohttp.ClientSession() as session:
        print("🎬 Multi-Region Log Replication Demo")

        async with session.get(f"{base}/api/health") as r:
            health = await r.json()
        print(f"✅ System Status: {health.get('system_status')}")
        primary = health.get("cluster_stats", {}).get("primary_region")
        print(f"🏢 Primary Region: {primary}")

        regions = health.get("cluster_stats", {}).get("regions", {})
        print("🌍 Regions Status")
        for name, info in regions.items():
            crown = "👑" if info.get("is_primary") else "📍"
            print(f"🟢 {crown} {name.upper()}: {info.get('log_count', 0)} logs")

        print("✍️ Writing Test Logs")
        for i in range(10):
            payload = {"message": f"cart update {i}", "level": "info", "service": "demo"}
            async with session.post(f"{base}/api/logs", json=payload) as r:
                out = await r.json()
            print(f"✅ Log {i+1}: {out.get('log_id')}")

        print("🚀 Performance Test")
        n = 200
        t0 = time.perf_counter()
        for i in range(n):
            payload = {"message": f"perf {i}", "level": "info", "service": "perf"}
            async with session.post(f"{base}/api/logs", json=payload):
                pass
        t1 = time.perf_counter()
        throughput = n / max(1e-9, (t1 - t0))
        print(f"📊 Throughput: {throughput:.1f} logs/second")

        async with session.get(f"{base}/api/health") as r:
            health2 = await r.json()
        print("⏱️ Replication Lag (ms):")
        for region, lag in (health2.get("replication_lag_ms") or {}).items():
            print(f"   {region}: {lag:.2f}ms")


if __name__ == "__main__":
    asyncio.run(main())

