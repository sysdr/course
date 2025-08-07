"""LogPlatform Python SDK - Official client library for distributed log processing platform."""

from .client import LogPlatformClient
from .config import Config
from .exceptions import LogPlatformError, ConnectionError, AuthenticationError
from .models import LogEntry, QueryResult, StreamConfig

__version__ = "1.0.0"
__all__ = [
    "LogPlatformClient",
    "Config", 
    "LogPlatformError",
    "ConnectionError",
    "AuthenticationError",
    "LogEntry",
    "QueryResult",
    "StreamConfig"
]
