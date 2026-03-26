Distributed Logs (Week 2) - TCP + TLS Log Shipper

This mini project runs:
- A TCP server that accepts batches of gzipped JSON logs
- A load generator that simulates multiple workers shipping logs to the server

The default connection mode is TLS. The client must use the same TLS mode as the server.

---

Run the TCP server

1) TLS mode (default)

```bash
python3 src/tcp_server.py
```

Expected output:

```text
TCP Server listening on localhost:8888 (TLS: True)
```

2) No-TLS mode (plain TCP)

```bash
python3 src/tcp_server.py --no-tls
```

Expected output:

```text
TCP Server listening on localhost:8888 (TLS: False)
```

Keep this server running in one terminal.

---

Run the load generator

1) TLS mode (matches the default server)

```bash
python3 src/load_generator.py 500 10 5
```

Meaning:
- `500` = target RPS
- `10` = duration (seconds)
- `5` = number of workers

2) No-TLS mode (matches `--no-tls`)

```bash
python3 src/load_generator.py 500 10 5 --no-tls
```

---

How to verify it works

Server terminal:
- You should see `Client connected: (...)` lines
- Every ~5 seconds you should see increasing log metrics, for example:

```text
[STATS] Logs: <number>, Rate: ... logs/sec, Throughput: ... MB/sec
```

Client terminal:
- You should see `Worker X: Connected and ready`
- You should NOT repeatedly see:

```text
Failed to send batch: Connection lost
```

---

Troubleshooting: "Connection lost" and "Logs: 0"

If the server shows `TLS: True` but the client is sending plain TCP (or vice-versa),
the connection drops when the first real batch is sent.

Fix:
- If server is TLS, run the client without `--no-tls`
- If server is No-TLS (`--no-tls`), run the client with `--no-tls`
