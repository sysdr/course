# Sliding Window Analytics

A real-time analytics system that processes streaming events using sliding window algorithms with Redis as the backend storage.

## Features

- Real-time event processing with sliding windows
- Redis-based data storage and caching
- FastAPI REST API
- Event generation and simulation
- Docker containerization
- Comprehensive logging and monitoring

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 2GB of available memory

### Running the Demo

1. **Start the application:**
   ```bash
   ./demo.sh
   ```

   This script will:
   - Check Docker availability
   - Stop any existing containers
   - Build and start the application
   - Wait for services to be ready
   - Display access URLs

2. **Access the application:**
   - API: http://localhost:8000
   - API Documentation: http://localhost:8000/docs
   - Redis: localhost:6379

3. **View logs:**
   ```bash
   docker-compose logs -f
   ```

### Cleanup

To stop and clean up everything:

```bash
./cleanup.sh
```

This script will:
- Stop all containers
- Remove all images, volumes, and networks
- Clean up dangling Docker resources
- Remove all project-related resources

## Manual Commands

If you prefer to run commands manually:

### Start the application
```bash
docker-compose up --build
```

### Stop the application
```bash
docker-compose down
```

### View logs
```bash
docker-compose logs -f
```

### Rebuild from scratch
```bash
docker-compose down --rmi all --volumes --remove-orphans
docker-compose up --build
```

## Project Structure

```
sliding-window-analytics/
├── config/
│   └── settings.py          # Configuration settings
├── data/                    # Data storage
├── docker/
│   └── Dockerfile          # Application Dockerfile
├── logs/                   # Application logs
├── main.py                 # Main application entry point
├── requirements.txt        # Python dependencies
├── src/
│   ├── api/
│   │   └── main.py        # FastAPI application
│   ├── core/
│   │   └── sliding_window.py  # Sliding window logic
│   ├── utils/
│   │   └── event_generator.py # Event generation utilities
│   └── web/               # Web interface components
├── tests/
│   └── test_sliding_window.py  # Unit tests
├── docker-compose.yml     # Docker Compose configuration
├── demo.sh               # Demo startup script
├── cleanup.sh            # Cleanup script
└── README.md             # This file
```

## Configuration

The application can be configured through environment variables or by modifying `config/settings.py`:

- `REDIS_HOST`: Redis server host (default: localhost)
- `REDIS_PORT`: Redis server port (default: 6379)
- `WINDOW_SIZE_SECONDS`: Sliding window size in seconds (default: 30)
- `SLIDE_INTERVAL_SECONDS`: Window slide interval in seconds (default: 5)
- `API_HOST`: API server host (default: 0.0.0.0)
- `API_PORT`: API server port (default: 8000)

## API Endpoints

- `GET /health`: Health check
- `GET /events`: Get current events in sliding window
- `POST /events`: Add a new event
- `GET /analytics`: Get analytics data
- `GET /docs`: API documentation (Swagger UI)

## Development

### Running Tests
```bash
docker-compose exec sliding-window-app pytest
```

### Adding New Features
1. Create feature branch
2. Implement changes
3. Add tests
4. Update documentation
5. Submit pull request

## Troubleshooting

### Common Issues

1. **Port already in use:**
   - Stop other services using port 8000
   - Or change the port in `config/settings.py`

2. **Redis connection issues:**
   - Ensure Redis container is running: `docker-compose ps`
   - Check Redis logs: `docker-compose logs redis`

3. **Memory issues:**
   - Increase Docker memory limit
   - Reduce `max_events_per_window` in settings

### Logs and Debugging

- Application logs: `docker-compose logs sliding-window-app`
- Redis logs: `docker-compose logs redis`
- All logs: `docker-compose logs -f`

## License

This project is licensed under the MIT License. 