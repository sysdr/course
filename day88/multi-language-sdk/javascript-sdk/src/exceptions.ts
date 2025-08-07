export class LogPlatformError extends Error {
    constructor(message: string, public cause?: Error) {
        super(message);
        this.name = 'LogPlatformError';
    }
}

export class ConnectionError extends LogPlatformError {
    constructor(message: string, cause?: Error) {
        super(message, cause);
        this.name = 'ConnectionError';
    }
}

export class AuthenticationError extends LogPlatformError {
    constructor(message: string, cause?: Error) {
        super(message, cause);
        this.name = 'AuthenticationError';
    }
}
