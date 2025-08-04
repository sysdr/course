# NLP Log Processor - Day 84

A Natural Language Processing system for intelligent log analysis and understanding, built with Flask, NLTK, and Docker.

## 🚀 Features

### Core NLP Capabilities
- **Intent Classification**: Automatically categorizes log messages (error, warning, info, security, performance, debug)
- **Sentiment Analysis**: Analyzes emotional tone of log messages using VADER sentiment analysis
- **Entity Extraction**: Identifies IP addresses, emails, URLs, error codes, file paths, timestamps, and more
- **Keyword Extraction**: Extracts important keywords from log messages
- **Batch Processing**: Efficiently processes multiple log messages simultaneously

### New Features (Added)
- **Host Log Reading**: Read and analyze log files directly from the host machine
- **Demo Mode**: Built-in demo with sample log messages for testing
- **Real-time Dashboard**: Beautiful web interface with live statistics and charts
- **Security**: Restricted file access to prevent unauthorized file reading

## 🛠️ Technology Stack

- **Backend**: Python Flask with async support
- **NLP**: NLTK, TextBlob for sentiment analysis and entity extraction
- **Frontend**: HTML5, Tailwind CSS, Chart.js
- **Containerization**: Docker with volume mounting for host file access
- **Data Processing**: Pandas for data manipulation

## 📦 Installation & Setup

### Prerequisites
- Docker and Docker Compose
- Python 3.11+ (for local development)

### Quick Start with Docker

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd nlp-log-processor
   ```

2. **Start the application**
   ```bash
   ./run_docker.sh
   # or
   docker-compose up --build -d
   ```

3. **Access the dashboard**
   - Open your browser and go to: http://localhost:5000
   - The API is available at: http://localhost:5000/api/health

### Local Development

1. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

2. **Run the application**
   ```bash
   python src/api/server.py
   ```

## 🎯 Usage

### Web Dashboard

1. **Single Log Analysis**
   - Enter a log message in the text area
   - Click "Analyze Message" to get NLP insights
   - View intent, sentiment, entities, and keywords

2. **Host Log Reading**
   - Enter a log file path (e.g., `/tmp/sample_logs.log`)
   - Click "Read Logs" to process the entire file
   - View batch processing results with summaries

3. **Demo Mode**
   - Click "Run Demo" to see NLP analysis on sample log messages
   - Perfect for testing and demonstration purposes

### API Endpoints

#### Health Check
```bash
GET /api/health
```

#### Analyze Single Log
```bash
POST /api/analyze
Content-Type: application/json

{
  "message": "2024-01-15 10:30:15 ERROR [UserService] Authentication failed"
}
```

#### Read Host Logs
```bash
POST /api/read-logs
Content-Type: application/json

{
  "file_path": "/tmp/sample_logs.log"
}
```

#### Demo Logs
```bash
GET /api/demo-logs
```

#### Get Statistics
```bash
GET /api/stats
```

## 🔒 Security Features

### File Access Restrictions
The host log reading feature includes security measures:
- **Allowed directories**: `/var/log`, `/tmp`, `/home`, `~` (home directory)
- **Read-only access**: Docker containers mount host directories as read-only
- **Path validation**: Server-side validation prevents directory traversal attacks

### Example Allowed Paths
- `/var/log/syslog`
- `/tmp/application.log`
- `/home/user/logs/error.log`
- `~/logs/debug.log`

## 📊 NLP Analysis Results

### Intent Classification
- **Error**: Failed operations, exceptions, crashes
- **Warning**: Deprecation notices, slow performance, retries
- **Info**: Successful operations, status updates
- **Security**: Authentication issues, access violations
- **Performance**: Resource usage, latency issues
- **Debug**: Detailed debugging information

### Entity Extraction
- **IP Addresses**: IPv4 addresses in log messages
- **Email Addresses**: Email patterns
- **URLs**: HTTP/HTTPS links
- **Error Codes**: Standard error codes (e.g., 404, 500)
- **File Paths**: File system paths
- **Timestamps**: Date/time patterns
- **Database Tables**: Common table names
- **HTTP Status Codes**: Response codes

### Sentiment Analysis
- **Compound Score**: Overall sentiment (-1 to +1)
- **Positive**: Positive sentiment percentage
- **Negative**: Negative sentiment percentage
- **Neutral**: Neutral sentiment percentage

## 🐳 Docker Configuration

### Volume Mounts
```yaml
volumes:
  - ./data:/app/data          # Application data
  - /tmp:/tmp:ro              # Host logs (read-only)
```

### Environment Variables
- `FLASK_ENV=development`
- `PORT=5000`

## 📁 Project Structure

```
nlp-log-processor/
├── config/
│   └── config.py             # Configuration settings
├── data/
│   ├── logs/                 # Processed log storage
│   ├── models/               # NLP model storage
│   └── sample_logs/          # Sample log files
├── src/
│   ├── api/
│   │   └── server.py         # Flask API server
│   ├── nlp/
│   │   ├── log_processor.py  # Core NLP processing
│   │   └── extractors/       # Entity extraction modules
│   └── web/
│       └── templates/
│           └── dashboard.html # Web dashboard
├── tests/                    # Test files
├── docker-compose.yml        # Docker configuration
├── Dockerfile               # Container definition
├── requirements.txt         # Python dependencies
├── run_docker.sh           # Docker startup script
└── README.md               # This file
```

## 🧪 Testing

### Run Tests
```bash
./run_tests.sh
# or
pytest tests/
```

### Sample Log File
A sample log file is created at `/tmp/sample_logs.log` for testing:
```bash
# Test host log reading
curl -X POST http://localhost:5000/api/read-logs \
  -H "Content-Type: application/json" \
  -d '{"file_path": "/tmp/sample_logs.log"}'
```

## 🚀 Deployment

### Production Considerations
- Use a production WSGI server (Gunicorn, uWSGI)
- Configure proper logging and monitoring
- Set up reverse proxy (Nginx)
- Implement authentication and authorization
- Use environment variables for configuration
- Set up proper backup and recovery procedures

### Scaling
- The application supports horizontal scaling
- Use load balancers for multiple instances
- Consider using Redis for caching
- Implement database storage for persistent data

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📝 License

This project is part of the Day 84 course curriculum.

## 🆘 Troubleshooting

### Common Issues

1. **Port 5000 already in use**
   ```bash
   # Kill existing processes
   lsof -i :5000
   kill -9 <PID>
   ```

2. **Docker build fails**
   ```bash
   # Clean and rebuild
   docker-compose down
   docker system prune -f
   docker-compose up --build
   ```

3. **File access denied**
   - Ensure the file path is in allowed directories
   - Check file permissions
   - Verify Docker volume mounts

4. **NLP models not loading**
   - Check internet connection for NLTK downloads
   - Verify Python dependencies are installed
   - Check logs for specific error messages

### Logs and Debugging
```bash
# View Docker logs
docker-compose logs -f

# Access container shell
docker-compose exec nlp-processor bash

# Check application health
curl http://localhost:5000/api/health
```

## 🎉 Demo

Try the demo mode to see the NLP Log Processor in action:

1. Open http://localhost:5000
2. Click "🎭 Run Demo" button
3. View the comprehensive analysis of sample log messages
4. Explore the dashboard statistics and charts

The demo showcases all NLP capabilities including intent classification, sentiment analysis, entity extraction, and keyword identification. 