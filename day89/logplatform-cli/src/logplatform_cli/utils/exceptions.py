class LogPlatformCLIError(Exception):
    """Base exception for CLI errors"""
    pass

class AuthenticationError(LogPlatformCLIError):
    """Authentication related errors"""
    pass

class APIError(LogPlatformCLIError):
    """API communication errors"""
    pass

class ConfigurationError(LogPlatformCLIError):
    """Configuration related errors"""
    pass
