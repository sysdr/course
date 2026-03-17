#!/usr/bin/env python3
"""Load test: send many write requests to the cluster (article: load_test.py)."""
import sys
import os
import argparse
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from config.cluster_config import DEFAULT_CONFIG


def write_one(port, request_id):
    try:
        r = requests.post(
            f"http://localhost:{port}/write",
            json={
                "message": f"Load test message {request_id}",
                "level": "info",
                "source": "load_test"
            },
            timeout=10
        )
        return r.status_code == 200 and r.json().get('success', False)
    except Exception:
        return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--requests', type=int, default=1000)
    parser.add_argument('--concurrent', type=int, default=10)
    parser.add_argument('--port', type=int, default=None, help='Primary node port (default: first in config)')
    args = parser.parse_args()

    port = args.port or DEFAULT_CONFIG['nodes'][0]['port']
    total = args.requests
    concurrency = args.concurrent

    print(f"Starting load test: {total} requests, {concurrency} concurrent")
    start = time.time()
    successful = 0
    failed = 0

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(write_one, port, i) for i in range(total)]
        done = 0
        for f in as_completed(futures):
            done += 1
            if (done % 50) == 0 or done == total:
                bar = int(20 * done / total)
                print(f"\rProgress: [{'#' * bar}{' ' * (20 - bar)}] {100 * done // total}% | {done}/{total} requests", end='')
            if f.result():
                successful += 1
            else:
                failed += 1

    elapsed = time.time() - start
    print("\n\nResults:")
    print(f"  Total requests: {total}")
    print(f"  Successful: {successful} ({100 * successful / total:.1f}%)")
    print(f"  Failed: {failed} ({100 * failed / total:.1f}%)")
    print(f"  Average response time: {1000 * elapsed / total:.1f}ms")


if __name__ == "__main__":
    main()
