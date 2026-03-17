#!/usr/bin/env python3
"""Performance benchmark: single-threaded and multi-threaded (article: benchmark_test.py)."""
import sys
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from config.cluster_config import DEFAULT_CONFIG


def do_write(port, i):
    start = time.time()
    try:
        r = requests.post(
            f"http://localhost:{port}/write",
            json={"message": f"Benchmark {i}", "level": "info"},
            timeout=10
        )
        elapsed = time.time() - start
        return elapsed if r.status_code == 200 else None
    except Exception:
        return None


def main():
    port = DEFAULT_CONFIG['nodes'][0]['port']

    print("Single-threaded benchmark (100 requests)...")
    times = []
    for i in range(100):
        t = do_write(port, i)
        if t is not None:
            times.append(t)
    if times:
        times.sort()
        avg = sum(times) / len(times)
        print(f"Average: {avg:.3f}s")
        print(f"Min: {min(times):.3f}s")
        print(f"Max: {max(times):.3f}s")
        p95 = times[int(len(times) * 0.95)] if len(times) > 1 else times[0]
        print(f"95th percentile: {p95:.3f}s")
    else:
        print("No successful requests")

    print("\nMulti-threaded benchmark (10 threads x 20 requests)...")
    start = time.time()
    with ThreadPoolExecutor(max_workers=10) as ex:
        futures = [ex.submit(do_write, port, i) for i in range(200)]
        results = [f.result() for f in as_completed(futures)]
    total_time = time.time() - start
    ok = [t for t in results if t is not None]
    print(f"Total time: {total_time:.3f}s")
    print(f"Requests per second: {len(ok) / total_time:.1f}")
    print(f"Average request time: {sum(ok) / len(ok):.3f}s" if ok else "N/A")


if __name__ == "__main__":
    main()
