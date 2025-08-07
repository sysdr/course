package com.logplatform.sdk;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDateTime;
import java.util.Map;

public class LogEntry {
    @JsonProperty("timestamp")
    private LocalDateTime timestamp;
    
    @JsonProperty("level")
    private String level;
    
    @JsonProperty("message")
    private String message;
    
    @JsonProperty("service")
    private String service;
    
    @JsonProperty("metadata")
    private Map<String, Object> metadata;

    public LogEntry() {
        this.timestamp = LocalDateTime.now();
        this.metadata = Map.of();
    }

    public LogEntry(String level, String message, String service) {
        this();
        this.level = level;
        this.message = message;
        this.service = service;
        this.timestamp = LocalDateTime.now();
    }

    public LogEntry(String level, String message, String service, Map<String, Object> metadata) {
        this(level, message, service);
        this.metadata = metadata != null ? metadata : Map.of();
        this.timestamp = LocalDateTime.now();
    }

    // Getters
    public LocalDateTime getTimestamp() { return timestamp; }
    public String getLevel() { return level; }
    public String getMessage() { return message; }
    public String getService() { return service; }
    public Map<String, Object> getMetadata() { return metadata; }

    // Setters
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }
    public void setLevel(String level) { this.level = level; }
    public void setMessage(String message) { this.message = message; }
    public void setService(String service) { this.service = service; }
    public void setMetadata(Map<String, Object> metadata) { this.metadata = metadata; }
}
