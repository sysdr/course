"""Inter-node communication utilities."""

import requests


def get_node_health(host, port, timeout=5):
    """GET /health for a node. Returns dict or None on failure."""
    try:
        r = requests.get(f"http://{host}:{port}/health", timeout=timeout)
        if r.status_code == 200:
            return r.json()
    except Exception:
        pass
    return None


def post_replicate(host, port, file_path, data, timeout=10):
    """POST /replicate to a node. Returns True on success."""
    try:
        r = requests.post(
            f"http://{host}:{port}/replicate",
            json={'file_path': file_path, 'data': data},
            timeout=timeout
        )
        return r.status_code == 200 and r.json().get('success', False)
    except Exception:
        return False


def post_write(host, port, log_data, timeout=10):
    """POST /write to a node. Returns response dict or None."""
    try:
        r = requests.post(
            f"http://{host}:{port}/write",
            json=log_data,
            timeout=timeout
        )
        if r.status_code == 200:
            return r.json()
    except Exception:
        pass
    return None


def get_read(host, port, file_path, timeout=10):
    """GET /read/<file_path> from a node. Returns response dict or None."""
    try:
        r = requests.get(
            f"http://{host}:{port}/read/{file_path}",
            timeout=timeout
        )
        if r.status_code == 200:
            return r.json()
    except Exception:
        pass
    return None
