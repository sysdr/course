import os

# Server configuration
SERVER_HOST = os.environ.get('SERVER_HOST', '0.0.0.0')
SERVER_PORT = int(os.environ.get('SERVER_PORT', 9000))
BUFFER_SIZE = int(os.environ.get('BUFFER_SIZE', 1024))

# Log filtering configuration
MIN_LOG_LEVEL = os.environ.get('MIN_LOG_LEVEL', 'INFO')
LOG_LEVELS = {
    'DEBUG': 0,
    'INFO': 1,
    'WARNING': 2,
    'ERROR': 3,
    'CRITICAL': 4
}

# Log persistence configuration
LOG_FILE_PATH = os.environ.get('LOG_FILE_PATH', 'logs/server.log')
ENABLE_LOG_PERSISTENCE = os.environ.get('ENABLE_LOG_PERSISTENCE', 'true').lower() == 'true'

# Rate limiting configuration
RATE_LIMIT_ENABLED = os.environ.get('RATE_LIMIT_ENABLED', 'true').lower() == 'true'
RATE_LIMIT_WINDOW = int(os.environ.get('RATE_LIMIT_WINDOW', 60))  # Window in seconds
RATE_LIMIT_MAX_REQUESTS = int(os.environ.get('RATE_LIMIT_MAX_REQUESTS', 100))  # Max requests per window