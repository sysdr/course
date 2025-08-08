# 🔔 Webhook Notifications System

A real-time webhook notification system built with FastAPI and React, designed for monitoring and delivering log events to external services.

## 🚀 Features

- **Real-time Webhook Delivery**: Asynchronous webhook delivery with retry logic
- **Subscription Management**: Create, update, and manage webhook subscriptions
- **Event Filtering**: Filter events by type, level, source, and custom criteria
- **Dashboard**: Real-time monitoring dashboard with statistics and testing tools
- **Security**: Webhook signature verification and secret key management
- **Scalable**: Built with async/await for high concurrency

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   FastAPI       │    │   Webhook       │
│   (React)       │◄──►│   Backend       │◄──►│   Endpoints     │
│   Dashboard     │    │   (Python)      │    │   (External)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   Event         │
                       │   Listener      │
                       │   (Demo Events) │
                       └─────────────────┘
```

## 📋 Prerequisites

- Python 3.11+
- Node.js 16+
- npm or yarn

## 🛠️ Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd day90-webhook-notifications
   ```

2. **Start the application**
   ```bash
   ./start.sh
   ```

   This will:
   - Create a Python virtual environment
   - Install Python dependencies
   - Build the React frontend
   - Run tests
   - Start the FastAPI server

3. **Access the application**
   - Dashboard: http://localhost:8000
   - API Documentation: http://localhost:8000/docs

## 🎯 Usage

### Creating Webhook Subscriptions

1. Open the dashboard at http://localhost:8000
2. Click "Create Subscription"
3. Fill in the details:
   - **Name**: Descriptive name for the subscription
   - **URL**: Your webhook endpoint URL
   - **Events**: Select event types to monitor
4. Click "Create Subscription"

### Testing Webhooks

- **Test Individual Subscription**: Click the "Test" button next to any subscription
- **Test All Subscriptions**: Use the "Send Test Event" button in the Actions panel
- **API Testing**: Use the `/api/v1/events` endpoint to send custom events

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/subscriptions` | GET | List all subscriptions |
| `/api/v1/subscriptions` | POST | Create new subscription |
| `/api/v1/subscriptions/{id}` | GET | Get specific subscription |
| `/api/v1/subscriptions/{id}` | PUT | Update subscription |
| `/api/v1/subscriptions/{id}` | DELETE | Delete subscription |
| `/api/v1/events` | POST | Send test event |
| `/api/v1/stats` | GET | Get delivery statistics |
| `/api/v1/health` | GET | Health check |

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# Server Configuration
HOST=0.0.0.0
PORT=8000
DEBUG=true

# Webhook Configuration
MAX_CONCURRENT_DELIVERIES=100
DELIVERY_TIMEOUT=30
MAX_RETRY_ATTEMPTS=3
RETRY_DELAY=2
```

### Webhook Configuration

Edit `config/webhook_config.py` to customize webhook behavior:

```python
# Webhook delivery settings
WEBHOOK_CONFIG = {
    "max_concurrent": 100,
    "timeout": 30,
    "max_retries": 3,
    "retry_delay": 2,
    "signature_header": "X-Webhook-Signature"
}
```

## 🧪 Testing

### Run Tests
```bash
# Run all tests
python -m pytest

# Run specific test file
python -m pytest tests/unit/test_subscription_manager.py

# Run with coverage
python -m pytest --cov=src
```

### Manual Testing

1. **Create a test webhook endpoint**:
   - Use [webhook.site](https://webhook.site) for testing
   - Or set up a local endpoint with tools like ngrok

2. **Test the workflow**:
   ```bash
   # Create subscription
   curl -X POST "http://localhost:8000/api/v1/subscriptions" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Test Webhook",
       "url": "https://webhook.site/your-unique-url",
       "events": ["log.error", "log.warning"]
     }'

   # Send test event
   curl -X POST "http://localhost:8000/api/v1/events" \
     -H "Content-Type: application/json" \
     -d '{
       "level": "ERROR",
       "source": "test-service",
       "message": "Test webhook event",
       "event_type": "log.error"
     }'
   ```

## 📊 Monitoring

The dashboard provides real-time monitoring of:

- **Subscription Statistics**: Total and active subscriptions
- **Delivery Statistics**: Success/failure rates, delivery times
- **Real-time Charts**: Webhook delivery trends over time
- **Event Logs**: Recent webhook deliveries and their status

## 🔒 Security

- **Webhook Signatures**: Each webhook includes a signature for verification
- **Secret Keys**: Unique secret keys for each subscription
- **Input Validation**: Comprehensive validation of all inputs
- **Rate Limiting**: Built-in protection against abuse

## 🚀 Deployment

### Docker Deployment

```bash
# Build and run with Docker Compose
docker-compose up -d

# Or build manually
docker build -t webhook-notifications .
docker run -p 8000:8000 webhook-notifications
```

### Production Considerations

- Use a production WSGI server (Gunicorn)
- Set up proper logging and monitoring
- Configure environment variables for production
- Set up SSL/TLS certificates
- Implement proper authentication and authorization

## 📝 Development

### Project Structure

```
day90-webhook-notifications/
├── src/                    # Backend source code
│   ├── api/               # API routes and endpoints
│   ├── webhook/           # Webhook core functionality
│   └── main.py           # FastAPI application entry point
├── frontend/              # React frontend
│   ├── src/              # React source code
│   └── package.json      # Node.js dependencies
├── tests/                 # Test files
├── config/               # Configuration files
├── scripts/              # Utility scripts
├── requirements.txt      # Python dependencies
└── docker-compose.yml    # Docker configuration
```

### Adding New Features

1. **Backend**: Add new endpoints in `src/api/routes.py`
2. **Frontend**: Add new components in `frontend/src/components/`
3. **Tests**: Add corresponding tests in `tests/`
4. **Documentation**: Update this README

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
- Check the API documentation at http://localhost:8000/docs
- Review the test files for usage examples
- Open an issue in the repository

---

**Built with ❤️ using FastAPI and React**
