package com.logplatform.sdk;

import com.fasterxml.jackson.annotation.JsonProperty;

public class HealthResponse {
    @JsonProperty("status")
    private String status;
    
    @JsonProperty("timestamp")
    private String timestamp;
    
    @JsonProperty("version")
    private String version;
    
    @JsonProperty("uptime")
    private long uptime;

    public HealthResponse() {}

    public HealthResponse(String status, String timestamp, String version, long uptime) {
        this.status = status;
        this.timestamp = timestamp;
        this.version = version;
        this.uptime = uptime;
    }

    // Getters
    public String getStatus() { return status; }
    public String getTimestamp() { return timestamp; }
    public String getVersion() { return version; }
    public long getUptime() { return uptime; }

    // Setters
    public void setStatus(String status) { this.status = status; }
    public void setTimestamp(String timestamp) { this.timestamp = timestamp; }
    public void setVersion(String version) { this.version = version; }
    public void setUptime(long uptime) { this.uptime = uptime; }
}
