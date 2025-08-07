package com.logplatform.sdk;

import com.fasterxml.jackson.annotation.JsonProperty;

public class SubmitResponse {
    @JsonProperty("success")
    private boolean success;
    
    @JsonProperty("log_id")
    private String logId;
    
    @JsonProperty("message")
    private String message;

    public SubmitResponse() {}

    public SubmitResponse(boolean success, String logId, String message) {
        this.success = success;
        this.logId = logId;
        this.message = message;
    }

    // Getters
    public boolean isSuccess() { return success; }
    public String getLogId() { return logId; }
    public String getMessage() { return message; }

    // Setters
    public void setSuccess(boolean success) { this.success = success; }
    public void setLogId(String logId) { this.logId = logId; }
    public void setMessage(String message) { this.message = message; }
}
