"""Custom exceptions for LogPlatform SDK."""

class LogPlatformError(Exception):
    """Base exception for LogPlatform SDK."""
    pass

class ConnectionError(LogPlatformError):
    """Raised when connection to the platform fails."""
    pass

class AuthenticationError(LogPlatformError):
    """Raised when authentication fails."""
    pass

class RateLimitError(LogPlatformError):
    """Raised when rate limit is exceeded."""
    pass
