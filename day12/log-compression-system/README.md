# Log Compression System

This project implements a log compression system for reducing network bandwidth usage in distributed logging.

## Features

- Configurable compression algorithms (gzip, zlib)
- Adjustable compression levels (1-9)
- Batched log shipping
- Performance metrics
- Docker support

## Getting Started

### Local Setup

1. Build the project:
   ```
   ./scripts/build.sh
   ```

2. Run tests:
   ```
   ./scripts/run_tests.sh
   ```

3. Start the server:
   ```
   ./scripts/run_server.sh
   ```

4. In another terminal, start the client:
   ```
   ./scripts/run_client.sh
   ```

### Docker Setup

1. Run with Docker Compose:
   ```
   cd docker
   docker-compose up --build
   ```

## Configuration

The log shipper and receiver can be configured with various options:

- Compression algorithm: gzip or zlib
- Compression level: 1-9 (1 = fastest, 9 = best compression)
- Batch size: Number of logs to batch before sending
- Batch interval: Maximum time to wait before sending a partial batch

See `client.py` and `server.py` for all available options.
