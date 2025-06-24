# Day 28: Read/Write Quorums for Consistency Control

This project implements a distributed quorum-based consistency control system for log processing.

## Features

- Configurable consistency levels (Strong, Balanced, Eventual)
- Read/Write quorum implementation
- Conflict resolution using vector clocks
- Real-time web dashboard
- Comprehensive testing suite

## Quick Start

### Without Docker
```bash
./scripts/build.sh
```

### With Docker
```bash
docker-compose up --build
```

## Testing
```bash
./scripts/test.sh
```

## Web Interface
Visit http://localhost:8000 to interact with the system and observe consistency tradeoffs.

## Consistency Levels

- **Strong**: R=N, W=N (All nodes must respond)
- **Balanced**: R=majority, W=majority (Most nodes must respond)
- **Eventual**: R=1, W=1 (Any single node can respond)
