"""
Configuration module for the logger service.
"""
import os

# Log levels with corresponding numeric values
LOG_LEVELS = {
    "DEBUG": 10,
    "INFO": 20,
    "WARNING": 30,
    "ERROR": 40,
    "CRITICAL": 50
}

# Default configuration values
DEFAULT_CONFIG = {
    # Log level (can be overridden by environment variable)
    "log_level": os.environ.get("LOG_LEVEL", "INFO"),
    
    # How often to log messages (in seconds)
    "log_frequency": float(os.environ.get("LOG_FREQUENCY", "5.0")),
    
    # Log file settings
    "log_to_file": os.environ.get("LOG_TO_FILE", "true").lower() == "true",
    "log_file_path": os.environ.get("LOG_FILE_PATH", "/logs/logger.log"),
    "log_max_size_mb": float(os.environ.get("LOG_MAX_SIZE_MB", "1.0")),
    
    # Format strings for different log destinations
    "console_format": "[{timestamp}] [{level}] {message}",
    "file_format": "{timestamp} | {level} | {message}",
    
    # Web interface settings
    "web_host": os.environ.get("WEB_HOST", "0.0.0.0"),
    "web_port": int(os.environ.get("WEB_PORT", "8080")),
    "max_logs_to_display": int(os.environ.get("MAX_LOGS_TO_DISPLAY", "100"))
}

def get_config():
    """Returns the current configuration."""
    return DEFAULT_CONFIG

def get_log_level_value(level_name):
    """Converts a log level name to its numeric value."""
    return LOG_LEVELS.get(level_name.upper(), LOG_LEVELS["INFO"])

def is_log_enabled(message_level, config_level):
    """Determines if a message should be logged based on the configured level."""
    return get_log_level_value(message_level) >= get_log_level_value(config_level)