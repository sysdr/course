import os
import json


def read_json_file(file_path):
    """Read JSON from file. Returns None if file does not exist or invalid JSON."""
    if not os.path.exists(file_path):
        return None
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None


def write_json_file(file_path, data):
    """Write data as JSON to file. Creates parent dirs if needed."""
    os.makedirs(os.path.dirname(os.path.abspath(file_path)) or '.', exist_ok=True)
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=2)


def ensure_dir(path):
    """Ensure directory exists."""
    os.makedirs(path, exist_ok=True)
