# Distributed Log Processing System

This project is part of the "365-Day Distributed Log Processing System Implementation" series.

## Project Overview

We're building a distributed system for processing log data at scale. This repository contains all the code and configuration needed to run the system.

## Getting Started

### Prerequisites
- Docker and Docker Compose
- Git
- VS Code (recommended)

### Running the Application
1. Clone this repository
2. Navigate to the project directory
3. Run `docker-compose up` to start the services

## Configuration Options

The logger service can be configured using environment variables in the `docker-compose.yml` file:

| Environment Variable | Description | Default Value |
|----------------------|-------------|---------------|
| LOG_LEVEL | Minimum log level to output (DEBUG, INFO, WARNING, ERROR, CRITICAL) | INFO |
| LOG_FREQUENCY | How often to generate heartbeat logs (seconds) | 5.0 |
| LOG_TO_FILE | Whether to write logs to a file | true |
| LOG_FILE_PATH | Path where log files will be stored | /logs/logger.log |
| LOG_MAX_SIZE_MB | Maximum log file size before rotation (MB) | 1.0 |
| WEB_HOST | Host address for the web interface | 0.0.0.0 |
| WEB_PORT | Port for the web interface | 8080 |
| MAX_LOGS_TO_DISPLAY | Maximum number of logs to store in memory for the web interface | 100 |

## Web Interface

The logger service includes a web interface for viewing logs and configuration:

- **URL**: http://localhost:8080
- **Features**:
  - View recent log messages
  - See current configuration
  - Auto-refresh logs every 10 seconds
  - Filter logs by level using CSS color-coding

## Log File Storage

Logs are stored in the `./logs` directory on your host machine, which is mounted as a volume in the Docker container. Log files are automatically rotated when they reach the configured maximum size.

## Project Structure
- `src/services/`: Contains individual microservices
  - `logger/`: The logger service
    - `app.py`: Main application entry point
    - `logger.py`: Log handling functionality
    - `config.py`: Configuration management
    - `web_server.py`: Web interface implementation
- `config/`: Configuration files
- `logs/`: Persistent storage for log files
- `data/`: Data storage (gitignored)
- `docs/`: Documentation
- `tests/`: Test suites

## Features Implemented
- Environment setup with Docker, Git, and VS Code
- Basic logger service with configurable settings
- Log rotation based on file size
- Log level filtering
- Persistent log storage using Docker volumes
- Web interface for monitoring logs
- Configuration management and override via environment variables

## Day 1 Homework Accomplishments
- Created a configuration system with multiple options
- Implemented log file output with rotation
- Added a web interface to view logs and configuration
- Updated documentation with new features and configuration options