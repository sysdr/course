# Log Shipping Client - Main Project

This is the basic implementation of a log shipping client that demonstrates core concepts.

## Features

- Read logs from files (batch and incremental)
- Ship logs to a TCP server over the network
- Basic error handling and retry logic
- Containerization support with Docker

## Running the Project

### Install Dependencies
```bash
pip install -r requirements.txt
```

### Start the Server
```bash
python server.py --port 9000
```

### Run the Client (Batch Mode)
```bash
python -m src.main --log-file sample_logs.txt --server-host localhost --server-port 9000 --batch
```

### Run the Client (Continuous Mode)
```bash
python -m src.main --log-file sample_logs.txt --server-host localhost --server-port 9000
```

### Run Tests
```bash
pytest tests/ -v
```

### With Coverage
```bash
pytest --cov=src tests/
```

### Using Docker
```bash
docker-compose up
```

## Project Structure

- `src/log_reader.py` - Reads logs from files
- `src/log_shipper.py` - Ships logs to TCP server
- `src/main.py` - Command-line interface
- `server.py` - TCP log server
- `tests/` - Unit and integration tests
