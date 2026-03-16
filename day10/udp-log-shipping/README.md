# UDP Log Shipping System

A simple UDP-based log shipping system: a client sends JSON log entries over UDP, and a server receives them, batches writes, and appends them to a daily log file.

## Features

- **Client**: Sends log messages (with sequence numbers for loss detection) to a configurable host/port.
- **Server**: Listens for UDP logs, buffers them, and flushes to disk when the buffer is full (100 logs) or after 5 seconds to reduce disk I/O.

## Requirements

- Python 3.6+

## Usage

### Start the server

```bash
cd udp-log-shipping
python3 -m src.server.udp_server --host 0.0.0.0 --port 9999
```

- `--host`: Bind address (default: `0.0.0.0`)
- `--port`: Port to listen on (default: `9999`)

Logs are written under `logs/` as `udp_logs_YYYY-MM-DD.log`. If that path is not writable, the server falls back to a file in the system temp directory.

### Send logs from the client

```bash
python3 -m src.client.udp_client --server 127.0.0.1 --port 9999 --app my-app --count 100 --interval 0.001
```

- `--server`: Server host (default: `127.0.0.1`)
- `--port`: Server port (default: `9999`)
- `--app`: Application name (default: `test-app`)
- `--count`: Number of logs to send (default: `1000`)
- `--interval`: Delay between logs in seconds (default: `0.001`)

### Run tests

```bash
python3 -m src.tests.test_udp_logging
```

Tests start a server in a background thread on port 9998 and run: log sending, high volume, packet loss detection (sequence numbers), server restart scenario, and performance.

## Project layout

```
udp-log-shipping/
├── src/
│   ├── server/
│   │   └── udp_server.py   # UDP log collector with buffered writes
│   ├── client/
│   │   └── udp_client.py   # UDP log sender with sequence numbers
│   └── tests/
│       └── test_udp_logging.py
├── logs/                    # Daily log files (created at runtime)
└── README.md
```

## Notes

- UDP is unreliable: packets can be lost or reordered. The client adds a `sequence` field so the server (or downstream tools) can detect gaps.
- If you see "Address already in use", another process is using the port. Stop it or use a different `--port`.
