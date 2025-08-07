package com.logplatform.sdk;

public class LogPlatformException extends Exception {
    
    public LogPlatformException(String message) {
        super(message);
    }
    
    public LogPlatformException(String message, Throwable cause) {
        super(message, cause);
    }
    
    public LogPlatformException(Throwable cause) {
        super(cause);
    }
}
