import requests
import threading
import time
from datetime import datetime


class HealthChecker:
    """Node health monitoring."""

    def __init__(self, nodes, interval_seconds=30, host='localhost'):
        self.nodes = nodes
        self.interval = interval_seconds
        self.host = host
        self._running = False
        self._thread = None

    def start(self):
        """Start health check loop in background thread."""
        self._running = True
        self._thread = threading.Thread(target=self._check_loop, daemon=True)
        self._thread.start()

    def stop(self):
        """Stop health check loop."""
        self._running = False
        if self._thread:
            self._thread.join(timeout=self.interval * 2)

    def _check_loop(self):
        """Periodically check health of all nodes."""
        while self._running:
            for node_id, node in self.nodes.items():
                try:
                    port = getattr(node, 'port', None)
                    if port is None:
                        continue
                    response = requests.get(
                        f"http://{self.host}:{port}/health",
                        timeout=5
                    )
                    if response.status_code == 200:
                        node.is_healthy = True
                    else:
                        node.is_healthy = False
                except Exception:
                    node.is_healthy = False
            time.sleep(self.interval)

    def check_once(self):
        """Run one round of health checks."""
        for node_id, node in self.nodes.items():
            try:
                port = getattr(node, 'port', None)
                if port is None:
                    continue
                response = requests.get(
                    f"http://{self.host}:{port}/health",
                    timeout=5
                )
                node.is_healthy = (response.status_code == 200)
            except Exception:
                node.is_healthy = False
