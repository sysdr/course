# LogPlatform CLI

Command-line interface for distributed log processing platform management.

## Quick Start

```bash
# Start the environment
./start.sh

# Login to platform
logplatform auth login

# Search logs
logplatform logs search --query "error" --limit 10

# Stream logs in real-time
logplatform logs stream --level ERROR

# Stop the environment
./stop.sh
```

## Features

- **Authentication**: Secure login with token management
- **Log Management**: Search, stream, and export logs
- **Alert Management**: Create and manage log alerts
- **Configuration**: Multi-profile configuration management
- **Administration**: Platform health and user management

## Commands

### Authentication
- `logplatform auth login` - Login to platform
- `logplatform auth logout` - Logout from platform
- `logplatform auth status` - Show authentication status

### Log Management
- `logplatform logs search` - Search logs with filters
- `logplatform logs stream` - Stream logs in real-time
- `logplatform logs export` - Export logs to file
- `logplatform logs tail <service>` - Tail logs for service

### Alert Management
- `logplatform alerts list` - List alerts
- `logplatform alerts create` - Create new alert
- `logplatform alerts delete <id>` - Delete alert

### Configuration
- `logplatform config get [key]` - Get configuration value
- `logplatform config set <key> <value>` - Set configuration value
- `logplatform config init` - Initialize configuration

### Administration
- `logplatform admin health` - Check platform health
- `logplatform admin stats` - Show platform statistics
- `logplatform admin users` - List platform users

## Installation

```bash
pip install -e .
```

## Development

```bash
# Install development dependencies
pip install -r requirements.txt

# Run tests
pytest tests/ -v

# Install in development mode
pip install -e .
```

## Docker

```bash
# Build and run with Docker
docker-compose up --build

# Use CLI in container
docker-compose exec logplatform-cli logplatform --help
```
